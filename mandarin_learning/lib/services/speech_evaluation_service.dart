/// Menghitung skor kemiripan antara teks ucapan yang dikenali dengan teks target Mandarin.
/// Mendukung pencocokan karakter Hanzi dan pencocokan Pinyin (bebas tanda nada).
int scoreMandarinTranscription(
  String target,
  String recognized, {
  String? targetPinyin,
}) {
  final cleanTarget = normalizeMandarinTranscript(target);
  final cleanRecognized = normalizeMandarinTranscript(recognized);

  if (cleanTarget.isEmpty || cleanRecognized.isEmpty) return 0;

  // 1. Cek kecocokan Hanzi langsung (persis sama)
  if (cleanTarget == cleanRecognized) return 100;

  // 2. Cek apakah target Hanzi terkandung utuh dalam rekaman ucapan yang lebih panjang
  // Contoh: target '你好' tapi perangkat mengenali '你好吗' -> 100%
  if (cleanRecognized.contains(cleanTarget)) return 100;

  // 3. Jika targetPinyin diberikan, cocokkan dengan pinyin yang dinormalisasi
  if (targetPinyin != null && targetPinyin.isNotEmpty) {
    final normTargetPinyin = normalizePinyin(targetPinyin);
    final normRecogPinyin = normalizePinyin(cleanRecognized);

    if (normTargetPinyin.isNotEmpty && normRecogPinyin.isNotEmpty) {
      if (normTargetPinyin == normRecogPinyin ||
          normRecogPinyin.contains(normTargetPinyin)) {
        return 100;
      }
      // Hitung kemiripan Levenshtein pada pinyin
      final pinyinScore = _calculateLevenshteinScore(normTargetPinyin, normRecogPinyin);
      if (pinyinScore >= 80) return pinyinScore;
    }
  }

  // 4. Hitung kemiripan Levenshtein karakter Hanzi
  return _calculateLevenshteinScore(cleanTarget, cleanRecognized);
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
