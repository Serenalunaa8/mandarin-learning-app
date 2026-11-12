import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SpeechRecognitionSettingsService {
  static const MethodChannel _settingsChannel = MethodChannel(
    'com.nihaoki.app/biometric_settings',
  );

  static Future<bool> openSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _settingsChannel.invokeMethod<bool>('openSpeechSettings') ??
          false;
    } on PlatformException catch (error) {
      debugPrint(
        '[SpeechRecognitionSettings] Tidak dapat membuka pengaturan suara: '
        '${error.code} - ${error.message}',
      );
      return false;
    }
  }
}
