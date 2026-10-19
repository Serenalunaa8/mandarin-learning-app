import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/vocabulary_model.dart';
import 'supabase_service.dart';

class VocabularyService {
  static final VocabularyService instance = VocabularyService._internal();
  VocabularyService._internal();

  List<VocabularyItem> _allVocabulary = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<VocabularyItem> get allVocabulary => _allVocabulary;

  Future<void> loadVocabulary() async {
    if (_isLoaded && _allVocabulary.isNotEmpty) return;

    try {
      // 1. Coba ambil dari Supabase terlebih dahulu
      final supabaseItems = await SupabaseService.instance.fetchVocabulary(limit: 5000);
      if (supabaseItems.isNotEmpty) {
        _allVocabulary = supabaseItems;
        _isLoaded = true;
        debugPrint('[VocabularyService] Berhasil memuat ${_allVocabulary.length} kosakata dari Supabase.');
        return;
      }
    } catch (e) {
      debugPrint('[VocabularyService] Gagal memuat dari Supabase, beralih ke aset lokal: $e');
    }

    // 2. Fallback instan ke lokal data/mandarin_id.json
    try {
      final jsonString = await rootBundle.loadString('data/mandarin_id.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _allVocabulary = jsonList.map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>)).toList();
      _isLoaded = true;
      debugPrint('[VocabularyService] Berhasil memuat ${_allVocabulary.length} kosakata dari aset lokal.');
    } catch (e) {
      debugPrint('[VocabularyService] Error kritis saat memuat aset lokal: $e');
    }
  }

  List<VocabularyItem> getByLevel(int hskLevel) {
    return _allVocabulary.where((item) => item.hskLevel == hskLevel).toList();
  }

  // Mengelompokkan kosakata per unit (10 kata per unit) untuk learning path
  Map<int, List<VocabularyItem>> getUnitsForLevel(int hskLevel, {int wordsPerUnit = 10}) {
    final words = getByLevel(hskLevel);
    final Map<int, List<VocabularyItem>> units = {};

    int unitNumber = 1;
    for (int i = 0; i < words.length; i += wordsPerUnit) {
      final end = (i + wordsPerUnit < words.length) ? i + wordsPerUnit : words.length;
      units[unitNumber] = words.sublist(i, end);
      unitNumber++;
    }
    return units;
  }

  List<VocabularyItem> search(String query) {
    if (query.trim().isEmpty) return [];
    final term = query.trim().toLowerCase();

    return _allVocabulary.where((item) {
      return item.hanzi.toLowerCase().contains(term) ||
          item.pinyin.toLowerCase().contains(term) ||
          item.artiIndonesia.toLowerCase().contains(term);
    }).toList();
  }

  VocabularyItem? getById(int id) {
    try {
      return _allVocabulary.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
