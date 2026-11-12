import 'package:flutter_test/flutter_test.dart';
import 'package:nihaoki/models/vocabulary_model.dart';
import 'package:nihaoki/services/vocabulary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads example sentences from the JSON matching each HSK level',
    () async {
      final examplesByLevel = {
        1: ('爱', '我爱我的家人。'),
        4: ('爱情', '他们的爱情故事非常感人。'),
        5: ('唉', '唉，今天真累。'),
        6: ('哎哟', '哎哟，我的脚好疼！'),
      };

      for (final entry in examplesByLevel.entries) {
        final item = VocabularyItem(
          id: entry.key,
          hanzi: entry.value.$1,
          pinyin: '',
          artiIndonesia: '',
          translations: const [],
          hskLevel: entry.key,
          contohKalimat: const [],
          sumber: 'test',
        );

        final example = await VocabularyService.instance.createExampleSentence(
          item,
        );

        expect(example.hanzi, entry.value.$2);
      }
    },
  );

  test('keeps HSK 5 and 6 words when remote vocabulary is partial', () async {
    final service = VocabularyService.instance;

    await service.loadVocabulary();

    expect(service.getByLevel(5), isNotEmpty);
    expect(service.getByLevel(6), isNotEmpty);
  });
}
