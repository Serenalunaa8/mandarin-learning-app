/// Menghitung skor kemiripan antara teks ucapan yang dikenali dengan teks target Mandarin.
/// Menggunakan analisis fonetik multi-tingkat (Hanzi, Pinyin, suku kata, dan variasi ASR)
/// untuk menghasilkan skor tingkat validasi yang akurat, adil, dan tidak sembarangan (contoh: 90% saat sesuai).
int scoreMandarinTranscription(
  String target,
  String recognized, {
  String? targetPinyin,
  double? confidence,
  bool realisticScale = true,
}) {
  final cleanTarget = normalizeMandarinTranscript(target);
  final cleanRecognized = normalizeMandarinTranscript(recognized);

  if (cleanTarget.isEmpty || cleanRecognized.isEmpty) return 0;

  // 1. EVALUASI TINGKAT 1: Kecocokan Karakter Hanzi
  // Jika karakter Hanzi identik persis
  if (cleanTarget == cleanRecognized) {
    if (realisticScale && targetPinyin != null) {
      if (confidence != null && confidence > 0) {
        return (88 + (confidence * 10)).round().clamp(90, 98);
      }
      return 90; // Default tingkat validasi 90% saat sudah sesuai
    }
    return 100;
  }

  // Jika target Hanzi terkandung utuh dalam ucapan (misal '你好' di '你好啊' / '嗯你好')
  if (cleanRecognized.contains(cleanTarget)) {
    if (realisticScale && targetPinyin != null) {
      if (confidence != null && confidence > 0) {
        return (86 + (confidence * 10)).round().clamp(88, 96);
      }
      return 90;
    }
    return 100;
  }

  // 2. EVALUASI TINGKAT 2: Kecocokan Pinyin Baku (Bebas Nada & Spasi)
  if (targetPinyin != null && targetPinyin.isNotEmpty) {
    final normTargetPinyin = normalizePinyin(targetPinyin);
    final normRecogPinyin = normalizePinyin(cleanRecognized);

    if (normTargetPinyin.isNotEmpty && normRecogPinyin.isNotEmpty) {
      // Kecocokan pinyin persis (misal 'nihao' == 'nihao')
      if (normTargetPinyin == normRecogPinyin ||
          normRecogPinyin.contains(normTargetPinyin) ||
          normTargetPinyin.contains(normRecogPinyin)) {
        if (realisticScale) {
          if (confidence != null && confidence > 0) {
            return (88 + (confidence * 8)).round().clamp(90, 96);
          }
          return 90; // Sesuai target pelafalan pinyin (cth: 90%)
        }
        return 100;
      }

      // 3. EVALUASI TINGKAT 3: Kecocokan Fonetik Mandarin & Variasi ASR
      // Menangani variasi wajar pengenal suara (sh->s, zh->z, ch->c, how->hao, xie->sye, dll.)
      if (_isPhoneticallyClose(normTargetPinyin, normRecogPinyin)) {
        return 88; // Sangat mendekati target dengan variasi fonem minor
      }

      // 4. EVALUASI TINGKAT 4: Analisis Kesamaan Suku Kata (Syllable Overlap)
      final targetSyllables = _splitPinyinSyllables(normTargetPinyin);
      final recogSyllables = _splitPinyinSyllables(normRecogPinyin);
      if (targetSyllables.isNotEmpty && recogSyllables.isNotEmpty) {
        int matchedSyllables = 0;
        for (final syl in targetSyllables) {
          if (recogSyllables.any((r) => r == syl || _isPhoneticallyClose(syl, r))) {
            matchedSyllables++;
          }
        }
        if (matchedSyllables == targetSyllables.length) {
          return 88;
        }
        if (matchedSyllables > 0 && targetSyllables.length > 1) {
          final ratio = matchedSyllables / targetSyllables.length;
          return (60 + (ratio * 18)).round().clamp(60, 78);
        }
      }

      // 5. EVALUASI TINGKAT 5: Jarak Levenshtein pada Pinyin
      final pinyinLevScore = _calculateLevenshteinScore(normTargetPinyin, normRecogPinyin);
      if (pinyinLevScore >= 80) {
        return (80 + ((pinyinLevScore - 80) * 0.4)).round().clamp(80, 88);
      } else if (pinyinLevScore >= 60) {
        return (62 + ((pinyinLevScore - 60) * 0.65)).round().clamp(62, 75);
      } else if (pinyinLevScore >= 40) {
        return (35 + ((pinyinLevScore - 40) * 0.75)).round().clamp(35, 50);
      } else if (pinyinLevScore > 0) {
        return (pinyinLevScore * 0.6).round().clamp(10, 28);
      }
    }
  }

  // 6. EVALUASI TINGKAT 6: Levenshtein Karakter Hanzi jika keduanya teks Hanzi
  final hanziLevScore = _calculateLevenshteinScore(cleanTarget, cleanRecognized);
  return hanziLevScore;
}

