import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  static final _mandarinCharacters = RegExp(
    r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]+',
  );

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('zh-CN');
      try {
        final voices = await _flutterTts.getVoices;
        if (voices is List) {
          final mandarinVoices = voices.whereType<Map>();
          final mainlandVoice = mandarinVoices.where((voice) {
            final locale = voice['locale']
                ?.toString()
                .replaceAll('_', '-')
                .toLowerCase();
            return locale == 'zh-cn' || locale == 'cmn-cn';
          });
          if (mainlandVoice.isNotEmpty) {
            final voice = mainlandVoice.first;
            await _flutterTts.setVoice({
              'name': voice['name'].toString(),
              'locale': voice['locale'].toString(),
            });
          }
        }
      } catch (error) {
        debugPrint(
          '[AudioService] Mandarin voice selection unavailable: $error',
        );
      }
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.45); // Kecepatan nyaman untuk pemula
      _isInitialized = true;
      debugPrint('[AudioService] TTS Mandarin berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('[AudioService] Gagal inisialisasi TTS: $e');
    }
  }

  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    if (!_isInitialized) {
      await initialize();
    }
    if (!_isInitialized) return false;
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
      return true;
    } catch (e) {
      debugPrint('[AudioService] Error saat memutar suara: $e');
      return false;
    }
  }

  String extractMandarinText(String text) => _mandarinCharacters
      .allMatches(text)
      .map((match) => match.group(0)!)
      .join('，');

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('[AudioService] Error saat menghentikan suara: $e');
    }
  }
}
