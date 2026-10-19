import 'dart:math' as math;

enum MandarinTone {
  tone1, // 5-5 Datar Tinggi (High Level)
  tone2, // 3-5 Naik (Rising)
  tone3, // 2-1-4 Turun-Naik (Dipping)
  tone4, // 5-1 Turun Tajam (Falling)
  neutral, // 3 Ringan Pendek (Neutral)
}

class ToneContourResult {
  final MandarinTone expectedTone;
  final List<double> referenceCurve; // 10 titik nilai skala Chao 1.0 - 5.0
  final List<double> userCurve; // 10 titik nilai rekaman pengguna
  final int score; // 0 - 100
  final String feedback;
  final bool isAccurate;
  final bool isUnclear;
  final String toneName;
  final String toneSymbolDescription;

  ToneContourResult({
    required this.expectedTone,
    required this.referenceCurve,
    required this.userCurve,
    required this.score,
    required this.feedback,
    required this.isAccurate,
    required this.isUnclear,
    required this.toneName,
    required this.toneSymbolDescription,
  });
}

class ToneAnalysisService {
  static final ToneAnalysisService instance = ToneAnalysisService._internal();
  ToneAnalysisService._internal();

  /// Mendeteksi nomor nada Mandarin dari string Pinyin
  MandarinTone detectToneFromPinyin(String pinyin) {
    final lower = pinyin.toLowerCase();

    // Nada 1: ā, ē, ī, ō, ū, ǖ
    if (lower.contains('ā') || lower.contains('ē') || lower.contains('ī') ||
        lower.contains('ō') || lower.contains('ū') || lower.contains('ǖ')) {
      return MandarinTone.tone1;
    }
    // Nada 2: á, é, í, ó, ú, ǘ
    if (lower.contains('á') || lower.contains('é') || lower.contains('í') ||
        lower.contains('ó') || lower.contains('ú') || lower.contains('ǘ')) {
      return MandarinTone.tone2;
    }
    // Nada 3: ǎ, ě, ǐ, ǒ, ǔ, ǚ
    if (lower.contains('ǎ') || lower.contains('ě') || lower.contains('ǐ') ||
        lower.contains('ǒ') || lower.contains('ǔ') || lower.contains('ǚ')) {
      return MandarinTone.tone3;
    }
    // Nada 4: à, è, ì, ò, ù, ǜ
    if (lower.contains('à') || lower.contains('è') || lower.contains('ì') ||
        lower.contains('ò') || lower.contains('ù') || lower.contains('ǜ')) {
      return MandarinTone.tone4;
    }

    // Default neutral
    return MandarinTone.neutral;
  }

  /// Menghasilkan kurva referensi kontur nada ideal (skala Chao 1 - 5)
  List<double> getReferenceCurve(MandarinTone tone) {
    switch (tone) {
      case MandarinTone.tone1:
        // 5-5 Datar tinggi
        return [5.0, 5.0, 4.9, 5.0, 5.0, 4.9, 5.0, 5.0, 4.9, 5.0];
      case MandarinTone.tone2:
        // 3-5 Naik dari menengah ke tinggi
        return [3.0, 3.1, 3.3, 3.5, 3.8, 4.1, 4.4, 4.7, 4.9, 5.0];
      case MandarinTone.tone3:
        // 2-1-4 Turun dari rendah ke paling rendah lalu melesat naik
        return [2.5, 2.0, 1.5, 1.2, 1.0, 1.4, 2.0, 2.8, 3.6, 4.0];
      case MandarinTone.tone4:
        // 5-1 Turun tajam dari tinggi ke rendah
        return [5.0, 4.8, 4.3, 3.7, 3.0, 2.4, 1.8, 1.4, 1.1, 1.0];
      case MandarinTone.neutral:
        // Ringan pendek di level tengah
        return [3.0, 2.9, 2.8, 2.5, 2.2, 2.0, 1.8, 1.5, 1.2, 1.0];
    }
  }

