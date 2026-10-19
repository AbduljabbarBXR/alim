import 'package:alim/services/audio.dart';
import 'package:alim/services/audio_downloads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("surah ayah counts cover the whole Qur'an", () {
    expect(surahAyahCounts, hasLength(114));
    expect(surahAyahCounts.reduce((a, b) => a + b), 6236);
    expect(surahAyahCounts.first, 7);
    expect(surahAyahCounts.last, 6);
  });

  group('reciters', () {
    test('a small market of voices, each with its own bitrate', () {
      expect(reciters, hasLength(9));
      expect(reciters.first.id, 'alafasy');
      for (final r in reciters) {
        expect(r.name, isNotEmpty);
        expect(r.folder, isNotEmpty);
        expect(r.kbps, greaterThan(0));
        expect(r.style, isNotEmpty);
      }
      expect(reciterById('ghamidi').kbps, 40);
    });

    test('an unknown id falls back to the first voice', () {
      expect(reciterById('not-a-reciter').id, 'alafasy');
    });

    test('ayah urls are zero padded the way everyayah names its files', () {
      final alafasy = reciterById('alafasy');
      expect(
        ayahAudioUrl(alafasy, 1, 1),
        'https://everyayah.com/data/Alafasy_64kbps/001001.mp3',
      );
      expect(
        ayahAudioUrl(alafasy, 2, 255),
        'https://everyayah.com/data/Alafasy_64kbps/002255.mp3',
      );
      expect(
        ayahAudioUrl(alafasy, 114, 6),
        'https://everyayah.com/data/Alafasy_64kbps/114006.mp3',
      );
      final husary = reciterById('husary');
      expect(
        ayahAudioUrl(husary, 36, 1),
        'https://everyayah.com/data/Husary_64kbps/036001.mp3',
      );
    });

    test('surah zips sit beside the loose files', () {
      final alafasy = reciterById('alafasy');
      expect(
        surahZipUrl(alafasy, 1),
        'https://everyayah.com/data/Alafasy_64kbps/zips/001.zip',
      );
      expect(localAyahPath('/tmp/audio', 2, 255), '/tmp/audio/002255.mp3');
    });
  });
}
