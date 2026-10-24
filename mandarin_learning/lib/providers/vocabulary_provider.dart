import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vocabulary_model.dart';
import '../models/quiz_attempt_model.dart';
import '../services/vocabulary_service.dart';
import '../services/local_database_service.dart';
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
  String _activeUserId = 'guest_local_user';
  bool _isGuestUser = true;

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

    _activeUserId = userId ?? 'guest_local_user';
    _isGuestUser =
        userId == null ||
        userId == 'guest_local_user' ||
        userId == 'guest_temp';
    final prefs = await SharedPreferences.getInstance();
    final localProgress = await LocalDatabaseService.instance
        .fetchLearningProgress(_activeUserId);
    final remoteProgress = _isGuestUser
        ? <int, Map<String, bool>>{}
        : await SupabaseService.instance.fetchUserVocabularyProgress(
            _activeUserId,
          );
    final progressByVocabId = <int, Map<String, bool>>{
      for (final row in localProgress)
        (row['vocab_id'] as num).toInt(): {
          'learned_in_path': row['learned_in_path'] == 1,
          'quiz_mastered': row['quiz_mastered'] == 1,
          'is_favorite': row['is_favorite'] == 1,
        },
    };
    progressByVocabId.addAll(remoteProgress);

    _learnedVocabIds.clear();
    _quizMasteredVocabIds.clear();
    _favoriteVocabIds.clear();
    for (final entry in progressByVocabId.entries) {
      final state = entry.value;
      if (state['learned_in_path'] == true) {
        _learnedVocabIds.add(entry.key);
      }
      if (state['quiz_mastered'] == true) {
        _quizMasteredVocabIds.add(entry.key);
      }
      if (state['is_favorite'] == true) {
        _favoriteVocabIds.add(entry.key);
      }
    }

    final legacyQuizMastery = prefs.getStringList(
      'quiz_mastered_vocab_ids_$_activeUserId',
    );
    _quizMasteredVocabIds.addAll(
      (legacyQuizMastery ?? []).map((id) => int.tryParse(id)).whereType<int>(),
    );
    _learnedVocabIds.addAll(
      (prefs.getStringList('local_progress_learned_$_activeUserId') ?? [])
          .map((id) => int.tryParse(id))
          .whereType<int>(),
    );
    _quizMasteredVocabIds.addAll(
      (prefs.getStringList('local_progress_quiz_$_activeUserId') ?? [])
          .map((id) => int.tryParse(id))
          .whereType<int>(),
    );
    final legacyFavorites = prefs.getStringList(
      'favorite_vocab_ids_$_activeUserId',
    );
    _favoriteVocabIds.addAll(
      (legacyFavorites ?? prefs.getStringList('favorite_vocab_ids') ?? [])
          .map((id) => int.tryParse(id))
          .whereType<int>(),
    );
    _favoriteVocabIds.addAll(
      (prefs.getStringList('local_progress_favorites_$_activeUserId') ?? [])
          .map((id) => int.tryParse(id))
          .whereType<int>(),
    );

    // Keep a local database cache and import records saved before database sync.
    _quizAttempts.clear();
    final localAttempts = await LocalDatabaseService.instance.fetchQuizAttempts(
      _activeUserId,
    );
    final oldLocalAttempts = prefs.getStringList('local_quiz_attempts') ?? [];
    final attemptsById = <String, QuizAttempt>{
      for (final attempt in localAttempts) attempt.id: attempt,
    };
    for (final encodedAttempt in oldLocalAttempts) {
      try {
        final map = jsonDecode(encodedAttempt) as Map<String, dynamic>;
        final attempt = QuizAttempt.fromJson(map);
        if (attempt.userId == _activeUserId) {
          attemptsById.putIfAbsent(attempt.id, () => attempt);
        }
      } catch (e) {
        debugPrint('[VocabProvider] Error parsing quiz attempt: $e');
      }
    }
    if (!_isGuestUser) {
      final remoteAttempts = await SupabaseService.instance.fetchQuizAttempts(
        _activeUserId,
      );
      for (final attempt in remoteAttempts) {
        attemptsById[attempt.id] = attempt;
        await LocalDatabaseService.instance.saveQuizAttempt(attempt);
      }
    }
    _quizAttempts.addAll(attemptsById.values);
    _quizAttempts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
      'favorite_vocab_ids_$_activeUserId',
      _favoriteVocabIds.map((e) => e.toString()).toList(),
    );
    final matchingItems = VocabularyService.instance.allVocabulary.where(
      (item) => item.id == vocabId,
    );
    if (matchingItems.isNotEmpty) {
      await _persistVocabularyProgress(matchingItems.first);
    }
  }

  Future<void> markAsLearned({
    required int vocabId,
    required String userId,
    int? hskLevel,
  }) async {
    if (_learnedVocabIds.contains(vocabId)) return;

    _learnedVocabIds.add(vocabId);
    notifyListeners();

    final matchingItems = VocabularyService.instance.allVocabulary.where(
      (item) => item.id == vocabId,
    );
    if (matchingItems.isNotEmpty) {
      await _persistVocabularyProgress(matchingItems.first, hskLevel: hskLevel);
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
    await LocalDatabaseService.instance.saveQuizAttempt(attempt);
    await prefs.setStringList(
      'quiz_mastered_vocab_ids_${attempt.userId}',
      _quizMasteredVocabIds.map((id) => id.toString()).toList(),
    );
    await prefs.setStringList(
      'local_quiz_attempts',
      _quizAttempts.map((e) => jsonEncode(e.toJson())).toList(),
    );
    for (final vocabId in correctVocabIds) {
      final matchingItems = VocabularyService.instance.allVocabulary.where(
        (item) => item.id == vocabId,
      );
      if (matchingItems.isNotEmpty) {
        await _persistVocabularyProgress(matchingItems.first);
      }
    }

    if (!_isGuestUser) {
      final saved = await SupabaseService.instance.saveQuizAttempt(
        userId: attempt.userId,
        attemptId: attempt.id,
        hskLevel: attempt.hskLevel,
        quizType: attempt.quizType,
        score: attempt.score,
        totalQuestions: attempt.totalQuestions,
        correctAnswers: attempt.correctAnswers,
        coinsEarned: attempt.coinsEarned,
      );
      if (!saved) {
        debugPrint(
          '[VocabProvider] Quiz attempt cached locally; Supabase sync failed.',
        );
      }
    }
  }

  Future<void> _persistVocabularyProgress(
    VocabularyItem item, {
    int? hskLevel,
  }) async {
    final level = hskLevel ?? item.hskLevel;
    final learned = _learnedVocabIds.contains(item.id);
    final mastered = _quizMasteredVocabIds.contains(item.id);
    final favorite = _favoriteVocabIds.contains(item.id);
    final savedLocally = await LocalDatabaseService.instance
        .saveLearningProgress(
          userId: _activeUserId,
          vocabId: item.id,
          hskLevel: level,
          learnedInPath: learned,
          quizMastered: mastered,
          isFavorite: favorite,
        );
    if (!savedLocally) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'local_progress_learned_$_activeUserId',
        _learnedVocabIds.map((id) => id.toString()).toList(),
      );
      await prefs.setStringList(
        'local_progress_quiz_$_activeUserId',
        _quizMasteredVocabIds.map((id) => id.toString()).toList(),
      );
      await prefs.setStringList(
        'local_progress_favorites_$_activeUserId',
        _favoriteVocabIds.map((id) => id.toString()).toList(),
      );
    }

    if (!_isGuestUser) {
      final savedRemotely = await SupabaseService.instance
          .saveUserVocabularyProgress(
            userId: _activeUserId,
            vocabId: item.id,
            hskLevel: level,
            learnedInPath: learned,
            quizMastered: mastered,
            isFavorite: favorite,
          );
      if (!savedRemotely) {
        debugPrint(
          '[VocabProvider] Vocabulary progress cached locally; Supabase sync failed for ${item.id}.',
        );
      }
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
