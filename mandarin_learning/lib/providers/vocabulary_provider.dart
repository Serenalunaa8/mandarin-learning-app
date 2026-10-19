import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vocabulary_model.dart';
import '../services/vocabulary_service.dart';
import '../services/supabase_service.dart';

class VocabularyProvider extends ChangeNotifier {
  bool _isLoading = false;
  int _selectedLevel = 1;
  int _selectedUnit = 1;
  final Set<int> _learnedVocabIds = {};
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  int get selectedLevel => _selectedLevel;
  int get selectedUnit => _selectedUnit;
  Set<int> get learnedVocabIds => _learnedVocabIds;
  String get searchQuery => _searchQuery;

  List<VocabularyItem> get currentLevelVocabulary =>
      VocabularyService.instance.getByLevel(_selectedLevel);

  Map<int, List<VocabularyItem>> get currentLevelUnits =>
      VocabularyService.instance.getUnitsForLevel(_selectedLevel);

  List<VocabularyItem> get searchResults =>
      VocabularyService.instance.search(_searchQuery);

  Future<void> initialize(String? userId) async {
    _isLoading = true;
    notifyListeners();

    await VocabularyService.instance.loadVocabulary();

    // Muat progres yang sudah dipelajari
    _learnedVocabIds.clear();
    if (userId != null && userId != 'guest_local_user') {
      final ids = await SupabaseService.instance.fetchLearnedVocabIds(userId);
      _learnedVocabIds.addAll(ids);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final localList = prefs.getStringList('learned_vocab_ids') ?? [];
      _learnedVocabIds.addAll(localList.map((e) => int.tryParse(e) ?? 0));
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

  Future<void> markAsLearned({required int vocabId, required String userId}) async {
    if (_learnedVocabIds.contains(vocabId)) return;

    _learnedVocabIds.add(vocabId);
    notifyListeners();

    if (userId != 'guest_local_user') {
      await SupabaseService.instance.recordProgress(
        userId: userId,
        vocabId: vocabId,
        hskLevel: _selectedLevel,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'learned_vocab_ids',
        _learnedVocabIds.map((e) => e.toString()).toList(),
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
