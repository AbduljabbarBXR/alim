import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'audio.dart';
import 'notifications.dart';

/// The number of ayat in each surah, so a download knows when it is whole.
const surahAyahCounts = <int>[
  7,
  286,
  200,
  176,
  120,
  165,
  206,
  75,
  129,
  109,
  123,
  111,
  43,
  52,
  99,
  128,
  111,
  110,
  98,
  135,
  112,
  78,
  118,
  64,
  77,
  227,
  93,
  88,
  69,
  60,
  34,
  30,
  73,
  54,
  45,
  83,
  182,
  88,
  75,
  85,
  54,
  53,
  89,
  59,
  37,
  35,
  38,
  29,
  18,
  45,
  60,
  49,
  62,
  55,
  78,
  96,
  29,
  22,
  24,
  13,
  14,
  11,
  11,
  18,
  12,
  12,
  30,
  52,
  52,
  44,
  28,
  28,
  20,
  56,
  40,
  31,
  50,
  40,
  46,
  42,
  29,
  19,
  36,
  25,
  22,
  17,
  19,
  26,
  30,
  20,
  15,
  21,
  11,
  8,
  8,
  19,
  5,
  8,
  8,
  11,
  11,
  8,
  3,
  9,
  5,
  4,
  7,
  3,
  6,
  3,
  5,
  4,
  5,
  6,
];

enum DownloadPhase { idle, downloading, extracting, done, failed }

class DownloadTask {
  const DownloadTask({
    this.phase = DownloadPhase.idle,
    this.progress = 0,
    this.detail,
    this.error,
    this.bytes = 0,
    this.totalBytes = 0,
  });

  final DownloadPhase phase;
  final double progress;
  final String? detail;
  final String? error;

  /// How many bytes have landed so far, and how many are expected when the
  /// server tells us. Zero total means the size is not known yet.
  final int bytes;
  final int totalBytes;

  bool get busy =>
      phase == DownloadPhase.downloading || phase == DownloadPhase.extracting;

  DownloadTask copyWith({
    DownloadPhase? phase,
    double? progress,
    String? detail,
    String? error,
    int? bytes,
    int? totalBytes,
  }) => DownloadTask(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    detail: detail ?? this.detail,
    error: error ?? this.error,
    bytes: bytes ?? this.bytes,
    totalBytes: totalBytes ?? this.totalBytes,
  );
}

/// Raised inside a fetch when the person asked for the download to stop.
class _Stopped implements Exception {
  const _Stopped();
}

/// One download's right to keep running. The person stops it by flipping
/// [aborted]; whoever started it can then wait for [done] before touching the
/// same files again.
class _Abort {
  bool aborted = false;
  final Completer<void> _done = Completer<void>();

  Future<void> get done => _done.future;

  void finish() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// A readable size, so every progress line carries the weight of the file.
String _mb(int bytes) {
  final value = bytes / (1024 * 1024);
  return '${value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} MB';
}

/// Downloads a reciter's surahs into the app's own storage, one at a time.
/// Completed surahs are marked on disk, so the list survives restarts.
class AudioDownloads extends StateNotifier<Map<String, DownloadTask>> {
  AudioDownloads() : super(const {}) {
    _restore();
  }

  static const _maxZipBytes = 40 * 1024 * 1024;

  final Set<String> _done = {};
  final Map<String, _Abort> _aborts = {};
  final Map<String, int> _activeSurah = {};
  String? _rootPath;
  HttpClient? _client;

  /// The last shape of the download notification, so it is rewritten only when
  /// it visibly changes.
  int _lastNotifiedPercent = -1;
  DateTime _lastNotifiedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// One client for every request, so a pack does not open a fresh connection
  /// for each of its hundreds of files.
  HttpClient get _http =>
      _client ??= HttpClient()..connectionTimeout = const Duration(seconds: 20);

  @override
  void dispose() {
    _client?.close(force: true);
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final root = await _root();
      if (!await root.exists()) return;
      await for (final voice in root.list()) {
        if (voice is! Directory) continue;
        final id = _basename(voice.path);
        await for (final surahDir in voice.list()) {
          if (surahDir is! Directory) continue;
          final number = int.tryParse(_basename(surahDir.path));
          if (number == null) continue;
          if (await File('${surahDir.path}/.complete').exists()) {
            _done.add('$id/$number');
          }
        }
      }
    } catch (_) {
      // Downloads simply look empty if the folder cannot be read.
    }
    if (!mounted) return;
    state = {...state};
  }

