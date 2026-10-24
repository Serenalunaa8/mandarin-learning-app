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

  // Cache contoh kalimat dari Data/contoh_kalimat_hsk1_2.json
  Map<String, List<ExampleSentence>> _contohKalimatMap = {};
  bool _isContohKalimatLoaded = false;

  bool get isLoaded => _isLoaded;
  List<VocabularyItem> get allVocabulary => _allVocabulary;

  /// Memuat file Data/contoh_kalimat_hsk1_2.json
  Future<Map<String, List<ExampleSentence>>> loadContohKalimatMap() async {
    if (_isContohKalimatLoaded) return _contohKalimatMap;

    try {
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('Data/contoh_kalimat_hsk1_2.json');
      } catch (_) {
        jsonString = await rootBundle.loadString('data/contoh_kalimat_hsk1_2.json');
      }

      final dynamic decoded = json.decode(jsonString);
      if (decoded is Map) {
        final result = <String, List<ExampleSentence>>{};
        decoded.forEach((key, val) {
          final hanziKey = key.toString();
          if (val is List) {
            final list = <ExampleSentence>[];
            for (final item in val) {
              if (item is Map) {
                list.add(ExampleSentence.fromJson(Map<String, dynamic>.from(item)));
              }
            }
            if (list.isNotEmpty) {
              result[hanziKey] = list;
            }
          }
        });
        _contohKalimatMap = result;
        _isContohKalimatLoaded = true;
        debugPrint(
          '[VocabularyService] Berhasil memuat ${_contohKalimatMap.length} kata dari Data/contoh_kalimat_hsk1_2.json',
        );
      }
    } catch (e) {
      debugPrint('[VocabularyService] Info load contoh kalimat: $e');
    }

    return _contohKalimatMap;
  }

  /// Mengambil daftar contoh kalimat untuk suatu kosakata:
  /// 1. Dari item.contohKalimat jika ada
  /// 2. Dari Data/contoh_kalimat_hsk1_2.json jika cocok
  /// 3. Fallback ke createExampleSentence
  Future<List<ExampleSentence>> getExampleSentences(VocabularyItem item) async {
    if (item.contohKalimat.isNotEmpty) {
      return item.contohKalimat;
    }

    final map = await loadContohKalimatMap();
    if (map.containsKey(item.hanzi) && map[item.hanzi]!.isNotEmpty) {
      return map[item.hanzi]!;
    }

    try {
      final fallback = await createExampleSentence(item);
      return [fallback];
    } catch (_) {
      return [];
    }
  }

  Future<ExampleSentence> createExampleSentence(VocabularyItem item) async {
    if (item.contohKalimat.isNotEmpty) return item.contohKalimat.first;

    // Cek di contoh_kalimat_hsk1_2.json jika sudah termuat
    if (_contohKalimatMap.containsKey(item.hanzi) &&
        _contohKalimatMap[item.hanzi]!.isNotEmpty) {
      return _contohKalimatMap[item.hanzi]!.first;
    }

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

  Future<Map<String, VocabularyItem>> _loadBundledVocabulary() async {
    final jsonString = await rootBundle.loadString('data/mandarin_id.json');
    final decoded = json.decode(jsonString);
    if (decoded is! List) {
      throw const FormatException(
        'Format data/mandarin_id.json harus berupa daftar kosakata.',
      );
    }

    final vocabulary = <String, VocabularyItem>{};
    for (final value in decoded) {
      if (value is! Map) {
        throw const FormatException(
          'Setiap entri data/mandarin_id.json harus berupa objek kosakata.',
        );
      }
      final item = VocabularyItem.fromJson(Map<String, dynamic>.from(value));
      if (item.hanzi.isNotEmpty) vocabulary[item.hanzi] = item;
    }
    return vocabulary;
  }

  Future<void> loadVocabulary() async {
    if (_isLoaded && _allVocabulary.isNotEmpty) return;

    // Muat contoh kalimat dari Data/contoh_kalimat_hsk1_2.json
    final contohMap = await loadContohKalimatMap();

    try {
      // 1. Coba ambil dari Supabase terlebih dahulu
      final supabaseItems = await SupabaseService.instance.fetchVocabulary(
        limit: 5000,
      );
      if (supabaseItems.isNotEmpty) {
        _allVocabulary = supabaseItems.map((item) {
          if (item.contohKalimat.isEmpty && contohMap.containsKey(item.hanzi)) {
            return item.copyWith(contohKalimat: contohMap[item.hanzi]);
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

    // 2. Fallback instan ke lokal data/mandarin_id.json
    try {
      final jsonString = await rootBundle.loadString('data/mandarin_id.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _allVocabulary = jsonList
          .map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>))
          .map((item) {
            if (item.contohKalimat.isEmpty && contohMap.containsKey(item.hanzi)) {
              return item.copyWith(contohKalimat: contohMap[item.hanzi]);
            }
            return item;
          })
          .toList();
      _isLoaded = true;
      debugPrint(
        '[VocabularyService] Berhasil memuat ${_allVocabulary.length} kosakata dari aset lokal.',
      );
    } catch (e) {
      debugPrint('[VocabularyService] Error kritis saat memuat aset lokal: $e');
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
