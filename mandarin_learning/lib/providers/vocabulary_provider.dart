import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vocabulary_model.dart';
import '../models/quiz_attempt_model.dart';
import '../services/vocabulary_service.dart';
import '../services/supabase_service.dart';

class VocabularyProvider extends ChangeNotifier {
  bool _isLoading = false;
  int _selectedLevel = 1;
  int _selectedUnit = 1;
  final Set<int> _learnedVocabIds = {};
  final Set<int> _quizMasteredVocabIds = {};
  final Set<int> _favoriteVocabIds = {};
  final List<QuizAttempt> _quizAttempts = [];
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  int get selectedLevel => _selectedLevel;
  int get selectedUnit => _selectedUnit;
  Set<int> get learnedVocabIds => _learnedVocabIds;
  Set<int> get favoriteVocabIds => _favoriteVocabIds;
  List<QuizAttempt> get quizAttempts => _quizAttempts;
  String get searchQuery => _searchQuery;

  int get totalQuizzesCompleted => _quizAttempts.length;
  int get totalQuizMasteredVocabulary => _quizMasteredVocabIds.length;

  double get averageQuizScore {
    if (_quizAttempts.isEmpty) return 0.0;
    final sum = _quizAttempts.fold<int>(
      0,
      (prev, element) => prev + element.score,
    );
    return sum / _quizAttempts.length;
  }

  List<VocabularyItem> get currentLevelVocabulary =>
      VocabularyService.instance.getByLevel(_selectedLevel);

  List<VocabularyItem> get allVocabulary =>
      VocabularyService.instance.allVocabulary;

  Map<int, List<VocabularyItem>> get currentLevelUnits =>
      VocabularyService.instance.getUnitsForLevel(_selectedLevel);

  List<VocabularyItem> get searchResults =>
      VocabularyService.instance.search(_searchQuery);

  List<VocabularyItem> get favoriteVocabulary {
    return VocabularyService.instance.allVocabulary
        .where((item) => _favoriteVocabIds.contains(item.id))
        .toList();
  }

  Future<void> initialize(String? userId) async {
    _isLoading = true;
    notifyListeners();

    await VocabularyService.instance.loadVocabulary();

    final isGuestUser =
        userId == null ||
        userId == 'guest_local_user' ||
        userId == 'guest_temp';
    final prefs = await SharedPreferences.getInstance();
    _quizMasteredVocabIds
      ..clear()
      ..addAll(
        (prefs.getStringList(
                  'quiz_mastered_vocab_ids_${userId ?? 'guest_local_user'}',
                ) ??
                [])
            .map((id) => int.tryParse(id))
            .whereType<int>(),
      );

    // 1. Muat progres yang sudah dipelajari (PB-05 & FR-15)
    _learnedVocabIds.clear();
    if (!isGuestUser) {
      final ids = await SupabaseService.instance.fetchLearnedVocabIds(userId);
      _learnedVocabIds.addAll(ids);
    }

    // 2. Muat koleksi kata favorit / kamus tersimpan
    _favoriteVocabIds.clear();
    if (!isGuestUser) {
      final favList = prefs.getStringList('favorite_vocab_ids') ?? [];
      _favoriteVocabIds.addAll(favList.map((e) => int.tryParse(e) ?? 0));
    }

    // 3. Muat riwayat kuis utama
    _quizAttempts.clear();
    if (!isGuestUser) {
      final localAttempts = prefs.getStringList('local_quiz_attempts') ?? [];
      for (var str in localAttempts) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          _quizAttempts.add(QuizAttempt.fromJson(map));
        } catch (e) {
          debugPrint('[VocabProvider] Error parsing quiz attempt: $e');
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void setLevel(int level) {
    if (level >= 1 && level <= 6) {
      _selectedLevel = level;
      _selectedUnit = 1;
      notifyListeners();
    }
  }

  void setUnit(int unit) {
    _selectedUnit = unit;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  bool isLearned(int vocabId) => _learnedVocabIds.contains(vocabId);

  bool isFavorite(int vocabId) => _favoriteVocabIds.contains(vocabId);

  Future<void> toggleFavorite(int vocabId) async {
    if (_favoriteVocabIds.contains(vocabId)) {
      _favoriteVocabIds.remove(vocabId);
    } else {
      _favoriteVocabIds.add(vocabId);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'favorite_vocab_ids',
      _favoriteVocabIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> markAsLearned({
    required int vocabId,
    required String userId,
    int? hskLevel,
  }) async {
    if (_learnedVocabIds.contains(vocabId)) return;

    _learnedVocabIds.add(vocabId);
    notifyListeners();

    if (userId != 'guest_local_user' && userId != 'guest_temp') {
      await SupabaseService.instance.recordProgress(
        userId: userId,
        vocabId: vocabId,
        hskLevel: hskLevel ?? _selectedLevel,
      );
    }
  }

  Future<void> recordQuizAttempt(
    QuizAttempt attempt, {
    Set<int> correctVocabIds = const {},
  }) async {
    _quizAttempts.insert(0, attempt);
    _quizMasteredVocabIds.addAll(correctVocabIds);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'quiz_mastered_vocab_ids_${attempt.userId}',
      _quizMasteredVocabIds.map((id) => id.toString()).toList(),
    );

    // Mode Tamu tidak menyimpan riwayat kuis ke disk maupun online.
    if (attempt.userId != 'guest_local_user' &&
        attempt.userId != 'guest_temp') {
      final jsonList = _quizAttempts
          .map((e) => jsonEncode(e.toJson()))
          .toList();
      await prefs.setStringList('local_quiz_attempts', jsonList);

      await SupabaseService.instance.saveQuizAttempt(
        userId: attempt.userId,
        attemptId: attempt.id,
        hskLevel: attempt.hskLevel,
        quizType: attempt.quizType,
        score: attempt.score,
        totalQuestions: attempt.totalQuestions,
        correctAnswers: attempt.correctAnswers,
        coinsEarned: attempt.coinsEarned,
      );
    }
  }

  double getLevelProgress(int level) {
    final words = VocabularyService.instance.getByLevel(level);
    if (words.isEmpty) return 0.0;

    int learnedCount = 0;
    for (var w in words) {
      if (_learnedVocabIds.contains(w.id)) {
        learnedCount++;
      }
    }
    return (learnedCount / words.length).clamp(0.0, 1.0);
  }
}