  String _basename(String path) => path.split(Platform.pathSeparator).last;

  String _key(String reciterId, int surah) => '$reciterId/$surah';

  Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/audio');
    if (await dir.exists()) {
      _rootPath = dir.path;
    } else {
      await dir.create(recursive: true);
      _rootPath = dir.path;
    }
    return dir;
  }

  Future<Directory> _surahDir(String reciterId, int surah) async {
    final root = await _root();
    final dir = Directory('${root.path}/$reciterId/$surah');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  bool isSurahDownloaded(String reciterId, int surah) =>
      _done.contains(_key(reciterId, surah));

  int downloadedCount(String reciterId) =>
      _done.where((key) => key.startsWith('$reciterId/')).length;

  bool packDownloaded(String reciterId) => downloadedCount(reciterId) >= 114;

  /// The local folder, when the surah has been fully unpacked. Synchronous so
  /// the player can use it the moment a download finishes.
  String? surahDirectorySync(String reciterId, int surah) {
    final root = _rootPath;
    if (root == null || !isSurahDownloaded(reciterId, surah)) return null;
    return '$root/$reciterId/$surah';
  }

  static bool _same(DownloadTask? a, DownloadTask b) =>
      a != null &&
      a.phase == b.phase &&
      a.detail == b.detail &&
      (a.progress - b.progress).abs() < 0.005;

  void _set(String key, DownloadTask task) {
    final next = {...state};
    var changed = false;
    if (!_same(state[key], task)) {
      next[key] = task;
      changed = true;
    }
    final parts = key.split('/');
    final surah = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (surah != null) {
      final packKey = '${parts[0]}/all';
      final pack = state[packKey];
      if (pack != null && pack.busy) {
        final relayed = DownloadTask(
          phase: DownloadPhase.downloading,
          progress: (surah - 1 + task.progress.clamp(0.0, 1.0)) / 114,
          detail: 'Surah $surah of 114 · ${task.detail ?? 'saving'}',
          bytes: task.bytes,
          totalBytes: task.totalBytes,
        );
        if (!_same(pack, relayed)) {
          next[packKey] = relayed;
          changed = true;
        }
      }
    }
    if (changed) {
      state = next;
      _notify();
    }
  }

  /// Keeps one silent notification in the shade with the download's name and
  /// percentage while anything is still saving, and takes it away after.
  void _notify() {
    DownloadTask? chosen;
    for (final entry in state.entries) {
      final task = entry.value;
      if (!task.busy) continue;
      if (entry.key.endsWith('/all')) {
        chosen = task;
        break;
      }
      chosen ??= task;
    }
    if (chosen == null) {
      if (_lastNotifiedPercent >= 0) {
        _lastNotifiedPercent = -1;
        unawaited(Notifications.hideDownloadProgress());
      }
      return;
    }
    final percent = (chosen.progress.clamp(0.0, 1.0) * 100).round();
    final now = DateTime.now();
    if (percent == _lastNotifiedPercent) return;
    if (now.difference(_lastNotifiedAt) < const Duration(milliseconds: 700)) {
      return;
    }
    _lastNotifiedPercent = percent;
    _lastNotifiedAt = now;
    unawaited(
      Notifications.downloadProgress(
        percent: percent,
        body: chosen.detail ?? 'Downloading',
      ),
    );
  }

  void _remove(String key) {
    final next = {...state};
    next.remove(key);
    state = next;
  }

  Future<void> downloadSurah(Reciter reciter, int surah) async {
    final key = _key(reciter.id, surah);
    if (state[key]?.busy ?? false) return;
    if (isSurahDownloaded(reciter.id, surah)) {
      _set(key, const DownloadTask(phase: DownloadPhase.done, progress: 1));
      return;
    }
    final previous = _aborts[key];
    if (previous != null) {
      previous.aborted = true;
      await previous.done;
    }
    final token = _Abort();
    _aborts[key] = token;
    _set(
      key,
      const DownloadTask(phase: DownloadPhase.downloading, detail: 'Starting'),
    );
    final dir = await _surahDir(reciter.id, surah);
    try {
      final zipUrl = surahZipUrl(reciter, surah);
      final size = await _remoteSize(zipUrl, token);
      if (size == null || size > _maxZipBytes) {
        await _downloadAyahs(reciter, surah, dir, key, token);
      } else {
        await _downloadZip(reciter, surah, dir, key, zipUrl, token);
      }
      if (token.aborted) throw const _Stopped();
      await File('${dir.path}/.complete').writeAsString('1', flush: true);
      _done.add(key);
      _set(key, const DownloadTask(phase: DownloadPhase.done, progress: 1));
    } on _Stopped {
      _set(
        key,
        const DownloadTask(
          phase: DownloadPhase.failed,
          error: 'Download stopped.',
        ),
      );
    } catch (_) {
      _set(
        key,
        DownloadTask(
          phase: DownloadPhase.failed,
          error:
              'Could not save surah $surah. Check the connection and try again.',
        ),
      );
    } finally {
      token.finish();
      if (identical(_aborts[key], token)) _aborts.remove(key);
      _notify();
    }
  }

  /// Asks the running download of one surah to stop; the sheet's Stop button.
  Future<void> stopSurah(String reciterId, int surah) async {
    final key = _key(reciterId, surah);
    _aborts[key]?.aborted = true;
    if (state[key]?.busy ?? false) {
      _set(
        key,
        const DownloadTask(
          phase: DownloadPhase.failed,
          error: 'Download stopped.',
        ),
      );
    }
  }

  Future<void> _downloadZip(
    Reciter reciter,
    int surah,
    Directory dir,
    String key,
    String url,
    _Abort token,
  ) async {
    final temp = File('${dir.path}/surah.zip');
    try {
      await _fetch(
        url,
        temp,
        abort: token,
        onProgress:
            (received, total) => _set(
              key,
              DownloadTask(
                phase: DownloadPhase.downloading,
                progress: total > 0 ? received / total * 0.9 : 0,
                detail:
                    total > 0
                        ? '${(received * 100 / total).round()}% · '
                            '${_mb(received)} of ${_mb(total)}'
                        : _mb(received),
                bytes: received,
                totalBytes: total > 0 ? total : 0,
              ),
            ),
      );
      _set(
        key,
        const DownloadTask(
          phase: DownloadPhase.extracting,
          progress: 0.92,
          detail: 'Unpacking',
        ),
      );
      final bytes = await temp.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      var found = 0;
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name.split('/').last.toLowerCase();
        if (!name.endsWith('.mp3')) continue;
        final target = File('${dir.path}/$name');
        await target.writeAsBytes(file.content as List<int>, flush: true);
        found++;
      }
      if (found == 0) throw const FormatException('No audio in the archive.');
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<void> _downloadAyahs(
    Reciter reciter,
    int surah,
    Directory dir,
    String key,
    _Abort token,
  ) async {
    final count = surahAyahCounts[surah - 1];
    final pending = <int>[];
    var done = 0;
    var bytes = 0;
    for (var ayah = 1; ayah <= count; ayah++) {
      final target = File(localAyahPath(dir.path, surah, ayah));
      if (await target.exists()) {
        final length = await target.length();
        if (length > 1024) {
          done++;
          bytes += length;
          continue;
        }
      }
      pending.add(ayah);
    }
    final inFlight = <int, int>{};
    void report() {
      final live = bytes + inFlight.values.fold<int>(0, (a, b) => a + b);
      _set(
        key,
        DownloadTask(
          phase: DownloadPhase.downloading,
          progress: done / count,
          detail:
              '$done/$count · ${(done * 100 / count).round()}% · ${_mb(live)}',
          bytes: live,
        ),
      );
    }

    report();
    var next = 0;
    Future<void> worker() async {
      while (true) {
        if (token.aborted || next >= pending.length) return;
        final ayah = pending[next++];
        final target = File(localAyahPath(dir.path, surah, ayah));
        final part = File('${target.path}.part');
        var attempts = 0;
        try {
          while (true) {
            try {
              await _fetch(
                ayahAudioUrl(reciter, surah, ayah),
                part,
                abort: token,
                onProgress: (received, _) {
                  inFlight[ayah] = received;
                  report();
                },
              );
              break;
            } catch (error) {
              if (error is _Stopped) rethrow;
              attempts++;
              if (attempts >= 2 || token.aborted) rethrow;
              await Future<void>.delayed(const Duration(seconds: 1));
            }
          }
          await part.rename(target.path);
        } on _Stopped {
          if (await part.exists()) {
            try {
              await part.delete();
            } catch (_) {}
          }
          return;
        } finally {
          inFlight.remove(ayah);
        }
        done++;
        bytes += await target.length();
        report();
      }
    }

    // Three files at a time: enough to keep the line busy without hammering
    // the server or memory.
    await Future.wait([for (var w = 0; w < 3; w++) worker()]);
    if (token.aborted) throw const _Stopped();
  }

  Future<int?> _remoteSize(String url, _Abort token) async {
    try {
      if (token.aborted) throw const _Stopped();
      final request = await _http.headUrl(Uri.parse(url));
      final response = await request.close();
      await response.drain<void>();
      if (token.aborted) throw const _Stopped();
      if (response.statusCode != HttpStatus.ok) return null;
      return response.contentLength >= 0 ? response.contentLength : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetch(
    String url,
    File target, {
    _Abort? abort,
    void Function(int received, int total)? onProgress,
  }) async {
    if (abort != null && abort.aborted) throw const _Stopped();
    final request = await _http.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}');
    }
    final total = response.contentLength;
    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        if (abort != null && abort.aborted) throw const _Stopped();
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null) {
          onProgress(received, total > 0 ? total : -1);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<void> downloadPack(Reciter reciter, {void Function()? onDone}) async {
    final key = '${reciter.id}/all';
    if (state[key]?.busy ?? false) return;
    final previous = _aborts[key];
    if (previous != null) {
      previous.aborted = true;
      await previous.done;
    }
    final token = _Abort();
    _aborts[key] = token;
    _set(
      key,
      const DownloadTask(phase: DownloadPhase.downloading, detail: 'Starting'),
    );
    try {
      for (var surah = 1; surah <= 114; surah++) {
        if (token.aborted) {
          _set(
            key,
            const DownloadTask(
              phase: DownloadPhase.failed,
              error: 'Download stopped.',
            ),
          );
          return;
        }
        if (!isSurahDownloaded(reciter.id, surah)) {
          _activeSurah[reciter.id] = surah;
          await downloadSurah(reciter, surah);
          _activeSurah.remove(reciter.id);
          if (token.aborted) {
            _set(
              key,
              const DownloadTask(
                phase: DownloadPhase.failed,
                error: 'Download stopped.',
              ),
            );
            return;
          }
          final child = state[_key(reciter.id, surah)];
          if (child?.phase == DownloadPhase.failed) {
            throw StateError('Surah $surah stopped the pack.');
          }
        }
        _set(
          key,
          DownloadTask(
            phase: DownloadPhase.downloading,
            progress: surah / 114,
            detail: 'Surah $surah of 114',
          ),
        );
      }
      _set(key, const DownloadTask(phase: DownloadPhase.done, progress: 1));
      onDone?.call();
    } catch (_) {
      _set(
        key,
        const DownloadTask(
          phase: DownloadPhase.failed,
          error: 'The pack stopped early. Tap to pick it up again.',
        ),
      );
    } finally {
      token.finish();
      if (identical(_aborts[key], token)) _aborts.remove(key);
      _activeSurah.remove(reciter.id);
      _notify();
    }
  }

  /// Stops a running pack at once, including the surah being saved.
  Future<void> stopPack(String reciterId) async {
    _aborts['$reciterId/all']?.aborted = true;
    final active = _activeSurah[reciterId];
    if (active != null) {
      _aborts[_key(reciterId, active)]?.aborted = true;
    }
    final key = '$reciterId/all';
    if (state[key]?.busy ?? false) {
      _set(
        key,
        const DownloadTask(
          phase: DownloadPhase.failed,
          error: 'Download stopped.',
        ),
      );
    }
  }

  Future<void> deleteSurah(String reciterId, int surah) async {
    final key = _key(reciterId, surah);
    _aborts[key]?.aborted = true;
    _done.remove(key);
    _remove(key);
    try {
      final dir = await _surahDir(reciterId, surah);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> deletePack(String reciterId) async {
    for (var surah = 1; surah <= 114; surah++) {
      await deleteSurah(reciterId, surah);
    }
    _remove('$reciterId/all');
  }
}

final audioDownloadsProvider =
    StateNotifierProvider<AudioDownloads, Map<String, DownloadTask>>(
      (ref) => AudioDownloads(),
    );
