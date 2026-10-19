import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models.dart';

/// A reciter whose ayah-by-ayah recordings stream from everyayah.com at
/// 64 kbps, roughly 17 hours of Qur'an for about 500 MB if it were ever
/// saved, so it is streamed instead.
class Reciter {
  const Reciter({
    required this.id,
    required this.name,
    required this.folder,
    this.style = 'Murattal',
    this.kbps = 64,
  });

  final String id;
  final String name;
  final String folder;
  final String style;
  final int kbps;
}

const reciters = <Reciter>[
  Reciter(
    id: 'alafasy',
    name: 'Mishary Rashid Alafasy',
    folder: 'Alafasy_64kbps',
  ),
  Reciter(
    id: 'abdulbasit',
    name: 'Abdul Basit (Murattal)',
    folder: 'Abdul_Basit_Murattal_64kbps',
  ),
  Reciter(
    id: 'abdulbasit_mujawwad',
    name: 'Abdul Basit (Mujawwad)',
    folder: 'Abdul_Basit_Mujawwad_128kbps',
    style: 'Mujawwad',
    kbps: 128,
  ),
  Reciter(
    id: 'husary',
    name: 'Mahmoud Khalil Al-Husary',
    folder: 'Husary_64kbps',
  ),
  Reciter(
    id: 'husary_mujawwad',
    name: 'Al-Husary (Mujawwad)',
    folder: 'Husary_Mujawwad_64kbps',
    style: 'Mujawwad',
  ),
  Reciter(
    id: 'minshawy',
    name: 'Mohamed Siddiq Al-Minshawi',
    folder: 'Minshawy_Murattal_128kbps',
    kbps: 128,
  ),
  Reciter(
    id: 'sudais',
    name: 'Abdurrahman As-Sudais',
    folder: 'Abdurrahmaan_As-Sudais_192kbps',
    kbps: 192,
  ),
  Reciter(
    id: 'shuraym',
    name: 'Saud Ash-Shuraym',
    folder: 'Saood_ash-Shuraym_128kbps',
    kbps: 128,
  ),
  Reciter(
    id: 'ghamidi',
    name: 'Saad Al-Ghamdi',
    folder: 'Ghamadi_40kbps',
    kbps: 40,
  ),
];

Reciter reciterById(String id) =>
    reciters.firstWhere((r) => r.id == id, orElse: () => reciters.first);

/// EveryAyah names its files `SSSAAA.mp3`, zero-padded to three digits.
String ayahAudioUrl(Reciter reciter, int surah, int ayah) {
  final s = surah.toString().padLeft(3, '0');
  final a = ayah.toString().padLeft(3, '0');
  return 'https://everyayah.com/data/${reciter.folder}/$s$a.mp3';
}

/// The per-surah archive EveryAyah keeps beside the loose files.
String surahZipUrl(Reciter reciter, int surah) {
  final s = surah.toString().padLeft(3, '0');
  return 'https://everyayah.com/data/${reciter.folder}/zips/$s.zip';
}

/// Where a downloaded ayah lives once a surah is unpacked.
String localAyahPath(String directory, int surah, int ayah) {
  final s = surah.toString().padLeft(3, '0');
  final a = ayah.toString().padLeft(3, '0');
  return '$directory/$s$a.mp3';
}

class AudioView {
  const AudioView({
    this.surah,
    this.ayah,
    this.reciterName,
    this.playing = false,
    this.loading = false,
    this.failed = false,
  });

  final int? surah;
  final int? ayah;
  final String? reciterName;
  final bool playing;
  final bool loading;
  final bool failed;

  bool get active => surah != null;
}

/// Plays the Qur'an ayah by ayah. The player itself is built on the first
/// press, so the app carries on as before when no one listens.
class AyahAudio extends StateNotifier<AudioView> {
  AyahAudio() : super(const AudioView());

