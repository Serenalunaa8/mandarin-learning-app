import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/models/user_profile_model.dart';
import 'package:mandarin_learning/providers/auth_provider.dart';
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
      expect(
        SecurityService.verifyPassword('MySecretPassword!2026', hash),
        isFalse,
      );
    });
  });

  group('Ketentuan Session Management & Biometric 1-to-1 Binding', () {
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
      expect(
        await SessionService.getLastBiometricUser(),
        equals('aria_mandarin'),
      );
    });

    test('Pendaftaran biometrik ganda (Sidik Jari & Pengenalan Wajah) berjalan akurat', () async {
      // 1. Awalnya belum didaftarkan
      expect(await SessionService.isBiometricEnrolled(), isFalse);
      expect(await SessionService.getEnrolledBiometricUsername(), isNull);

      // 2. Daftarkan akun dengan sidik jari dan pengenalan wajah
      await SessionService.enrollBiometric(
        userId: 'user_lucy_88',
        username: 'lucy_naibaho',
        fullName: 'Lucy Naibaho',
        allowFingerprint: true,
        allowFace: true,
      );

      // 3. Verifikasi status pendaftaran
      expect(await SessionService.isBiometricEnrolled(), isTrue);
      expect(
        await SessionService.getEnrolledBiometricUsername(),
        equals('lucy_naibaho'),
      );
      expect(
        await SessionService.getEnrolledBiometricFullName(),
        equals('Lucy Naibaho'),
      );
      expect(await SessionService.isFingerprintAllowed(), isTrue);
      expect(await SessionService.isFaceAllowed(), isTrue);

      // 4. Ubah preferensi sensor (misal hanya izinkan wajah)
      await SessionService.setFingerprintAllowed(false);
      expect(await SessionService.isFingerprintAllowed(), isFalse);
      expect(await SessionService.isFaceAllowed(), isTrue);

      await SessionService.setFaceAllowed(false);
      expect(await SessionService.isFingerprintAllowed(), isFalse);
      expect(await SessionService.isFaceAllowed(), isFalse);

      await SessionService.setFingerprintAllowed(true);
      expect(await SessionService.isFingerprintAllowed(), isTrue);
      expect(await SessionService.isFaceAllowed(), isFalse);

      // 5. Hapus pendaftaran biometrik
      await SessionService.unenrollBiometric();
      expect(await SessionService.isBiometricEnrolled(), isFalse);
      expect(await SessionService.getEnrolledBiometricUsername(), isNull);
    });

    test('Biometrik terikat 1-ke-1: Akun B menimpa/menonaktifkan biometrik Akun A', () async {
      // Akun A mendaftarkan biometrik
      await SessionService.enrollBiometric(
        userId: 'user_a',
        username: 'akun_a',
        fullName: 'Akun A',
        allowFingerprint: true,
        allowFace: true,
      );

      expect(await SessionService.isBiometricEnrolled(), isTrue);
      expect(await SessionService.getEnrolledBiometricUsername(), equals('akun_a'));

      // Akun B mengaktifkan biometrik di perangkat yang sama
      await SessionService.enrollBiometric(
        userId: 'user_b',
        username: 'akun_b',
        fullName: 'Akun B',
        allowFingerprint: true,
        allowFace: false,
      );

      // Biometrik akun A sekarang tertimpa oleh akun B
      expect(await SessionService.isBiometricEnrolled(), isTrue);
      expect(await SessionService.getEnrolledBiometricUsername(), equals('akun_b'));
      expect(await SessionService.getEnrolledBiometricUsername(), isNot(equals('akun_a')));
      expect(await SessionService.isFaceAllowed(), isFalse);
    });
  });

  group('Ketentuan Guest Mode (Mode Tamu / Akses Terbatas)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Mode Tamu tidak menyimpan koin, XP, atau progres ke SharedPreferences', () async {
      final auth = AuthProvider();
      await auth.loginAsGuest();

      expect(auth.isGuest, isTrue);
      expect(auth.coins, equals(0));
      expect(auth.totalXp, equals(0));
      expect(auth.streak, equals(0));
      expect(auth.currentHskLevel, equals(1));

      // Tambah koin dan XP selama sesi tamu aktif
      await auth.addCoins(25, 'quiz_reward', 'Kuis Selesai');
      expect(auth.coins, equals(25));
      expect(auth.totalXp, equals(25));

      // Periksa disk SharedPreferences: pastikan tidak ada data progres yang ditulis ke disk
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('guest_coins'), isNull);
      expect(prefs.getInt('guest_xp'), isNull);
      expect(prefs.getInt('guest_hsk'), isNull);
      expect(prefs.getInt('guest_streak'), isNull);

      // Kurangi koin
      final deducted = await auth.deductCoins(10, 'shop', 'Beli petunjuk');
      expect(deducted, isTrue);
      expect(auth.coins, equals(15));
      expect(prefs.getInt('guest_coins'), isNull);

      // Sesi tamu baru selalu mulai dari 0 (tidak mempertahankan progres lama)
      await auth.loginAsGuest();
      expect(auth.coins, equals(0));
      expect(auth.totalXp, equals(0));
    });
  });

  group('Model UserProfile dengan Username dan Penyimpanan Database', () {
    test(
      'UserProfile mendukung username dan email untuk sinkronisasi database',
      () {
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
      },
    );
  });
}
