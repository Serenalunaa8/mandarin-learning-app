import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/user_profile_model.dart';
import '../models/vocabulary_model.dart';
import '../models/coin_transaction_model.dart';

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
        'coins': coins,
        'created_at': createdAt ?? now,
        'updated_at': now,
      };
      debugPrint('[SupabaseService] Menyimpan user baru ke app_users: username=$username, id=$id');
      final result = await client.from('app_users').insert(data).select().single();
      debugPrint('[SupabaseService] ✅ User berhasil disimpan ke Supabase: $result');
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
  }) async {
    if (!_isInitialized) return false;
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (coins != null) updateData['coins'] = coins;
      if (streak != null) updateData['streak'] = streak;
      if (currentHskLevel != null) updateData['current_hsk_level'] = currentHskLevel;
      if (fullName != null) updateData['full_name'] = fullName;

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
          .eq('user_id', userId);

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
    required String category,
    required String message,
    required int rating,
  }) async {
    try {
      await client.from('feedback').insert({
        'user_id': userId,
        'category': category,
        'message': message,
        'rating': rating,
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] submitFeedback error: $e');
      return false;
    }
  }
}