  AudioPlayer? _player;
  final List<int> _ayahNumbers = [];
  int? _surah;
  Reciter? _reciter;
  StreamSubscription<SequenceState?>? _sequenceSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<PlayerException>? _errorSub;

  AudioPlayer _ensure() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _sequenceSub = player.sequenceStateStream.listen((seq) {
      final idx = seq.currentIndex;
      if (idx == null || idx < 0 || idx >= _ayahNumbers.length) return;
      state = AudioView(
        surah: _surah,
        ayah: _ayahNumbers[idx],
        reciterName: _reciter?.name,
        playing: state.playing,
        loading: state.loading,
      );
    });
    _stateSub = player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        _reset();
        return;
      }
      final loading =
          ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering;
      state = AudioView(
        surah: _surah,
        ayah: state.ayah,
        reciterName: _reciter?.name,
        playing: ps.playing,
        loading: loading,
      );
    });
    _errorSub = player.errorStream.listen((_) {
      final p = _player;
      if (p == null) return;
      int? idx;
      try {
        idx = p.sequenceState.currentIndex;
      } catch (_) {
        idx = null;
      }
      if (idx != null && idx >= 0 && idx < _ayahNumbers.length - 1) {
        p.seekToNext();
      } else {
        stop();
      }
    });
    return _player = player;
  }

  void _reset() {
    _surah = null;
    _reciter = null;
    _ayahNumbers.clear();
    state = const AudioView();
  }

  /// The app bar's button: resume or pause what is already playing in this
  /// surah, and otherwise start it from [startAyah] or the top.
  Future<void> toggleSurah({
    required int surahNumber,
    required String surahName,
    required List<Ayah> ayat,
    required Reciter reciter,
    int? startAyah,
    String? localDir,
  }) {
    if (!state.failed && _surah == surahNumber && _reciter?.id == reciter.id) {
      return toggle();
    }
    return play(
      surahNumber: surahNumber,
      surahName: surahName,
      ayat: ayat,
      reciter: reciter,
      startAyah: startAyah,
      localDir: localDir,
    );
  }

  Future<void> play({
    required int surahNumber,
    required String surahName,
    required List<Ayah> ayat,
    required Reciter reciter,
    int? startAyah,
    String? localDir,
  }) async {
    if (ayat.isEmpty) return;
    final player = _ensure();
    _surah = surahNumber;
    _reciter = reciter;
    _ayahNumbers
      ..clear()
      ..addAll(ayat.map((a) => a.number));
    var startIndex = 0;
    if (startAyah != null) {
      final found = _ayahNumbers.indexOf(startAyah);
      if (found >= 0) startIndex = found;
    }
    state = AudioView(
      surah: surahNumber,
      ayah: _ayahNumbers[startIndex],
      reciterName: reciter.name,
      loading: true,
    );
    final sources = <AudioSource>[
      for (final a in ayat)
        AudioSource.uri(
          localDir == null
              ? Uri.parse(ayahAudioUrl(reciter, a.surah, a.ayah))
              : Uri.file(localAyahPath(localDir, a.surah, a.ayah)),
          tag: MediaItem(
            id: '${a.surah}:${a.ayah}',
            title: 'Surah $surahName, ayah ${a.ayah}',
            album: 'Alim, ${reciter.name}',
          ),
        ),
    ];
    try {
      await player.setAudioSources(
        sources,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );
      await player.play();
    } on PlayerInterruptedException {
      // A newer start took over; nothing to fix here.
    } catch (_) {
      state = AudioView(
        surah: surahNumber,
        ayah: _ayahNumbers[startIndex],
        reciterName: reciter.name,
        failed: true,
      );
    }
  }

  Future<void> toggle() async {
    final player = _player;
    if (player == null) return;
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> next() async {
    await _player?.seekToNext();
  }

  Future<void> previous() async {
    await _player?.seekToPrevious();
  }

  Future<void> stop() async {
    final player = _player;
    _reset();
    await player?.stop();
  }

  @override
  void dispose() {
    _sequenceSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
