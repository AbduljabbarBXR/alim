import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'audio.dart';

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
  });

  final DownloadPhase phase;
  final double progress;
  final String? detail;
  final String? error;

  bool get busy =>
      phase == DownloadPhase.downloading || phase == DownloadPhase.extracting;

  DownloadTask copyWith({
    DownloadPhase? phase,
    double? progress,
    String? detail,
    String? error,
  }) => DownloadTask(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    detail: detail ?? this.detail,
    error: error ?? this.error,
  );
}

/// Downloads a reciter's surahs into the app's own storage, one at a time.
/// Completed surahs are marked on disk, so the list survives restarts.
class AudioDownloads extends StateNotifier<Map<String, DownloadTask>> {
  AudioDownloads() : super(const {}) {
    _restore();
  }

  static const _maxZipBytes = 40 * 1024 * 1024;

  final Set<String> _done = {};
  final Set<String> _stopPacks = {};
  String? _rootPath;

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

  void _set(String key, DownloadTask task) {
    final previous = state[key];
    if (previous != null &&
        previous.phase == task.phase &&
        previous.detail == task.detail &&
        (previous.progress - task.progress).abs() < 0.01) {
      return;
    }
    state = {...state, key: task};
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
    _set(
      key,
      const DownloadTask(phase: DownloadPhase.downloading, detail: 'Starting'),
    );
    final dir = await _surahDir(reciter.id, surah);
    try {
      final zipUrl = surahZipUrl(reciter, surah);
      final size = await _remoteSize(zipUrl);
      if (size != null && size > _maxZipBytes) {
        await _downloadAyahs(reciter, surah, dir, key);
      } else {
        await _downloadZip(reciter, surah, dir, key, zipUrl);
      }
      await File('${dir.path}/.complete').writeAsString('1', flush: true);
      _done.add(key);
      _set(key, const DownloadTask(phase: DownloadPhase.done, progress: 1));
    } catch (error) {
      _set(
        key,
        DownloadTask(
          phase: DownloadPhase.failed,
          error:
              'Could not download $surah. Check the connection and try again.',
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
  ) async {
    final temp = File('${dir.path}/surah.zip');
    try {
      await _fetch(
        url,
        temp,
        onProgress:
            (fraction) => _set(
              key,
              DownloadTask(
                phase: DownloadPhase.downloading,
                progress: fraction * 0.9,
                detail: '${(fraction * 100).round()}%',
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
  ) async {
    final count = surahAyahCounts[surah - 1];
    var done = 0;
    for (var ayah = 1; ayah <= count; ayah++) {
      final target = File(localAyahPath(dir.path, surah, ayah));
      if (await target.exists() && await target.length() > 1024) {
        done++;
        continue;
      }
      final part = File('${target.path}.part');
      await _fetch(
        ayahAudioUrl(reciter, surah, ayah),
        part,
        onProgress:
            (fraction) => _set(
              key,
              DownloadTask(
                phase: DownloadPhase.downloading,
                progress: (done + fraction) / count,
                detail: 'Ayah $done of $count',
              ),
            ),
      );
      await part.rename(target.path);
      done++;
      _set(
        key,
        DownloadTask(
          phase: DownloadPhase.downloading,
          progress: done / count,
          detail: 'Ayah $done of $count',
        ),
      );
    }
  }

  Future<int?> _remoteSize(String url) async {
    final client =
        HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.headUrl(Uri.parse(url));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != HttpStatus.ok) return null;
      return response.contentLength >= 0 ? response.contentLength : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _fetch(
    String url,
    File target, {
    void Function(double fraction)? onProgress,
  }) async {
    final client =
        HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(url));
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
          sink.add(chunk);
          received += chunk.length;
          if (onProgress != null && total > 0) {
            onProgress(received / total);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> downloadPack(Reciter reciter, {void Function()? onDone}) async {
    final key = '${reciter.id}/all';
    if (state[key]?.busy ?? false) return;
    _stopPacks.remove(reciter.id);
    _set(
      key,
      const DownloadTask(phase: DownloadPhase.downloading, detail: 'Starting'),
    );
    try {
      for (var surah = 1; surah <= 114; surah++) {
        if (_stopPacks.remove(reciter.id)) {
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
          await downloadSurah(reciter, surah);
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
    }
  }

  Future<void> stopPack(String reciterId) async {
    _stopPacks.add(reciterId);
  }

  Future<void> deleteSurah(String reciterId, int surah) async {
    final key = _key(reciterId, surah);
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