/// Mengecek kedekatan fonetik pinyin untuk variasi ejaan ASR umum
bool _isPhoneticallyClose(String p1, String p2) {
  String simplify(String s) {
    return s
        .replaceAll('sh', 's')
        .replaceAll('zh', 'z')
        .replaceAll('ch', 'c')
        .replaceAll('sy', 's')
        .replaceAll('cy', 'c')
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u')
        .replaceAll('how', 'hao')
        .replaceAll('hau', 'hao')
        .replaceAll('haw', 'hao')
        .replaceAll('ho', 'hao')
        .replaceAll('xie', 'sie')
        .replaceAll('sye', 'sie')
        .replaceAll('cece', 'xiexie')
        .replaceAll('she', 'se');
  }

  final s1 = simplify(p1);
  final s2 = simplify(p2);
  return s1 == s2 || s1.contains(s2) || s2.contains(s1);
}

/// Memisahkan pinyin menjadi suku kata dasar untuk perbandingan silabis
List<String> _splitPinyinSyllables(String pinyin) {
  final clean = pinyin.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (clean.isEmpty) return [];

  final vowels = RegExp(r'[aeiou]+');
  final matches = vowels.allMatches(clean).toList();
  if (matches.length <= 1) return [clean];

  final List<String> syllables = [];
  int lastStart = 0;
  for (int i = 0; i < matches.length - 1; i++) {
    final nextVowelStart = matches[i + 1].start;
    final currVowelEnd = matches[i].end;
    final consonantLength = nextVowelStart - currVowelEnd;

    int splitPoint = currVowelEnd;
    if (consonantLength > 1) {
      splitPoint = currVowelEnd + 1;
    }
    syllables.add(clean.substring(lastStart, splitPoint));
    lastStart = splitPoint;
  }
  syllables.add(clean.substring(lastStart));
  return syllables;
}

int _calculateLevenshteinScore(String target, String recognized) {
  final targetRunes = target.runes.toList();
  final recognizedRunes = recognized.runes.toList();
  if (targetRunes.isEmpty || recognizedRunes.isEmpty) return 0;

  final distances = List.generate(
    targetRunes.length + 1,
    (_) => List<int>.filled(recognizedRunes.length + 1, 0),
  );
  for (var row = 0; row <= targetRunes.length; row++) {
    distances[row][0] = row;
  }
  for (var column = 0; column <= recognizedRunes.length; column++) {
    distances[0][column] = column;
  }
  for (var row = 1; row <= targetRunes.length; row++) {
    for (var column = 1; column <= recognizedRunes.length; column++) {
      final substitutionCost =
          targetRunes[row - 1] == recognizedRunes[column - 1] ? 0 : 1;
      distances[row][column] = [
        distances[row - 1][column] + 1,
        distances[row][column - 1] + 1,
        distances[row - 1][column - 1] + substitutionCost,
      ].reduce((a, b) => a < b ? a : b);
    }
  }
  final length = targetRunes.length > recognizedRunes.length
      ? targetRunes.length
      : recognizedRunes.length;
  return ((1 - distances.last.last / length) * 100).round().clamp(0, 100);
}

/// Normalisasi teks Mandarin (buang spasi dan tanda baca)
String normalizeMandarinTranscript(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[\s，。！？、,.!?;:：；"~_\-]'), '')
      .replaceAll("'", '')
      .replaceAll('`', '');
}

/// Normalisasi Pinyin (buang tanda nada ā, á, ǎ, à, dsb. dan spasi)
String normalizePinyin(String pinyin) {
  var s = pinyin.toLowerCase().trim();
  const toneMap = {
    'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
    'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
    'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
    'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
    'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
    'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
  };
  toneMap.forEach((toned, plain) {
    s = s.replaceAll(toned, plain);
  });
  return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
}