import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/models/user_profile_model.dart';
import 'package:mandarin_learning/services/security_service.dart';
import 'package:mandarin_learning/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ketentuan Autentikasi: Enkripsi Password (Non-Firebase)', () {
    test('Password di-hash dengan SHA-256 dan tidak berbentuk plain text', () {
      const rawPassword = 'passwordRahasia123';
      final hash = SecurityService.hashPassword(rawPassword);

      expect(hash, isNotEmpty);
      expect(hash, isNot(equals(rawPassword)));
      // SHA-256 hex string memiliki panjang 64 karakter
      expect(hash.length, equals(64));
    });

    test('Verifikasi password valid dan invalid berjalan akurat', () {
      const password = 'mySecretPassword!2026';
      final hash = SecurityService.hashPassword(password);

      expect(SecurityService.verifyPassword(password, hash), isTrue);
      expect(SecurityService.verifyPassword('wrongPassword', hash), isFalse);
      expect(SecurityService.verifyPassword('MySecretPassword!2026', hash), isFalse);
    });
  });

  group('Ketentuan Session Management', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Sesi login tersimpan dan dapat dipulihkan kembali', () async {
      await SessionService.saveSession(
        userId: 'user_123',
        username: 'lucy_mandarin',
        fullName: 'Lucy Naibaho',
        email: 'lucy@example.com',
      );

      final session = await SessionService.getSession();
      expect(session, isNotNull);
      expect(session!.userId, equals('user_123'));
      expect(session.username, equals('lucy_mandarin'));
      expect(session.fullName, equals('Lucy Naibaho'));
      expect(session.isLoggedIn, isTrue);
    });

    test('Logout menghapus sesi pengguna dengan bersih', () async {
      await SessionService.saveSession(
        userId: 'user_123',
        username: 'lucy_mandarin',
        fullName: 'Lucy Naibaho',
      );

      var session = await SessionService.getSession();
      expect(session, isNotNull);

      await SessionService.clearSession();
      session = await SessionService.getSession();
      expect(session, isNull);
    });

    test('Preferensi login biometrik dapat disimpan dan dibaca', () async {
      expect(await SessionService.isBiometricEnabled(), isFalse);

      await SessionService.setBiometricEnabled(true);
      expect(await SessionService.isBiometricEnabled(), isTrue);

      await SessionService.saveSession(
        userId: 'user_99',
        username: 'aria_mandarin',
        fullName: 'Aria Wang',
      );
      expect(await SessionService.getLastBiometricUser(), equals('aria_mandarin'));
    });
  });

  group('Model UserProfile dengan Username dan Penyimpanan Database', () {
    test('UserProfile mendukung username dan email untuk sinkronisasi database', () {
      final json = {
        'id': 'usr_456',
        'username': 'mandarin_learner',
        'email': 'learner@study.com',
        'full_name': 'Serena Halim',
        'avatar_url': '',
        'current_hsk_level': 2,
        'streak': 5,
        'total_xp': 250,
        'coins': 90,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.username, equals('mandarin_learner'));
      expect(profile.email, equals('learner@study.com'));
      expect(profile.fullName, equals('Serena Halim'));
      expect(profile.currentHskLevel, equals(2));
      expect(profile.coins, equals(90));

      final serialized = profile.toJson();
      expect(serialized['username'], equals('mandarin_learner'));
      expect(serialized['email'], equals('learner@study.com'));
    });
  });
}
