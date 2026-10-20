import 'package:alim/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the transliteration asset covers every ayah', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final transliterations = await container.read(
      quranTransliterationProvider.future,
    );

    expect(transliterations, hasLength(6236));
    expect(transliterations[1], 'Bismillaahir-rahmaanir-raheem');
    expect(transliterations[6236], isNotEmpty);
    expect(
      transliterations.values.every((line) => line.trim().isNotEmpty),
      isTrue,
    );
  });
}
