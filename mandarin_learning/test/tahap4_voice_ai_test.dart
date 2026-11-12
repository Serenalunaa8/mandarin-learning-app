import 'package:flutter_test/flutter_test.dart';
import 'package:nihaoki/services/tone_analysis_service.dart';
import 'package:nihaoki/services/ai_tutor_service.dart';
import 'package:nihaoki/services/speech_evaluation_service.dart';

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

    test(
      'Ucapan dinilai dari hasil transkripsi, bukan kontur suara simulasi',
      () {
        expect(scoreMandarinTranscription('你好', '你好'), 100);
        expect(scoreMandarinTranscription('你好', '你'), 50);
        expect(scoreMandarinTranscription('你好', '再见'), 0);
      },
    );
  });

  group('Tahap 4 (AI Tutor Mandarin - FR-14 & PBI-034/035)', () {
    test('AI Tutor menyediakan 2 mode AI: app_api (dengan Database) dan gemini (Murni)', () {
      expect(
        AiTutorMode.values.map((mode) => mode.id),
        containsAll(['app_api', 'gemini']),
      );
      expect(AiTutorMode.appApi.id, 'app_api');
      expect(AiTutorMode.gemini.id, 'gemini');
      expect(AiTutorMode.appApi.label, 'LingLing (玲玲)');
      expect(AiTutorMode.gemini.label, 'Gemini');
      expect(AiTutorMode.appApi.endpoint, 'lingling-ai');
      expect(AiTutorMode.gemini.endpoint, 'gemini-ai');
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
