import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/services/speech_evaluation_service.dart';

void main() {
  test('ignores transcript whitespace and punctuation', () {
    expect(scoreMandarinTranscription('你好', '你好。'), 100);
  });

  test('reports partial and incorrect recognition as lower matches', () {
    expect(scoreMandarinTranscription('你好', '你'), 50);
    expect(scoreMandarinTranscription('你好', '再见'), 0);
  });

  test('does not score empty recognition as a match', () {
    expect(scoreMandarinTranscription('你好', ''), 0);
  });
}
