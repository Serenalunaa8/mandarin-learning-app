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

  // ===================== AUTH =====================

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
    await client.auth.signOut();
  }

  // ===================== PROFIL =====================

  Future<UserProfile?> getProfile(String userId) async {
    try {
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
      PostgrestFilterBuilder<List<Map<String, dynamic>>> filterBuilder =
          client.from('vocabulary').select();

      if (hskLevel != null) {
        filterBuilder = filterBuilder.eq('hsk_level', hskLevel);
      }

      if (query != null && query.trim().isNotEmpty) {
        final term = query.trim();
        filterBuilder = filterBuilder.or('hanzi.ilike.%$term%,pinyin.ilike.%$term%,arti_indonesia.ilike.%$term%');
      }

      final List<dynamic> res = await filterBuilder.order('id', ascending: true).limit(limit);
      return res.map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>)).toList();
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

      if (coinsEarned > 0) {
        await addCoinTransaction(
          userId: userId,
          amount: coinsEarned,
          transactionType: 'quiz_reward',
          description: 'Hadiah Kuis HSK $hskLevel (Skor: $score)',
          attemptId: attemptId,
        );
      }
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
