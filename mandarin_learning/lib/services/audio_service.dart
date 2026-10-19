import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('zh-CN');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.45); // Kecepatan nyaman untuk pemula
      _isInitialized = true;
      debugPrint('[AudioService] TTS Mandarin berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('[AudioService] Gagal inisialisasi TTS: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[AudioService] Error saat memutar suara: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('[AudioService] Error saat menghentikan suara: $e');
    }
  }
}
