import 'package:flutter_test/flutter_test.dart';
import 'package:nihaoki/services/speech_evaluation_service.dart';

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

  test('gives realistic 90% validation score when pronunciation matches pinyin or hanzi', () {
    expect(scoreMandarinTranscription('你好', '你好', targetPinyin: 'nǐ hǎo'), 90);
    expect(scoreMandarinTranscription('你好', 'ni hao', targetPinyin: 'nǐ hǎo'), 90);
    expect(scoreMandarinTranscription('你好', 'nihao', targetPinyin: 'nǐ hǎo'), 90);
    expect(scoreMandarinTranscription('你好', 'ni how', targetPinyin: 'nǐ hǎo'), 88);
    expect(scoreMandarinTranscription('谢谢', '谢谢', targetPinyin: 'xiè xie'), 90);
    expect(scoreMandarinTranscription('谢谢', 'xie xie', targetPinyin: 'xiè xie'), 90);
    expect(scoreMandarinTranscription('再见', 'zai jian', targetPinyin: 'zài jiàn'), 90);
  });
}