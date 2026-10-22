enum MandarinTone { tone1, tone2, tone3, tone4, neutral }

class ToneAnalysisService {
  static final ToneAnalysisService instance = ToneAnalysisService._internal();
  ToneAnalysisService._internal();

  MandarinTone detectToneFromPinyin(String pinyin) {
    final lower = pinyin.toLowerCase();
    if (_containsAny(lower, 'āēīōūǖ')) return MandarinTone.tone1;
    if (_containsAny(lower, 'áéíóúǘ')) return MandarinTone.tone2;
    if (_containsAny(lower, 'ǎěǐǒǔǚ')) return MandarinTone.tone3;
    if (_containsAny(lower, 'àèìòùǜ')) return MandarinTone.tone4;
    return MandarinTone.neutral;
  }

  bool _containsAny(String text, String marks) =>
      marks.runes.any((mark) => text.runes.contains(mark));

  List<double> getReferenceCurve(MandarinTone tone) {
    switch (tone) {
      case MandarinTone.tone1:
        return [5, 5, 4.9, 5, 5, 4.9, 5, 5, 4.9, 5];
      case MandarinTone.tone2:
        return [3, 3.1, 3.3, 3.5, 3.8, 4.1, 4.4, 4.7, 4.9, 5];
      case MandarinTone.tone3:
        return [2.5, 2, 1.5, 1.2, 1, 1.4, 2, 2.8, 3.6, 4];
      case MandarinTone.tone4:
        return [5, 4.8, 4.3, 3.7, 3, 2.4, 1.8, 1.4, 1.1, 1];
      case MandarinTone.neutral:
        return [3, 2.9, 2.8, 2.5, 2.2, 2, 1.8, 1.5, 1.2, 1];
    }
  }
}
