import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/quiz_attempt_model.dart';

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
        version: 2,
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
              last_active_date TEXT,
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
          await _createProgressTables(db);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE users ADD COLUMN last_active_date TEXT',
            );
            await _createProgressTables(db);
          }
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

  /// Update data profil user (koin, streak, dan HSK) di database lokal
  Future<bool> updateUserStats({
    required String id,
    int? coins,
    int? streak,
    int? currentHskLevel,
    String? fullName,
    DateTime? lastActiveDate,
  }) async {
    try {
      final db = await database;
      if (db == null) return false;

      final values = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (coins != null) values['coins'] = coins;
      if (streak != null) values['streak'] = streak;
      if (currentHskLevel != null) {
        values['current_hsk_level'] = currentHskLevel;
      }
      if (fullName != null) values['full_name'] = fullName;
      if (lastActiveDate != null) {
        values['last_active_date'] = _dateOnly(lastActiveDate);
      }

      await db.update('users', values, where: 'id = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      debugPrint('[LocalDatabaseService] updateUserStats error: $e');
      return false;
    }
  }

  /// Memperbarui hash kata sandi pengguna berdasarkan ID
  Future<bool> updateUserPassword({
    required String id,
    required String newPasswordHash,
  }) async {
    try {
      final db = await database;
      if (db == null) return false;

      final values = <String, dynamic>{
        'password_hash': newPasswordHash,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final count = await db.update('users', values, where: 'id = ?', whereArgs: [id]);
      return count > 0;
    } catch (e) {
      debugPrint('[LocalDatabaseService] updateUserPassword error: ');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLearningProgress(
    String userId,
  ) async {
    try {
      final db = await database;
      if (db == null) return [];
      return await db.query(
        'learning_progress',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] fetchLearningProgress error: $e');
      return [];
    }
  }

  Future<bool> saveLearningProgress({
    required String userId,
    required int vocabId,
    required int hskLevel,
    required bool learnedInPath,
    required bool quizMastered,
    required bool isFavorite,
  }) async {
    try {
      final db = await database;
      if (db == null) return false;
      await db.insert('learning_progress', {
        'user_id': userId,
        'vocab_id': vocabId,
        'hsk_level': hskLevel,
        'learned_in_path': learnedInPath ? 1 : 0,
        'quiz_mastered': quizMastered ? 1 : 0,
        'is_favorite': isFavorite ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    } catch (e) {
      debugPrint('[LocalDatabaseService] saveLearningProgress error: $e');
      return false;
    }
  }

  Future<List<QuizAttempt>> fetchQuizAttempts(String userId) async {
    try {
      final db = await database;
      if (db == null) return [];
      final rows = await db.query(
        'learning_quiz_attempts',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      return rows
          .map((row) => QuizAttempt.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('[LocalDatabaseService] fetchQuizAttempts error: $e');
      return [];
    }
  }

  Future<bool> saveQuizAttempt(QuizAttempt attempt) async {
    try {
      final db = await database;
      if (db == null) return false;
      await db.insert(
        'learning_quiz_attempts',
        attempt.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('[LocalDatabaseService] saveQuizAttempt error: $e');
      return false;
    }
  }

  Future<void> _createProgressTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_progress (
        user_id TEXT NOT NULL,
        vocab_id INTEGER NOT NULL,
        hsk_level INTEGER NOT NULL,
        learned_in_path INTEGER NOT NULL DEFAULT 0,
        quiz_mastered INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, vocab_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_quiz_attempts (
        attempt_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        quiz_type TEXT NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        correct_answers INTEGER NOT NULL,
        coins_earned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
