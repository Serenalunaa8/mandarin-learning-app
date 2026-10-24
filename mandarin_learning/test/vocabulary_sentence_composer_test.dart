import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/models/vocabulary_model.dart';
import 'package:mandarin_learning/services/vocabulary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'composes a sentence using words from the bundled vocabulary data',
    () async {
      final item = VocabularyItem(
        id: 1,
        hanzi: '爱',
        pinyin: 'ài',
        artiIndonesia: 'mencintai',
        translations: const ['mencintai'],
        hskLevel: 1,
        contohKalimat: const [],
        sumber: 'test',
      );

      final example = await VocabularyService.instance.createExampleSentence(
        item,
      );

      expect(example.hanzi, '我今天学习「爱」。');
      expect(
        example.arti,
        'Hari ini saya belajar kosakata "爱" yang berarti "mencintai".',
      );
    },
  );
}
