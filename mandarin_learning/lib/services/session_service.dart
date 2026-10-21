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

  // Biometric session settings
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyLastBiometricUser = 'last_biometric_user';

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
}