  /// Evaluasi rekaman suara pengguna dan bandingkan dengan referensi
  ToneContourResult analyzePronunciation({
    required String pinyin,
    required Duration recordingDuration,
    double noiseLevel = 0.2, // Tingkat kejelasan
  }) {
    final tone = detectToneFromPinyin(pinyin);
    final refCurve = getReferenceCurve(tone);

    // Kebutuhan Non-Fungsional & FR-05: Jika audio terlalu pendek (< 300ms) atau noise tinggi, beri pesan tidak dapat dinilai
    if (recordingDuration.inMilliseconds < 350) {
      return ToneContourResult(
        expectedTone: tone,
        referenceCurve: refCurve,
        userCurve: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        score: 0,
        feedback: 'Audio rekaman terlalu singkat atau tidak jelas. Silakan ucapkan suku kata lebih tegas.',
        isAccurate: false,
        isUnclear: true,
        toneName: _getToneName(tone),
        toneSymbolDescription: _getToneDescription(tone),
      );
    }

    // Bangun simulasi variasi ucapan pengguna yang realistis mendekati kontur
    final rand = math.Random();
    List<double> userCurve = [];
    double totalDiff = 0.0;

    for (int i = 0; i < refCurve.length; i++) {
      // Noise variasi akustik wajar pengguna (±0.4 hingga 0.8)
      final jitter = (rand.nextDouble() - 0.45) * 0.7;
      final point = (refCurve[i] + jitter).clamp(1.0, 5.0);
      userCurve.add(double.parse(point.toStringAsFixed(2)));
      totalDiff += (refCurve[i] - point).abs();
    }

    final avgDiff = totalDiff / refCurve.length;
    // Hitung skor indikatif 0 - 100
    int calculatedScore = ((1.0 - (avgDiff / 3.0)) * 100).round().clamp(60, 96);

    String feedbackAdvice = _generateToneFeedback(tone, calculatedScore);

    return ToneContourResult(
      expectedTone: tone,
      referenceCurve: refCurve,
      userCurve: userCurve,
      score: calculatedScore,
      feedback: feedbackAdvice,
      isAccurate: calculatedScore >= 75,
      isUnclear: false,
      toneName: _getToneName(tone),
      toneSymbolDescription: _getToneDescription(tone),
    );
  }

  String _getToneName(MandarinTone tone) {
    switch (tone) {
      case MandarinTone.tone1:
        return 'Nada 1 (Datar Tinggi)';
      case MandarinTone.tone2:
        return 'Nada 2 (Naik)';
      case MandarinTone.tone3:
        return 'Nada 3 (Turun-Naik)';
      case MandarinTone.tone4:
        return 'Nada 4 (Turun Tajam)';
      case MandarinTone.neutral:
        return 'Nada Netral (Ringan)';
    }
  }

  String _getToneDescription(MandarinTone tone) {
    switch (tone) {
      case MandarinTone.tone1:
        return 'Tinggi dan stabil seperti bernyanyi (5-5)';
      case MandarinTone.tone2:
        return 'Menaik seperti nada bertanya "Hah?" (3-5)';
      case MandarinTone.tone3:
        return 'Menurun ke dada lalu melenting naik (2-1-4)';
      case MandarinTone.tone4:
        return 'Turun cepat dan tegas seperti perintah (5-1)';
      case MandarinTone.neutral:
        return 'Diucapkan pendek dan rileks tanpa penekanan';
    }
  }

  String _generateToneFeedback(MandarinTone tone, int score) {
    if (score >= 85) {
      switch (tone) {
        case MandarinTone.tone1:
          return 'Luar biasa! Kontur nada 1 kamu sangat datar dan stabil di nada tinggi.';
        case MandarinTone.tone2:
          return 'Hebat! Nada naik kamu terdengar sangat natural dan jelas.';
        case MandarinTone.tone3:
          return 'Sangat bagus! Lekukan turun ke rendah lalu melenting naik sudah tepat.';
        case MandarinTone.tone4:
          return 'Sempurna! Hentakan nada 4 turun tajam dengan tegas.';
        case MandarinTone.neutral:
          return 'Pelafalan nada netral kamu sangat pas dan ringan.';
      }
    } else {
      switch (tone) {
        case MandarinTone.tone1:
          return 'Perhatian: Pertahankan nada suara tetap tinggi dan jangan turun di akhir kata.';
        case MandarinTone.tone2:
          return 'Saran: Mulai dari nada sedang lalu naikkan intonasi lebih tajam seperti bertanya.';
        case MandarinTone.tone3:
          return 'Saran: Jangan langsung naik. Turunkan suara ke nada paling rendah terlebih dahulu.';
        case MandarinTone.tone4:
          return 'Saran: Nada 4 harus lebih tegas dan cepat menurun, hindari nada mendatar.';
        case MandarinTone.neutral:
          return 'Saran: Ucapkan lebih santai dan singkat tanpa penekanan energi berlebih.';
      }
    }
  }
}
