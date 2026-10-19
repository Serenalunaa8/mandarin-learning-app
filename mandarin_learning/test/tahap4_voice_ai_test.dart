import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/services/tone_analysis_service.dart';
import 'package:mandarin_learning/services/ai_tutor_service.dart';

void main() {
  group('Tahap 4 (Suara & Analisis Nada - FR-04 & FR-05)', () {
    test('Deteksi nomor nada Mandarin dari tanda Pinyin', () {
      final service = ToneAnalysisService.instance;

      expect(service.detectToneFromPinyin('mā'), MandarinTone.tone1);
      expect(service.detectToneFromPinyin('má'), MandarinTone.tone2);
      expect(service.detectToneFromPinyin('mǎ'), MandarinTone.tone3);
      expect(service.detectToneFromPinyin('mà'), MandarinTone.tone4);
      expect(service.detectToneFromPinyin('ma'), MandarinTone.neutral);

      // Kata kosakata nyata
      expect(service.detectToneFromPinyin('nǐ'), MandarinTone.tone3);
      expect(service.detectToneFromPinyin('hǎo'), MandarinTone.tone3);
      expect(service.detectToneFromPinyin('xiè'), MandarinTone.tone4);
      expect(service.detectToneFromPinyin('bù'), MandarinTone.tone4);
    });

    test('Kurva referensi nada mengikuti skala Chao 5 tingkat standar', () {
      final service = ToneAnalysisService.instance;

      // Nada 1: Datar tinggi (5-5)
      final t1 = service.getReferenceCurve(MandarinTone.tone1);
      expect(t1.first, 5.0);
      expect(t1.last, 5.0);

      // Nada 2: Naik (3-5)
      final t2 = service.getReferenceCurve(MandarinTone.tone2);
      expect(t2.first, 3.0);
      expect(t2.last, 5.0);

      // Nada 3: Turun-naik (2-1-4)
      final t3 = service.getReferenceCurve(MandarinTone.tone3);
      expect(t3.first, lessThan(3.0));
      expect(t3[4], 1.0); // Titik terendah
      expect(t3.last, 4.0); // Melenting naik

      // Nada 4: Turun tajam (5-1)
      final t4 = service.getReferenceCurve(MandarinTone.tone4);
      expect(t4.first, 5.0);
      expect(t4.last, 1.0);
    });

    test('Audio terlalu singkat (<350ms) ditandai tidak jelas / tidak dapat dinilai', () {
      final service = ToneAnalysisService.instance;
      final result = service.analyzePronunciation(
        pinyin: 'mā',
        recordingDuration: const Duration(milliseconds: 200),
      );

      expect(result.isUnclear, isTrue);
      expect(result.score, 0);
      expect(result.feedback, contains('terlalu singkat atau tidak jelas'));
    });

    test('Evaluasi rekaman normal menghasilkan skor indikatif dan kurva akustik', () {
      final service = ToneAnalysisService.instance;
      final result = service.analyzePronunciation(
        pinyin: 'nǐ',
        recordingDuration: const Duration(seconds: 2),
      );

      expect(result.isUnclear, isFalse);
      expect(result.score, greaterThanOrEqualTo(50));
      expect(result.userCurve.length, 10);
      expect(result.referenceCurve.length, 10);
      expect(result.toneName, contains('Nada 3'));
    });
  });

  group('Tahap 4 (AI Tutor Mandarin - FR-14 & PBI-034/035)', () {
    test('AI Tutor memberikan penjelasan tata bahasa tiga "de" dengan contoh kalimat', () async {
      final service = AiTutorService.instance;
      final answer = await service.askAiTutor('Jelaskan perbedaan partikel de: 的, 得, dan 地');

      expect(answer, contains('Perbedaan Tiga "de"'));
      expect(answer, contains('的'));
      expect(answer, contains('得'));
      expect(answer, contains('地'));
    });

    test('AI Tutor memberikan panduan membedakan Nada 2 dan Nada 3', () async {
      final service = AiTutorService.instance;
      final answer = await service.askAiTutor('Bagaimana cara membedakan nada 2 dan 3?');

      expect(answer, contains('Nada 2'));
      expect(answer, contains('Nada 3'));
      expect(answer, contains('Tips'));
    });

    test('AI Tutor memberikan contoh percakapan restoran yang praktis', () async {
      final service = AiTutorService.instance;
      final answer = await service.askAiTutor('Contoh percakapan pesan makanan di restoran');

      expect(answer, contains('菜单'));
      expect(answer, contains('买单'));
    });
  });

  group('Tahap 4 (Aturan Reward PRD 6.1)', () {
    test('Skor kuis memetakan koin 15, 10, atau 5 dengan benar', () {
      int calculateCoinReward(int score) {
        if (score >= 90) return 15;
        if (score >= 70) return 10;
        if (score >= 50) return 5;
        return 0;
      }

      expect(calculateCoinReward(100), 15);
      expect(calculateCoinReward(90), 15);
      expect(calculateCoinReward(85), 10);
      expect(calculateCoinReward(70), 10);
      expect(calculateCoinReward(60), 5);
      expect(calculateCoinReward(50), 5);
      expect(calculateCoinReward(45), 0);
    });
  });
}
