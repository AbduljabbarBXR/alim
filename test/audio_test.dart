import 'package:alim/services/audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reciters', () {
    test('three voices, each streamed at 64 kbps', () {
      expect(reciters, hasLength(3));
      expect(reciters.map((r) => r.id).toList(), [
        'alafasy',
        'abdulbasit',
        'husary',
      ]);
      for (final r in reciters) {
        expect(r.name, isNotEmpty);
        expect(r.folder, endsWith('64kbps'));
      }
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
  });
}
