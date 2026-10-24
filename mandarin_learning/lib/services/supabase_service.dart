import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/user_profile_model.dart';
import '../models/vocabulary_model.dart';
import '../models/coin_transaction_model.dart';
import '../models/quiz_attempt_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _isInitialized = true;
      debugPrint('[SupabaseService] Berhasil terhubung ke Supabase.');
    } catch (e) {
      debugPrint('[SupabaseService] Gagal inisialisasi: $e');
    }
  }

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => _isInitialized ? client.auth.currentUser : null;
  bool get isAuthenticated => currentUser != null;

  Future<bool> checkConnection() async {
    if (!_isInitialized) return false;

    try {
      await client
          .from('app_users')
          .select('id')
          .limit(0)
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Connection check failed: $e');
      return false;
    }
  }

  // ===================== AUTH & APP USERS (ONLINE DATABASE) =====================

  /// Mencari user berdasarkan username di database online Supabase (tabel app_users)
  Future<Map<String, dynamic>?> getAppUserByUsername(String username) async {
    if (!_isInitialized) {
      throw StateError('Supabase belum berhasil diinisialisasi.');
    }
    try {
      final res = await client
          .from('app_users')
          .select()
          .ilike('username', username.trim())
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[SupabaseService] getAppUserByUsername error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getAppUserByEmail(String email) async {
    if (!_isInitialized) {
      throw StateError('Supabase belum berhasil diinisialisasi.');
    }
    try {
      final res = await client
          .from('app_users')
          .select()
          .ilike('email', email.trim())
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[SupabaseService] getAppUserByEmail error: $e');
      rethrow;
    }
  }

  /// Mencari user berdasarkan id di database online Supabase (tabel app_users)
  Future<Map<String, dynamic>?> getAppUserById(String id) async {
    if (!_isInitialized) return null;
    try {
      final res = await client
          .from('app_users')
          .select()
          .eq('id', id)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[SupabaseService] getAppUserById error: $e');
      return null;
    }
  }

  Future<Map<int, Map<String, bool>>> fetchUserVocabularyProgress(
    String userId,
  ) async {
    try {
      final rows = await client
          .from('user_progress')
          .select('vocab_id, is_learned, is_quiz_mastered, is_favorite')
          .eq('user_id', userId);
      return {
        for (final row in rows)
          (row['vocab_id'] as num).toInt(): {
            'learned_in_path': row['is_learned'] == true,
            'quiz_mastered': row['is_quiz_mastered'] == true,
            'is_favorite': row['is_favorite'] == true,
          },
      };
    } catch (e) {
      debugPrint('[SupabaseService] fetchUserVocabularyProgress error: $e');
      return {};
    }
  }

  Future<bool> saveUserVocabularyProgress({
    required String userId,
    required int vocabId,
    required int hskLevel,
    required bool learnedInPath,
    required bool quizMastered,
    required bool isFavorite,
  }) async {
    try {
      await client.from('user_progress').upsert({
        'user_id': userId,
        'vocab_id': vocabId,
        'hsk_level': hskLevel,
        'is_learned': learnedInPath,
        'is_quiz_mastered': quizMastered,
        'is_favorite': isFavorite,
        'last_studied_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,vocab_id');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] saveUserVocabularyProgress error: $e');
      return false;
    }
  }

  /// Mendaftarkan user baru ke tabel app_users di Supabase
  Future<Map<String, dynamic>?> registerAppUser({
    required String id,
    required String username,
    required String passwordHash,
    required String fullName,
    String? email,
    int currentHskLevel = 1,
    int streak = 1,
    int coins = 50,
    String? createdAt,
  }) async {
    if (!_isInitialized) {
      throw StateError('Supabase belum berhasil diinisialisasi.');
    }
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = <String, dynamic>{
        'id': id,
        'username': username.trim().toLowerCase(),
        'password_hash': passwordHash,
        'full_name': fullName.trim(),
        'email': email?.trim().toLowerCase() ?? '',
        'current_hsk_level': currentHskLevel,
        'streak': streak,
        'last_active_date': DateTime.now().toIso8601String().split('T').first,
        'coins': coins,
        'created_at': createdAt ?? now,
        'updated_at': now,
      };
      debugPrint(
        '[SupabaseService] Menyimpan user baru ke app_users: username=$username, id=$id',
      );
      final result = await client
          .from('app_users')
          .insert(data)
          .select()
          .single();
      debugPrint(
        '[SupabaseService] ✅ User berhasil disimpan ke Supabase: $result',
      );
      return result;
    } catch (e) {
      debugPrint('[SupabaseService] ❌ registerAppUser GAGAL: $e');
      rethrow;
    }
  }

  /// Memperbarui statistik user di database online (app_users & profiles jika ada)
  Future<bool> updateAppUserStats({
    required String id,
    int? coins,
    int? streak,
    int? currentHskLevel,
    String? fullName,
    DateTime? lastActiveDate,
  }) async {
    if (!_isInitialized) return false;
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (coins != null) updateData['coins'] = coins;
      if (streak != null) updateData['streak'] = streak;
      if (currentHskLevel != null) {
        updateData['current_hsk_level'] = currentHskLevel;
      }
      if (fullName != null) updateData['full_name'] = fullName;
      if (lastActiveDate != null) {
        updateData['last_active_date'] = lastActiveDate
            .toIso8601String()
            .split('T')
            .first;
      }

      await client.from('app_users').update(updateData).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateAppUserStats error: $e');
      return false;
    }
  }

  // ===================== AUTH SUPABASE NATIVE (FALLBACK / COMPAT) =====================

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (!_isInitialized) return;
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  // ===================== PROFIL =====================

  Future<UserProfile?> getProfile(String userId) async {
    try {
      // Prioritaskan ambil dari app_users
      final appUser = await getAppUserById(userId);
      if (appUser != null) {
        return UserProfile.fromJson(appUser);
      }

      // Fallback ke tabel profiles
      final res = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        return UserProfile.fromJson(res);
      }
    } catch (e) {
      debugPrint('[SupabaseService] getProfile error: $e');
    }
    return null;
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      await client.from('profiles').update(data).eq('id', userId);
    } catch (e) {
      debugPrint('[SupabaseService] updateProfile error: $e');
    }
  }

  // ===================== KOSAKATA =====================

  Future<List<VocabularyItem>> fetchVocabulary({
    int? hskLevel,
    String? query,
    int limit = 200,
  }) async {
    try {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> filterBuilder = client
          .from('vocabulary')
          .select();

      if (hskLevel != null) {
        filterBuilder = filterBuilder.eq('hsk_level', hskLevel);
      }

      if (query != null && query.trim().isNotEmpty) {
        final term = query.trim();
        filterBuilder = filterBuilder.or(
          'hanzi.ilike.%$term%,pinyin.ilike.%$term%,arti_indonesia.ilike.%$term%',
        );
      }

      final List<dynamic> res = await filterBuilder
          .order('id', ascending: true)
          .limit(limit);
      return res
          .map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchVocabulary error: $e');
      return [];
    }
  }

  // ===================== PROGRES BELAJAR =====================

  Future<Set<int>> fetchLearnedVocabIds(String userId) async {
    try {
      final res = await client
          .from('user_progress')
          .select('vocab_id')
          .eq('user_id', userId)
          .eq('is_learned', true);

      return (res as List).map((e) => (e['vocab_id'] as num).toInt()).toSet();
    } catch (e) {
      debugPrint('[SupabaseService] fetchLearnedVocabIds error: $e');
      return {};
    }
  }

  Future<void> recordProgress({
    required String userId,
    required int vocabId,
    required int hskLevel,
  }) async {
    try {
      await client.from('user_progress').upsert({
        'user_id': userId,
        'vocab_id': vocabId,
        'hsk_level': hskLevel,
        'is_learned': true,
        'last_studied_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,vocab_id');
    } catch (e) {
      debugPrint('[SupabaseService] recordProgress error: $e');
    }
  }

  // ===================== KUIS =====================

  Future<List<QuizAttempt>> fetchQuizAttempts(String userId) async {
    try {
      final rows = await client
          .from('quiz_attempts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1000);
      return rows
          .map((row) => QuizAttempt.fromJson(row))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[SupabaseService] fetchQuizAttempts error: $e');
      return [];
    }
  }

  Future<bool> saveQuizAttempt({
    required String userId,
    required String attemptId,
    required int hskLevel,
    required String quizType,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    required int coinsEarned,
  }) async {
    try {
      await client.from('quiz_attempts').insert({
        'user_id': userId,
        'attempt_id': attemptId,
        'hsk_level': hskLevel,
        'quiz_type': quizType,
        'score': score,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'coins_earned': coinsEarned,
      });

      return true;
    } catch (e) {
      debugPrint('[SupabaseService] saveQuizAttempt error: $e');
      return false;
    }
  }

  // ===================== KOIN & LEDGER =====================

  Future<bool> addCoinTransaction({
    required String userId,
    required int amount,
    required String transactionType,
    required String description,
    String? attemptId,
  }) async {
    try {
      await client.from('coin_ledger').insert({
        'user_id': userId,
        'amount': amount,
        'transaction_type': transactionType,
        'description': description,
        'attempt_id': attemptId,
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] addCoinTransaction error: $e');
      return false;
    }
  }

  Future<List<CoinTransaction>> fetchCoinHistory(String userId) async {
    try {
      final res = await client
          .from('coin_ledger')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return (res as List)
          .map((e) => CoinTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchCoinHistory error: $e');
      return [];
    }
  }

  // ===================== FEEDBACK =====================

  Future<bool> submitFeedback({
    String? userId,
    String? accountName,
    required String category,
    required String message,
    required int rating,
  }) async {
    try {
      final payload = <String, dynamic>{
        'user_id': userId,
        'category': category,
        'message': message,
        'rating': rating,
      };
      if (accountName != null && accountName.isNotEmpty) {
        payload['account_name'] = accountName;
      }
      await client.from('feedback').insert(payload);
      return true;
    } catch (e) {
      try {
        await client.from('feedback').insert({
          'user_id': userId,
          'category': category,
          'message': message,
          'rating': rating,
        });
        return true;
      } catch (inner) {
        debugPrint('[SupabaseService] submitFeedback error: $inner');
        return false;
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchFeedbacks() async {
    try {
      final res = await client
          .from('feedback')
          .select('*, app_users(username, full_name, avatar_url)')
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      try {
        final res = await client
            .from('feedback')
            .select()
            .order('created_at', ascending: false)
            .limit(50);
        return List<Map<String, dynamic>>.from(res);
      } catch (inner) {
        debugPrint('[SupabaseService] fetchFeedbacks error: $inner');
        return [];
      }
    }
  }

  // ===================== KESAN & PESAN MATKUL =====================

  Future<bool> submitCourseImpression({
    String? userId,
    required String accountName,
    required String message,
  }) async {
    try {
      await client.from('course_impressions').insert({
        'user_id': userId,
        'account_name': accountName,
        'message': message,
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] submitCourseImpression error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCourseImpressions() async {
    try {
      final res = await client
          .from('course_impressions')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[SupabaseService] fetchCourseImpressions error: $e');
      return [];
    }
  }
}
