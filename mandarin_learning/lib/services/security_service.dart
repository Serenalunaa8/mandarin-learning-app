import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityService {
  // Salt internal untuk memperkuat hashing password
  static const String _appSalt = 'MandarinLearning_SecureSalt_2026';

  /// Hash password menggunakan SHA-256 dan salt
  static String hashPassword(String password) {
    final saltedBytes = utf8.encode('$_appSalt:$password');
    final digest = sha256.convert(saltedBytes);
    return digest.toString();
  }

  /// Verifikasi apakah input password cocok dengan password_hash yang tersimpan
  static bool verifyPassword(String inputPassword, String storedHash) {
    final computedHash = hashPassword(inputPassword);
    return computedHash == storedHash;
  }
}
