import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService instance = BiometricService._internal();
  BiometricService._internal();

  static const MethodChannel _settingsChannel = MethodChannel(
    'com.nihaoki.app/biometric_settings',
  );
  final LocalAuthentication _auth = LocalAuthentication();

  /// Memeriksa apakah perangkat mendukung autentikasi biometrik
  Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final canUseWeakBiometrics = await _settingsChannel.invokeMethod<bool?>(
          'canAuthenticate',
        );
        if (canUseWeakBiometrics != null) return canUseWeakBiometrics;
      }
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('[BiometricService] canAuthenticate error: $e');
      return false;
    }
  }

  /// Mengambil tipe biometrik yang tersedia di perangkat (misal: fingerprint, face)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Cek apakah perangkat mendukung pengenalan sidik jari
  Future<bool> hasFingerprint() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _settingsChannel.invokeMethod<bool?>(
          'hasFingerprint',
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[BiometricService] hasFingerprint channel error: $e');
      }
    }
    final types = await getAvailableBiometrics();
    return types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong);
  }

  /// Cek apakah perangkat mendukung pengenalan wajah (Face ID / Face Recognition)
  Future<bool> hasFaceRecognition() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _settingsChannel.invokeMethod<bool?>(
          'hasFaceRecognition',
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[BiometricService] hasFaceRecognition channel error: $e');
      }
    }
    final types = await getAvailableBiometrics();
    return types.contains(BiometricType.face) ||
        types.contains(BiometricType.weak);
  }

  /// Cek apakah perangkat mendukung iris
  Future<bool> hasIris() async {
    final types = await getAvailableBiometrics();
    return types.contains(BiometricType.iris);
  }

  /// Label deskripsi sensor yang tersedia di perangkat
  Future<String> getSensorSummary() async {
    final hasFinger = await hasFingerprint();
    final hasFace = await hasFaceRecognition();

    if (hasFinger && hasFace) {
      return 'Sidik Jari & Pengenalan Wajah';
    } else if (hasFace) {
      return 'Pengenalan Wajah (Face Recognition)';
    } else if (hasFinger) {
      return 'Sidik Jari (Fingerprint)';
    }
    return 'Sensor Biometrik';
  }

  /// Menjalankan prompt autentikasi biometrik
  Future<bool> authenticate({
    String reason = 'Pindai sidik jari atau wajah Anda untuk masuk ke akun',
  }) async {
    if (kIsWeb) {
      debugPrint(
        '[BiometricService] Biometrik tidak didukung pada browser web.',
      );
      return false;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidResult = await _settingsChannel.invokeMethod<bool?>(
          'authenticate',
          {'reason': reason},
        );
        if (androidResult != null) return androidResult;
      }
      final isSupported = await canAuthenticate();
      if (!isSupported) {
        debugPrint(
          '[BiometricService] Biometrik tidak didukung di perangkat ini.',
        );
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      debugPrint(
        '[BiometricService] PlatformException: ${e.code} - ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }

  Future<bool> openEnrollmentSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _settingsChannel.invokeMethod<bool>('openEnrollment') ??
          false;
    } on PlatformException catch (error) {
      debugPrint(
        '[BiometricService] Gagal membuka pengaturan biometrik: '
        '${error.code} - ${error.message}',
      );
      return false;
    }
  }
}
