import 'package:flutter_test/flutter_test.dart';
import 'package:nihaoki/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('extracts only Chinese text for Mandarin speech synthesis', () {
    expect(
      AudioService.instance.extractMandarinText(
        '你好 (nǐ hǎo) berarti halo. 再见!',
      ),
      '你好，再见',
    );
  });

  test('returns empty text when a response contains no Hanzi', () {
    expect(
      AudioService.instance.extractMandarinText('Jawaban bahasa Indonesia.'),
      isEmpty,
    );
  });
}
