import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coin_transaction_model.dart';
import '../models/user_profile_model.dart';
import '../services/biometric_service.dart';
import '../services/local_database_service.dart';
import '../services/security_service.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  UserProfile? _profile;
  final List<CoinTransaction> _coinTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isGuest = false;
  bool _isBiometricSupported = false;
  int _dailyGoalMinutes = 20;

  // Status Pendaftaran Biometrik (Sidik Jari & Pengenalan Wajah)
  bool _isBiometricEnrolled = false;
  String? _enrolledBiometricUsername;
  String? _enrolledBiometricFullName;
  String? _lastBiometricUsername;
  bool _hasFingerprintSensor = false;
  bool _hasFaceSensor = false;
  bool _isFingerprintAllowed = true;
  bool _isFaceAllowed = true;
  String _biometricSensorLabel = 'Biometrik (Sidik Jari / Wajah)';

  UserProfile? get profile => _profile;
  List<CoinTransaction> get coinTransactions =>
      List.unmodifiable(_coinTransactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _profile != null;
  bool get isGuest => _isGuest;
  bool get isBiometricSupported => _isBiometricSupported;

  // Getters Biometrik
  bool get isBiometricEnrolled => _isBiometricEnrolled;
  String? get enrolledBiometricUsername => _enrolledBiometricUsername;
  String? get biometricLoginUsername =>
      _lastBiometricUsername ?? _enrolledBiometricUsername;
  String? get enrolledBiometricFullName => _enrolledBiometricFullName;
  bool get hasFingerprintSensor => _hasFingerprintSensor;
  bool get hasFaceSensor => _hasFaceSensor;
  bool get isFingerprintAllowed => _isFingerprintAllowed;
  bool get isFaceAllowed => _isFaceAllowed;
  String get biometricSensorLabel => _biometricSensorLabel;

  /// Memeriksa apakah biometrik di perangkat ini aktif untuk akun yang sedang login saat ini
  bool get isBiometricEnrolledForCurrentUser {
    if (!_isBiometricEnrolled || _profile == null) return false;
    final enrolledUser = _enrolledBiometricUsername?.trim().toLowerCase();
    final currentUser = _profile?.username.trim().toLowerCase();
    return enrolledUser != null &&
        enrolledUser.isNotEmpty &&
        enrolledUser == currentUser;
  }

  int get coins => _profile?.coins ?? 50;
  int get streak => _profile?.streak ?? 1;
  int get totalXp => _profile?.totalXp ?? 0;
  int get currentHskLevel => _profile?.currentHskLevel ?? 1;
  int get dailyGoalMinutes => _dailyGoalMinutes;

  Future<void> updateDailyGoalMinutes(int minutes) async {
    _dailyGoalMinutes = minutes;
    notifyListeners();
    if (!_isGuest) {
      await SessionService.setDailyGoalMinutes(minutes);
    }
  }

  /// Memperbarui informasi ketersediaan sensor dan status pendaftaran biometrik
  Future<void> refreshBiometricStatus() async {
    _isBiometricSupported = await BiometricService.instance.canAuthenticate();
    _hasFingerprintSensor = false;
    _hasFaceSensor = false;
    if (_isBiometricSupported) {
      _hasFingerprintSensor = await BiometricService.instance.hasFingerprint();
      _hasFaceSensor = await BiometricService.instance.hasFaceRecognition();
      _biometricSensorLabel = await BiometricService.instance
          .getSensorSummary();
    }
    _isBiometricEnrolled = await SessionService.isBiometricEnrolled();
    _enrolledBiometricUsername =
        await SessionService.getEnrolledBiometricUsername();
    _lastBiometricUsername = await SessionService.getLastBiometricUser();
    _enrolledBiometricFullName =
        await SessionService.getEnrolledBiometricFullName();
    _isFingerprintAllowed = await SessionService.isFingerprintAllowed();
    _isFaceAllowed = await SessionService.isFaceAllowed();
    notifyListeners();
  }

  /// Inisialisasi awal: cek session, biometric support, dan database lokal
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Inisialisasi database lokal SQLite
      await LocalDatabaseService.instance.initialize();

      // Cek ketersediaan sensor & pendaftaran biometrik
      await refreshBiometricStatus();

      final prefs = await SharedPreferences.getInstance();
      final guestMode = prefs.getBool('is_guest_mode') ?? false;

      if (guestMode) {
        _isGuest = true;
        _dailyGoalMinutes = 20;
        // Mode Tamu (Akses Terbatas): tidak menyimpan progres apapun
        _profile = UserProfile(
          id: 'guest_temp',
          username: 'guest',
          fullName: 'Tamu (Akses Terbatas)',
          avatarUrl: '',
          currentHskLevel: 1,
          streak: 0,
          lastActiveDate: DateTime.now(),
          totalXp: 0,
          coins: 0,
        );
        _coinTransactions.clear();
      } else {
        _dailyGoalMinutes = await SessionService.getDailyGoalMinutes();
        // Cek sesi aktif dari SessionService
        final session = await SessionService.getSession();
        if (session != null) {
          // Cari data pengguna dari database lokal atau Supabase online
          Map<String, dynamic>? userData = await LocalDatabaseService.instance
              .getUserById(session.userId);

          // Coba ambil dari online database jika tersedia
          try {
            final onlineUser = await SupabaseService.instance.getAppUserById(
              session.userId,
            );
            if (onlineUser != null) {
              userData = onlineUser;
              await LocalDatabaseService.instance.saveOrUpdateUser(onlineUser);
            }
          } catch (_) {}

          if (userData != null) {
            _profile = UserProfile.fromJson(userData);
          } else {
            _profile = UserProfile(
              id: session.userId,
              username: session.username,
              fullName: session.fullName,
              email: session.email,
              avatarUrl: '',
              currentHskLevel: 1,
              streak: 1,
              lastActiveDate: DateTime.now(),
              totalXp: 0,
              coins: 50,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] checkSession error: $e');
    }

    if (_profile != null && !_isGuest) {
      try {
        _coinTransactions
          ..clear()
          ..addAll(
            await SupabaseService.instance.fetchCoinHistory(_profile!.id),
          );
      } catch (_) {}
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Login dengan enkripsi password (tidak menggunakan Firebase)
  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final trimmedInput = usernameOrEmail.trim();

    try {
      // 1. Coba cari di database online Supabase (tabel app_users)
      Map<String, dynamic>? userRecord;
      try {
        userRecord = await SupabaseService.instance.getAppUserByUsername(
          trimmedInput,
        );
        if (userRecord == null && trimmedInput.contains('@')) {
          userRecord = await SupabaseService.instance.getAppUserByEmail(
            trimmedInput,
          );
        }
      } catch (e) {
        debugPrint('[AuthProvider] Online query failed, fallback to local: $e');
      }

      // 2. Jika tidak ditemukan online atau offline, cari di database lokal SQLite
      userRecord ??= await LocalDatabaseService.instance.getUserByIdentifier(
        trimmedInput,
      );

      if (userRecord == null) {
        _errorMessage = 'Username atau akun tidak ditemukan. Silakan daftar terlebih dahulu.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. Verifikasi kata sandi dengan SHA-256 hash
      final storedHash = userRecord['password_hash'] as String? ?? '';
      final isPasswordValid = SecurityService.verifyPassword(
        password,
        storedHash,
      );

      if (!isPasswordValid) {
        _errorMessage = 'Kata sandi yang Anda masukkan salah.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 4. Sinkronkan ke database lokal jika baru diambil dari online
      await LocalDatabaseService.instance.saveOrUpdateUser(userRecord);

      // 5. Simpan Session Login Pengguna
      final userId = userRecord['id'].toString();
      final username = userRecord['username'].toString();
      final fullName =
          userRecord['full_name']?.toString() ?? 'Pelajar Mandarin';
      final email = userRecord['email']?.toString() ?? '';

      await SessionService.saveSession(
        userId: userId,
        username: username,
        fullName: fullName,
        email: email,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest_mode', false);
      await prefs.setString('last_registered_username', username);
      _isGuest = false;
      _dailyGoalMinutes = await SessionService.getDailyGoalMinutes();

      _profile = UserProfile.fromJson(userRecord);

      // Ambil riwayat koin
      try {
        _coinTransactions
          ..clear()
          ..addAll(await SupabaseService.instance.fetchCoinHistory(userId));
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal masuk: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Registrasi akun baru dengan username, password terenkripsi, tersimpan di database lokal & online
  Future<bool> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
    bool enableBiometric = false,
    bool enableFingerprint = false,
    bool enableFace = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final cleanUsername = username.trim().toLowerCase();
    final cleanFullName = fullName.trim();
    final cleanEmail = email?.trim().toLowerCase() ?? '';

    try {
      // 1. Pastikan username belum terdaftar di Supabase.
      try {
        final existingOnline = await SupabaseService.instance
            .getAppUserByUsername(cleanUsername);
        if (existingOnline != null) {
          _errorMessage = 'Username "$cleanUsername" sudah terdaftar online.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Supabase check warning: $e');
        // Lanjutkan — mungkin tidak ada koneksi internet, coba daftar lokal dulu
      }

      // Registrasi lama yang gagal sinkron dapat meninggalkan akun lokal.
      // Cocokkan password sebelum menyinkronkannya agar progres tidak hilang.
      final existingLocal = await LocalDatabaseService.instance
          .getUserByUsername(cleanUsername);
      final Map<String, dynamic> userMap;
      if (existingLocal != null) {
        final storedHash = existingLocal['password_hash'] as String? ?? '';
        if (!SecurityService.verifyPassword(password, storedHash)) {
          _errorMessage = 'Username ini sudah tersimpan di perangkat. Masukkan kata sandi akun tersebut untuk menyinkronkan.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        userMap = existingLocal;
      } else {
        final now = DateTime.now().toUtc().toIso8601String();
        userMap = {
          'id':
              'usr_${DateTime.now().millisecondsSinceEpoch}_${cleanUsername.hashCode.abs()}',
          'username': cleanUsername,
          'password_hash': SecurityService.hashPassword(password),
          'full_name': cleanFullName,
          'email': cleanEmail,
          'current_hsk_level': 1,
          'streak': 1,
          'total_xp': 0,
          'coins': 50,
          'created_at': now,
          'updated_at': now,
        };
      }

      // 2. Simpan ke database lokal SQLite terlebih dahulu
      await LocalDatabaseService.instance.saveOrUpdateUser(userMap);
      debugPrint(
        '[AuthProvider] ✅ Akun tersimpan di SQLite lokal: $cleanUsername',
      );

      // 3. Simpan ke database online Supabase
      try {
        await SupabaseService.instance.registerAppUser(
          id: userMap['id'].toString(),
          username: cleanUsername,
          passwordHash: userMap['password_hash'].toString(),
          fullName: userMap['full_name']?.toString() ?? cleanFullName,
          email: userMap['email']?.toString() ?? cleanEmail,
          currentHskLevel: (userMap['current_hsk_level'] as num?)?.toInt() ?? 1,
          streak: (userMap['streak'] as num?)?.toInt() ?? 1,
          totalXp: (userMap['total_xp'] as num?)?.toInt() ?? 0,
          coins: (userMap['coins'] as num?)?.toInt() ?? 50,
          createdAt: userMap['created_at']?.toString(),
        );
        debugPrint(
          '[AuthProvider] ✅ Akun berhasil disimpan ke Supabase online.',
        );
      } catch (e) {
        debugPrint(
          '[AuthProvider] ⚠️ Gagal simpan ke Supabase (offline/network): $e',
        );
      }

      // Pastikan sesi dan profil TIDAK diset saat daftar,
      // agar tidak otomatis dianggap authenticated / langsung ke dashboard
      _profile = null;
      _isGuest = false;

      // Catatan alur: Setelah mendaftar, akun tersimpan di database (lokal & online),
      // namun TIDAK langsung dibuatkan sesi login aktif dan TIDAK langsung masuk dashboard.
      // Pengguna diarahkan ke halaman login terlebih dahulu untuk melakukan autentikasi.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_registered_username', cleanUsername);
      await prefs.setBool('is_guest_mode', false);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mendaftar: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Mendaftarkan biometrik (Sidik Jari & Wajah) dengan verifikasi sensor terlebih dahulu
  Future<bool> enrollBiometric({
    String? targetUserId,
    String? targetUsername,
    String? targetFullName,
    bool allowFingerprint = true,
    bool allowFace = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasFingerprint = await BiometricService.instance.hasFingerprint();
      final hasFace = await BiometricService.instance.hasFaceRecognition();
      if (!hasFingerprint && !hasFace) {
        _errorMessage = 'Perangkat ini tidak memiliki atau belum mengaktifkan sensor biometrik.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final uId = targetUserId ?? _profile?.id;
      final uName = targetUsername ?? _profile?.username;
      final fName =
          targetFullName ?? (_profile?.fullName ?? 'Pelajar Mandarin');

      if (uId == null || uName == null || uName.isEmpty) {
        _errorMessage =
            'Tidak ada akun yang aktif untuk didaftarkan biometrik.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 1. Verifikasi fisik dengan sensor biometrik (sidik jari atau pengenalan wajah)
      final sensorLabel = await BiometricService.instance.getSensorSummary();
      final verified = await BiometricService.instance.authenticate(
        reason: 'Pindai $sensorLabel untuk mendaftarkan akun @$uName',
      );

      if (!verified) {
        _errorMessage = 'Pendaftaran biometrik dibatalkan atau sensor tidak mengenali Anda.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Simpan data pendaftaran akun ke SessionService
      await SessionService.enrollBiometric(
        userId: uId,
        username: uName,
        fullName: fName,
        allowFingerprint: allowFingerprint && hasFingerprint,
        allowFace: allowFace && hasFace,
      );

      await refreshBiometricStatus();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mendaftarkan biometrik: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Menghapus pendaftaran biometrik
  Future<bool> unenrollBiometric() async {
    _isLoading = true;
    notifyListeners();

    try {
      await SessionService.unenrollBiometric();
      await refreshBiometricStatus();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus pendaftaran biometrik: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Mengatur preferensi sensor yang diizinkan (Sidik Jari / Wajah)
  Future<void> setBiometricSensorPreference({
    bool? fingerprint,
    bool? face,
  }) async {
    if (fingerprint != null) {
      await SessionService.setFingerprintAllowed(fingerprint);
      _isFingerprintAllowed = fingerprint;
    }
    if (face != null) {
      await SessionService.setFaceAllowed(face);
      _isFaceAllowed = face;
    }
    if (!_isFingerprintAllowed && !_isFaceAllowed) {
      await SessionService.setBiometricEnabled(false);
    } else {
      await SessionService.setBiometricEnabled(true);
    }
    notifyListeners();
  }

  /// Login menggunakan sensor biometrik (Sidik Jari / Pengenalan Wajah)
  Future<bool> loginWithBiometrics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isSupported = await BiometricService.instance.canAuthenticate();
      if (!isSupported) {
        _errorMessage = 'Perangkat ini tidak mendukung atau belum mengaktifkan sensor biometrik.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // The device verifies the biometric; the app uses the last account that
      // successfully signed in to determine which profile to restore.
      final targetUser =
          await SessionService.getLastBiometricUser() ??
          await SessionService.getEnrolledBiometricUsername();

      if (targetUser == null || targetUser.isEmpty) {
        _errorMessage = 'Tidak ditemukan akun terakhir yang masuk di perangkat ini.\n\nSilakan masuk dengan kata sandi terlebih dahulu.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final authenticated = await BiometricService.instance.authenticate(
        reason: 'Verifikasi biometrik untuk masuk sebagai @$targetUser',
      );

      if (!authenticated) {
        _errorMessage = 'Autentikasi biometrik dibatalkan atau sensor tidak mengenali Anda.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Ambil data user dari database lokal atau online
      Map<String, dynamic>? userData = await LocalDatabaseService.instance
          .getUserByUsername(targetUser);

      try {
        final onlineData = await SupabaseService.instance.getAppUserByUsername(
          targetUser,
        );
        if (onlineData != null) {
          userData = onlineData;
          await LocalDatabaseService.instance.saveOrUpdateUser(onlineData);
        }
      } catch (_) {}

      if (userData == null) {
        _errorMessage =
            'Data akun terakhir yang masuk (@$targetUser) tidak ditemukan di perangkat. Silakan login manual dengan kata sandi.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Set sesi aktif
      final userId = userData['id'].toString();
      final username = userData['username'].toString();
      final fullName = userData['full_name']?.toString() ?? 'Pelajar Mandarin';
      final email = userData['email']?.toString() ?? '';

      await SessionService.saveSession(
        userId: userId,
        username: username,
        fullName: fullName,
        email: email,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest_mode', false);
      _isGuest = false;
      _dailyGoalMinutes = await SessionService.getDailyGoalMinutes();

      _profile = UserProfile.fromJson(userData);

      try {
        _coinTransactions
          ..clear()
          ..addAll(await SupabaseService.instance.fetchCoinHistory(userId));
      } catch (_) {}

      await refreshBiometricStatus();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal autentikasi biometrik: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loginAsGuest() async {
    _isGuest = true;
    _dailyGoalMinutes = 20;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_mode', true);
    // Hapus sisa cache progres tamu lama agar sesi selalu bersih dan tidak menyimpan progres apapun
    await prefs.remove('guest_coins');
    await prefs.remove('guest_xp');
    await prefs.remove('guest_hsk');
    await prefs.remove('guest_streak');

    _profile = UserProfile(
      id: 'guest_local_user',
      username: 'guest',
      email: '',
      fullName: 'Tamu (Akses Terbatas)',
      avatarUrl: '',
      currentHskLevel: 1,
      streak: 0,
      lastActiveDate: DateTime.now(),
      totalXp: 0,
      coins: 0,
    );
    _coinTransactions.clear();
    notifyListeners();
  }

  /// Logout dan hapus sesi
  Future<void> logout() async {
    await SessionService.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest_mode');
    await prefs.remove('guest_coins');
    await prefs.remove('guest_xp');
    await prefs.remove('guest_hsk');
    await prefs.remove('guest_streak');
    _profile = null;
    _coinTransactions.clear();
    _isGuest = false;
    notifyListeners();
  }

  Future<void> addCoins(
    int amount,
    String type,
    String description, {
    String? attemptId,
  }) async {
    if (_profile == null || amount <= 0) return;

    final profile = _profile!;
    final transactionId =
        attemptId ?? '${type}_${DateTime.now().microsecondsSinceEpoch}';
    if (_coinTransactions.any(
      (transaction) => transaction.attemptId == transactionId,
    )) {
      return;
    }

    final newCoins = profile.coins + amount;
    final newXp = profile.totalXp + amount;
    _profile = profile.copyWith(coins: newCoins, totalXp: newXp);

    if (!_isGuest) {
      // Simpan ke SQLite lokal
      await LocalDatabaseService.instance.updateUserStats(
        id: profile.id,
        coins: newCoins,
        totalXp: newXp,
      );

      // Simpan ke online database jika tersambung
      try {
        await SupabaseService.instance.updateAppUserStats(
          id: profile.id,
          coins: newCoins,
          totalXp: newXp,
        );
        await SupabaseService.instance.addCoinTransaction(
          userId: profile.id,
          amount: amount,
          transactionType: type,
          description: description,
          attemptId: transactionId,
        );
      } catch (_) {}
    }
    // Catatan: Mode Tamu TIDAK menyimpan progres apapun ke disk atau database.

    _coinTransactions.insert(
      0,
      CoinTransaction(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        userId: profile.id,
        attemptId: transactionId,
        amount: amount,
        transactionType: type,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<bool> deductCoins(
    int amount,
    String type,
    String description, {
    String? attemptId,
  }) async {
    if (_profile == null || _profile!.coins < amount) return false;

    final profile = _profile!;
    final transactionId =
        attemptId ?? '${type}_${DateTime.now().microsecondsSinceEpoch}';
    if (_coinTransactions.any(
      (transaction) => transaction.attemptId == transactionId,
    )) {
      return false;
    }

    final newCoins = profile.coins - amount;
    _profile = profile.copyWith(coins: newCoins);

    if (!_isGuest) {
      // Update SQLite lokal
      await LocalDatabaseService.instance.updateUserStats(
        id: profile.id,
        coins: newCoins,
      );

      // Update online database jika tersambung
      try {
        await SupabaseService.instance.updateAppUserStats(
          id: profile.id,
          coins: newCoins,
        );
        await SupabaseService.instance.addCoinTransaction(
          userId: profile.id,
          amount: -amount,
          transactionType: type,
          description: description,
          attemptId: transactionId,
        );
      } catch (_) {}
    }
    // Catatan: Mode Tamu TIDAK menyimpan progres apapun ke disk atau database.

    _coinTransactions.insert(
      0,
      CoinTransaction(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        userId: profile.id,
        attemptId: transactionId,
        amount: -amount,
        transactionType: type,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  Future<void> setHskLevel(int level) async {
    if (_profile == null || level < 1 || level > 6) return;
    _profile = _profile!.copyWith(currentHskLevel: level);
    notifyListeners();

    if (!_isGuest) {
      await LocalDatabaseService.instance.updateUserStats(
        id: _profile!.id,
        currentHskLevel: level,
      );
      try {
        await SupabaseService.instance.updateAppUserStats(
          id: _profile!.id,
          currentHskLevel: level,
        );
      } catch (_) {}
    }
    // Catatan: Mode Tamu TIDAK menyimpan progres apapun ke disk atau database.
  }
}
