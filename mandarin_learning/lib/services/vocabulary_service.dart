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
  Future<Map<String, VocabularyItem>>? _bundledVocabularyFuture;
  Future<List<VocabularyItem>>? _bundledVocabularyItemsFuture;

  Map<int, Map<String, List<ExampleSentence>>> _contohKalimatByLevel = {};
  bool _isContohKalimatLoaded = false;
  Future<Map<int, Map<String, List<ExampleSentence>>>>? _contohKalimatFuture;

  bool get isLoaded => _isLoaded;
  List<VocabularyItem> get allVocabulary => _allVocabulary;

  /// Memuat contoh kalimat dari aset JSON sesuai level HSK.
  Future<Map<int, Map<String, List<ExampleSentence>>>>
  loadContohKalimatByLevel() {
    if (_isContohKalimatLoaded) {
      return Future.value(_contohKalimatByLevel);
    }
    return _contohKalimatFuture ??= _loadContohKalimatByLevel();
  }

  Future<Map<int, Map<String, List<ExampleSentence>>>>
  _loadContohKalimatByLevel() async {
    const assetsByLevel = {
      1: 'Data/contoh_kalimat_hsk1_3.json',
      2: 'Data/contoh_kalimat_hsk1_3.json',
      3: 'Data/contoh_kalimat_hsk1_3.json',
      4: 'Data/contoh_kalimat_hsk4.json',
      5: 'Data/contoh-kalimat-hsk5.json',
      6: 'Data/contoh_kalimat_hsk6.json',
    };
    final result = <int, Map<String, List<ExampleSentence>>>{};

    for (final entry in assetsByLevel.entries) {
      if (result.containsKey(entry.key)) continue;

      String jsonString;
      try {
        jsonString = await rootBundle.loadString(entry.value);
      } catch (_) {
        final alt = entry.value.startsWith('Data/')
            ? 'data/${entry.value.substring(5)}'
            : 'Data/${entry.value.substring(5)}';
        try {
          jsonString = await rootBundle.loadString(alt);
        } catch (e) {
          debugPrint('[VocabularyService] Lewati contoh kalimat ${entry.value}: $e');
          continue;
        }
      }
      final dynamic decoded = json.decode(jsonString);
      if (decoded is! Map) {
        throw FormatException(
          'Format ${entry.value} harus berupa objek contoh kalimat.',
        );
      }

      final examplesByWord = <String, List<ExampleSentence>>{};
      decoded.forEach((key, value) {
        if (value is List) {
          final examples = value
              .whereType<Map>()
              .map(
                (item) =>
                    ExampleSentence.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
          if (examples.isNotEmpty) {
            examplesByWord[key.toString()] = examples;
          }
        }
      });

      for (final level in assetsByLevel.entries.where(
        (levelEntry) => levelEntry.value == entry.value,
      )) {
        result[level.key] = examplesByWord;
      }
    }

    _contohKalimatByLevel = result;
    _isContohKalimatLoaded = true;
    debugPrint(
      '[VocabularyService] Berhasil memuat contoh kalimat untuk HSK 1–6.',
    );
    return _contohKalimatByLevel;
  }

  /// Mengambil daftar contoh kalimat untuk suatu kosakata:
  /// 1. Dari aset contoh kalimat JSON yang sesuai level HSK jika cocok
  /// 2. Dari item.contohKalimat jika aset tidak memiliki kalimatnya
  /// 3. Fallback ke createExampleSentence
  Future<List<ExampleSentence>> getExampleSentences(VocabularyItem item) async {
    final examplesByLevel = await loadContohKalimatByLevel();
    final assetExamples = examplesByLevel[item.hskLevel]?[item.hanzi];
    if (assetExamples != null && assetExamples.isNotEmpty) {
      return assetExamples;
    }
    if (item.contohKalimat.isNotEmpty) return item.contohKalimat;

    try {
      final fallback = await createExampleSentence(item);
      return [fallback];
    } catch (_) {
      return [];
    }
  }

  Future<ExampleSentence> createExampleSentence(VocabularyItem item) async {
    final examplesByLevel = await loadContohKalimatByLevel();
    final assetExamples = examplesByLevel[item.hskLevel]?[item.hanzi];
    if (assetExamples != null && assetExamples.isNotEmpty) {
      return assetExamples.first;
    }
    if (item.contohKalimat.isNotEmpty) return item.contohKalimat.first;

    final dataWords = await (_bundledVocabularyFuture ??=
        _loadBundledVocabulary());
    const requiredWords = ['我', '今天', '学习'];
    final missingWords = [
      ...requiredWords,
      item.hanzi,
    ].where((word) => !dataWords.containsKey(word));
    if (missingWords.isNotEmpty) {
      throw StateError(
        'Kosakata ${missingWords.join(', ')} tidak ditemukan di data/mandarin_id.json.',
      );
    }

    final pronoun = dataWords['我']!;
    final today = dataWords['今天']!;
    final study = dataWords['学习']!;
    final target = dataWords[item.hanzi]!;
    final meaning = target.translations.isNotEmpty
        ? target.translations.first
        : target.artiIndonesia;

    return ExampleSentence(
      hanzi: '${pronoun.hanzi}${today.hanzi}${study.hanzi}「${target.hanzi}」。',
      arti:
          'Hari ini saya belajar kosakata "${target.hanzi}" yang berarti "$meaning".',
    );
  }

  Future<List<VocabularyItem>> _loadBundledVocabularyItems() async {
    String jsonString;
    try {
      jsonString = await rootBundle.loadString('data/mandarin_id.json');
    } catch (_) {
      jsonString = await rootBundle.loadString('Data/mandarin_id.json');
    }
    final decoded = json.decode(jsonString);
    if (decoded is! List) {
      throw const FormatException(
        'Format data/mandarin_id.json harus berupa daftar kosakata.',
      );
    }

    final vocabulary = <VocabularyItem>[];
    for (final value in decoded) {
      if (value is! Map) {
        throw const FormatException(
          'Setiap entri data/mandarin_id.json harus berupa objek kosakata.',
        );
      }
      final item = VocabularyItem.fromJson(Map<String, dynamic>.from(value));
      if (item.hanzi.isNotEmpty) vocabulary.add(item);
    }
    return vocabulary;
  }

  Future<Map<String, VocabularyItem>> _loadBundledVocabulary() async {
    final items = await (_bundledVocabularyItemsFuture ??=
        _loadBundledVocabularyItems());
    return {
      for (final item in items)
        if (item.hanzi.isNotEmpty) item.hanzi: item,
    };
  }

  Future<void> loadVocabulary() async {
    if (_isLoaded && _allVocabulary.isNotEmpty) return;

    Map<int, Map<String, List<ExampleSentence>>> contohMap = {};
    try {
      contohMap = await loadContohKalimatByLevel();
    } catch (e) {
      debugPrint('[VocabularyService] Peringatan memuat contoh kalimat: $e');
    }
    var bundledItems = <VocabularyItem>[];

    try {
      bundledItems = await (_bundledVocabularyItemsFuture ??=
          _loadBundledVocabularyItems());
    } catch (e) {
      debugPrint('[VocabularyService] Gagal memuat aset kosakata lokal: $e');
    }

    try {
      // Keep bundled entries missing from Supabase, which may return a partial list.
      final supabaseItems = await SupabaseService.instance.fetchVocabulary(
        limit: 5000,
      );
      if (supabaseItems.isNotEmpty) {
        final mergedById = <int, VocabularyItem>{
          for (final item in bundledItems)
            if (item.id != 0) item.id: item,
        };
        final idlessItems = <VocabularyItem>[];
        for (final item in supabaseItems) {
          if (item.id == 0) {
            idlessItems.add(item);
          } else {
            mergedById[item.id] = item;
          }
        }
        _allVocabulary = [...mergedById.values, ...idlessItems].map((item) {
          final examples = contohMap[item.hskLevel]?[item.hanzi];
          if (item.contohKalimat.isEmpty && examples != null) {
            return item.copyWith(contohKalimat: examples);
          }
          return item;
        }).toList();

        _isLoaded = true;
        debugPrint(
          '[VocabularyService] Berhasil memuat ${_allVocabulary.length} kosakata dari Supabase.',
        );
        return;
      }
    } catch (e) {
      debugPrint(
        '[VocabularyService] Gagal memuat dari Supabase, beralih ke aset lokal: $e',
      );
    }

    if (bundledItems.isNotEmpty) {
      _allVocabulary = bundledItems.map((item) {
        final examples = contohMap[item.hskLevel]?[item.hanzi];
        if (item.contohKalimat.isEmpty && examples != null) {
          return item.copyWith(contohKalimat: examples);
        }
        return item;
      }).toList();
      _isLoaded = true;
      debugPrint(
        '[VocabularyService] Berhasil memuat ${_allVocabulary.length} kosakata dari aset lokal.',
      );
    }
  }

  List<VocabularyItem> getByLevel(int hskLevel) {
    return _allVocabulary.where((item) => item.hskLevel == hskLevel).toList();
  }

  // Mengelompokkan kosakata per unit (10 kata per unit) untuk learning path
  Map<int, List<VocabularyItem>> getUnitsForLevel(
    int hskLevel, {
    int wordsPerUnit = 10,
  }) {
    final words = getByLevel(hskLevel);
    final Map<int, List<VocabularyItem>> units = {};

    int unitNumber = 1;
    for (int i = 0; i < words.length; i += wordsPerUnit) {
      final end = (i + wordsPerUnit < words.length)
          ? i + wordsPerUnit
          : words.length;
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
