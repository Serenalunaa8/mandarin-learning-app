import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/models/vocabulary_model.dart';
import 'package:mandarin_learning/screens/practice/dictionary_screen.dart';

void main() {
  final vocabulary = [
    VocabularyItem(
      id: 1,
      hanzi: '一',
      pinyin: 'yī',
      artiIndonesia: 'satu',
      translations: const ['satu'],
      hskLevel: 1,
      contohKalimat: const [],
      sumber: 'test',
    ),
    VocabularyItem(
      id: 2,
      hanzi: '爱',
      pinyin: 'ài',
      artiIndonesia: 'cinta',
      translations: const ['cinta'],
      hskLevel: 2,
      contohKalimat: const [],
      sumber: 'test',
    ),
  ];

  test('shows every level when Semua is selected', () {
    expect(filterVocabularyByHskLevel(vocabulary, 0), hasLength(2));
  });

  test(
    'shows words from the selected HSK level regardless of active level',
    () {
      final hskTwo = filterVocabularyByHskLevel(vocabulary, 2);

      expect(hskTwo, hasLength(1));
      expect(hskTwo.single.hskLevel, 2);
      expect(hskTwo.single.hanzi, '爱');
    },
  );
}
