import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  LocalDatabaseService._internal();

  Database? _db;
  bool _isInitialized = false;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null && _db!.isOpen) return _db;
    await initialize();
    return _db;
  }

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint(
        '[LocalDatabaseService] Platform Web terdeteksi: SQLite lokal dilewati (menggunakan Supabase & Session).',
      );
      return;
    }
    if (_isInitialized && _db != null && _db!.isOpen) return;

    try {
      final databasesPath = await getDatabasesPath();
      final path = p.join(databasesPath, 'mandarin_learning_local.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (Database db, int version) async {
          // Tabel pengguna lokal dengan username & password_hash terenkripsi
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users (
              id TEXT PRIMARY KEY,
              username TEXT UNIQUE NOT NULL,
              password_hash TEXT NOT NULL,
              full_name TEXT NOT NULL,
              email TEXT,
              current_hsk_level INTEGER DEFAULT 1,
              streak INTEGER DEFAULT 1,
              total_xp INTEGER DEFAULT 0,
              coins INTEGER DEFAULT 50,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          // Index untuk pencarian cepat berdasarkan username
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username)',
          );
        },
      );
      _isInitialized = true;
      debugPrint(
        '[LocalDatabaseService] SQLite database berhasil diinisialisasi.',
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] SQLite init info: $e');
    }
  }

  /// Menyimpan atau memperbarui user di database lokal SQLite
  Future<bool> saveOrUpdateUser(Map<String, dynamic> userMap) async {
    try {
      final db = await database;
      if (db == null) return false;

      final data = Map<String, dynamic>.from(userMap);
      data['updated_at'] = DateTime.now().toIso8601String();
      if (!data.containsKey('created_at') || data['created_at'] == null) {
        data['created_at'] = DateTime.now().toIso8601String();
      }

      await db.insert(
        'users',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('[LocalDatabaseService] saveOrUpdateUser error: $e');
      return false;
    }
  }

  /// Mengambil data user berdasarkan username
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      final db = await database;
      if (db == null) return null;

      final res = await db.query(
        'users',
        where: 'LOWER(username) = ?',
        whereArgs: [username.trim().toLowerCase()],
        limit: 1,
      );

      if (res.isNotEmpty) {
        return res.first;
      }
    } catch (e) {
      debugPrint('[LocalDatabaseService] getUserByUsername error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserByIdentifier(String identifier) async {
    try {
      final db = await database;
      if (db == null) return null;

      final normalizedIdentifier = identifier.trim().toLowerCase();
      final res = await db.query(
        'users',
        where: 'LOWER(username) = ? OR LOWER(email) = ?',
        whereArgs: [normalizedIdentifier, normalizedIdentifier],
        limit: 1,
      );

      if (res.isNotEmpty) {
        return res.first;
      }
    } catch (e) {
      debugPrint('[LocalDatabaseService] getUserByIdentifier error: $e');
    }
    return null;
  }

  /// Mengambil data user berdasarkan ID
  Future<Map<String, dynamic>?> getUserById(String id) async {
    try {
      final db = await database;
      if (db == null) return null;

      final res = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (res.isNotEmpty) {
        return res.first;
      }
    } catch (e) {
      debugPrint('[LocalDatabaseService] getUserById error: $e');
    }
    return null;
  }

  /// Mengambil semua user yang tersimpan di lokal (misal untuk multi-account / debug)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final db = await database;
      if (db == null) return [];

      return await db.query('users', orderBy: 'updated_at DESC');
    } catch (e) {
      debugPrint('[LocalDatabaseService] getAllUsers error: $e');
      return [];
    }
  }

  /// Update data profil user (koin, streak, xp, hsk) di database lokal
  Future<bool> updateUserStats({
    required String id,
    int? coins,
    int? streak,
    int? totalXp,
    int? currentHskLevel,
    String? fullName,
  }) async {
    try {
      final db = await database;
      if (db == null) return false;

      final values = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (coins != null) values['coins'] = coins;
      if (streak != null) values['streak'] = streak;
      if (totalXp != null) values['total_xp'] = totalXp;
      if (currentHskLevel != null) {
        values['current_hsk_level'] = currentHskLevel;
      }
      if (fullName != null) values['full_name'] = fullName;

      await db.update('users', values, where: 'id = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      debugPrint('[LocalDatabaseService] updateUserStats error: $e');
      return false;
    }
  }
}
