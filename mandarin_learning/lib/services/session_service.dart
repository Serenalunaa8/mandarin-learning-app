import 'package:shared_preferences/shared_preferences.dart';

class UserSessionData {
  final String userId;
  final String username;
  final String fullName;
  final String email;
  final bool isLoggedIn;
  final DateTime? loginTime;

  UserSessionData({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
    required this.isLoggedIn,
    this.loginTime,
  });
}

class SessionService {
  static const String _keyUserId = 'session_user_id';
  static const String _keyUsername = 'session_username';
  static const String _keyFullName = 'session_full_name';
  static const String _keyEmail = 'session_email';
  static const String _keyIsLoggedIn = 'session_is_logged_in';
  static const String _keyLoginTime = 'session_login_time';

  // Biometric session settings & enrollment
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyLastBiometricUser = 'last_biometric_user';
  static const String _keyBiometricEnrolled = 'biometric_enrolled';
  static const String _keyBiometricEnrolledUserId = 'biometric_enrolled_user_id';
  static const String _keyBiometricEnrolledUsername = 'biometric_enrolled_username';
  static const String _keyBiometricEnrolledFullName = 'biometric_enrolled_full_name';
  static const String _keyBiometricAllowFingerprint = 'biometric_allow_fingerprint';
  static const String _keyBiometricAllowFace = 'biometric_allow_face';
  static const String _keyBiometricEnrolledAt = 'biometric_enrolled_at';

  /// Menyimpan sesi login pengguna
  static Future<void> saveSession({
    required String userId,
    required String username,
    required String fullName,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyFullName, fullName);
    await prefs.setString(_keyEmail, email ?? '');
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyLoginTime, DateTime.now().toIso8601String());
    // Simpan juga username terakhir untuk kenyamanan login biometrik
    await prefs.setString(_keyLastBiometricUser, username);
  }

  /// Membaca sesi login yang sedang aktif
  static Future<UserSessionData?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    final userId = prefs.getString(_keyUserId);
    final username = prefs.getString(_keyUsername);

    if (!isLoggedIn || userId == null || username == null) {
      return null;
    }

    final loginTimeString = prefs.getString(_keyLoginTime);
    DateTime? loginTime;
    if (loginTimeString != null) {
      loginTime = DateTime.tryParse(loginTimeString);
    }

    return UserSessionData(
      userId: userId,
      username: username,
      fullName: prefs.getString(_keyFullName) ?? 'Pelajar Mandarin',
      email: prefs.getString(_keyEmail) ?? '',
      isLoggedIn: true,
      loginTime: loginTime,
    );
  }

  /// Menghapus sesi login saat pengguna logout
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyLoginTime);
  }

  /// Cek apakah fitur biometrik diaktifkan
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Set status preferensi biometrik
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  /// Ambil username pengguna terakhir untuk autentikasi biometrik
  static Future<String?> getLastBiometricUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastBiometricUser);
  }

  /// Cek apakah ada akun yang telah didaftarkan biometriknya di perangkat ini
  static Future<bool> isBiometricEnrolled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnrolled) ?? false;
  }

  /// Mendaftarkan biometrik untuk akun tertentu
  static Future<void> enrollBiometric({
    required String userId,
    required String username,
    required String fullName,
    bool allowFingerprint = true,
    bool allowFace = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnrolled, true);
    await prefs.setBool(_keyBiometricEnabled, true);
    await prefs.setString(_keyBiometricEnrolledUserId, userId);
    await prefs.setString(_keyBiometricEnrolledUsername, username);
    await prefs.setString(_keyBiometricEnrolledFullName, fullName);
    await prefs.setBool(_keyBiometricAllowFingerprint, allowFingerprint);
    await prefs.setBool(_keyBiometricAllowFace, allowFace);
    await prefs.setString(_keyBiometricEnrolledAt, DateTime.now().toIso8601String());
    // Update juga target user
    await prefs.setString(_keyLastBiometricUser, username);
  }

  /// Menghapus pendaftaran biometrik
  static Future<void> unenrollBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnrolled, false);
    await prefs.setBool(_keyBiometricEnabled, false);
    await prefs.remove(_keyBiometricEnrolledUserId);
    await prefs.remove(_keyBiometricEnrolledUsername);
    await prefs.remove(_keyBiometricEnrolledFullName);
    await prefs.remove(_keyBiometricAllowFingerprint);
    await prefs.remove(_keyBiometricAllowFace);
    await prefs.remove(_keyBiometricEnrolledAt);
  }

  /// Mengambil username yang didaftarkan pada biometrik
  static Future<String?> getEnrolledBiometricUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final enrolled = prefs.getBool(_keyBiometricEnrolled) ?? false;
    if (!enrolled) return null;
    return prefs.getString(_keyBiometricEnrolledUsername) ?? prefs.getString(_keyLastBiometricUser);
  }

  /// Mengambil nama lengkap pemilik biometrik yang didaftarkan
  static Future<String?> getEnrolledBiometricFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBiometricEnrolledFullName);
  }

  /// Apakah sensor sidik jari diaktifkan untuk akun terdaftar
  static Future<bool> isFingerprintAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricAllowFingerprint) ?? true;
  }

  static Future<void> setFingerprintAllowed(bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricAllowFingerprint, allowed);
  }

  /// Apakah pengenalan wajah diaktifkan untuk akun terdaftar
  static Future<bool> isFaceAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricAllowFace) ?? true;
  }

  static Future<void> setFaceAllowed(bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricAllowFace, allowed);
  }

  static const String _keyDailyGoalMinutes = 'daily_goal_target_minutes';

  /// Mengambil target waktu belajar harian dalam menit (default: 20 menit)
  static Future<int> getDailyGoalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyGoalMinutes) ?? 20;
  }

  /// Menyimpan target waktu belajar harian dalam menit
  static Future<void> setDailyGoalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyGoalMinutes, minutes);
  }

  static const String _keyProfileBackgroundIndex = 'profile_background_index';

  /// Mengambil index background profil yang tersimpan
  static Future<int> getProfileBackgroundIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyProfileBackgroundIndex) ?? 0;
  }

  /// Menyimpan index background profil yang dipilih
  static Future<void> setProfileBackgroundIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyProfileBackgroundIndex, index);
  }
}