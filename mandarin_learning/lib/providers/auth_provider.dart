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

  UserProfile? get profile => _profile;
  List<CoinTransaction> get coinTransactions =>
      List.unmodifiable(_coinTransactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _profile != null;
  bool get isGuest => _isGuest;
  bool get isBiometricSupported => _isBiometricSupported;

  int get coins => _profile?.coins ?? 50;
  int get streak => _profile?.streak ?? 1;
  int get totalXp => _profile?.totalXp ?? 0;
  int get currentHskLevel => _profile?.currentHskLevel ?? 1;

  /// Inisialisasi awal: cek session, biometric support, dan database lokal
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Inisialisasi database lokal SQLite
      await LocalDatabaseService.instance.initialize();

      // Cek ketersediaan sensor biometrik
      _isBiometricSupported = await BiometricService.instance.canAuthenticate();

      final prefs = await SharedPreferences.getInstance();
      final guestMode = prefs.getBool('is_guest_mode') ?? false;

      if (guestMode) {
        _isGuest = true;
        _profile = UserProfile(
          id: 'guest_local_user',
          fullName: prefs.getString('guest_name') ?? 'Pelajar Mandarin',
          avatarUrl: '',
          currentHskLevel: prefs.getInt('guest_hsk') ?? 1,
          streak: prefs.getInt('guest_streak') ?? 1,
          lastActiveDate: DateTime.now(),
          totalXp: prefs.getInt('guest_xp') ?? 120,
          coins: prefs.getInt('guest_coins') ?? 50,
        );
      } else {
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
      _isGuest = false;

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
          _errorMessage =
              'Username ini sudah tersimpan di perangkat. Masukkan kata sandi akun tersebut untuk menyinkronkan.';
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
      debugPrint('[AuthProvider] ✅ Akun tersimpan di SQLite lokal: $cleanUsername');

      // 3. Simpan ke database online Supabase
      try {
        await SupabaseService.instance.registerAppUser(
          id: userMap['id'].toString(),
          username: cleanUsername,
          passwordHash: userMap['password_hash'].toString(),
          fullName: userMap['full_name']?.toString() ?? cleanFullName,
          email: userMap['email']?.toString() ?? cleanEmail,
          currentHskLevel:
              (userMap['current_hsk_level'] as num?)?.toInt() ?? 1,
          streak: (userMap['streak'] as num?)?.toInt() ?? 1,
          totalXp: (userMap['total_xp'] as num?)?.toInt() ?? 0,
          coins: (userMap['coins'] as num?)?.toInt() ?? 50,
          createdAt: userMap['created_at']?.toString(),
        );
        debugPrint('[AuthProvider] ✅ Akun berhasil disimpan ke Supabase online.');
      } catch (e) {
        debugPrint('[AuthProvider] ⚠️ Gagal simpan ke Supabase (offline/network): $e');
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

  /// Login menggunakan sensor biometrik (Fingerprint / Face ID)
  Future<bool> loginWithBiometrics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authenticated = await BiometricService.instance.authenticate(
        reason: 'Verifikasi biometrik untuk masuk ke akun Mandarin Learning',
      );

      if (!authenticated) {
        _errorMessage = 'Autentikasi biometrik dibatalkan atau tidak dikenali.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Ambil username terakhir yang pernah login di perangkat ini
      String? targetUser = await SessionService.getLastBiometricUser();

      // Jika belum ada session sebelumnya, ambil user pertama dari database lokal
      if (targetUser == null || targetUser.isEmpty) {
        final allUsers = await LocalDatabaseService.instance.getAllUsers();
        if (allUsers.isNotEmpty) {
          targetUser = allUsers.first['username'] as String?;
        }
      }

      if (targetUser == null) {
        _errorMessage = 'Belum ada akun tersimpan di perangkat ini. Silakan login atau registrasi manual terlebih dahulu.';
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
        _errorMessage = 'Data akun biometrik tidak ditemukan.';
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

      _profile = UserProfile.fromJson(userData);

      try {
        _coinTransactions
          ..clear()
          ..addAll(await SupabaseService.instance.fetchCoinHistory(userId));
      } catch (_) {}

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_mode', true);

    _profile = UserProfile(
      id: 'guest_local_user',
      username: 'guest',
      email: '',
      fullName: 'Pelajar Mandiri',
      avatarUrl: '',
      currentHskLevel: 1,
      streak: 3,
      lastActiveDate: DateTime.now(),
      totalXp: 150,
      coins: 50,
    );
    notifyListeners();
  }

  /// Logout dan hapus sesi
  Future<void> logout() async {
    await SessionService.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest_mode');
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
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('guest_coins', newCoins);
      await prefs.setInt('guest_xp', newXp);
    }

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
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('guest_coins', newCoins);
    }

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
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('guest_hsk', level);
    }
  }
}
