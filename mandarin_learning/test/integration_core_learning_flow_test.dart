import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/models/vocabulary_model.dart';
import 'package:mandarin_learning/models/quiz_attempt_model.dart';
import 'package:mandarin_learning/models/coin_transaction_model.dart';
import 'package:mandarin_learning/services/tone_analysis_service.dart';
import 'package:mandarin_learning/services/speech_evaluation_service.dart';

// PBI-070: Integration Testing Alur Utama (Materi ➔ Kuis ➔ Pelafalan ➔ Reward Koin)
// Sesuai PRD 8.1 Alur Utama Pembelajaran & DoD Sprint 7

void main() {
  group('PBI-070: Integration Test Alur Pembelajaran Utama (End-to-End Logic)', () {
    test('Simulasi Alur Penuh: Pemilihan Materi ➔ Kuis ➔ Pelafalan ➔ Reward Koin ➔ Ledger', () async {
      // 1. DATA MATERI: Pengguna memilih kosakata HSK 1
      final mockVocab = VocabularyItem(
        id: 1,
        hanzi: '你好',
        pinyin: 'nǐ hǎo',
        artiIndonesia: 'halo / apa kabar',
        translations: ['halo', 'hai', 'apa kabar'],
        hskLevel: 1,
        jenisKata: 'Ungkapan',
        contohKalimat: [
          ExampleSentence(
            hanzi: '你好！很高兴认识你。',
            arti: 'Halo! Senang berkenalan denganmu.',
          ),
        ],
        sumber: 'HSK 1 Official Vocabulary',
      );

      expect(mockVocab.hskLevel, 1);
      expect(mockVocab.hanzi, '你好');
      expect(mockVocab.contohKalimat.length, 1);

      // 2. STATUS PROGRES MATERI: Tandai kosakata selesai dipelajari
      final learnedVocabIds = <int>{};
      learnedVocabIds.add(mockVocab.id);
      expect(learnedVocabIds.contains(1), isTrue);

      // 3. KUIS UTAMA: Pengguna mengerjakan 10 soal kuis
      const totalQuestions = 10;
      const correctAnswers = 9; // Skor 90%
      final quizScore = ((correctAnswers / totalQuestions) * 100).round();
      expect(quizScore, 90);

      // Hitung Reward Kuis (PRD 6.1: Skor >= 90 ➔ 15 koin)
      int quizReward = 0;
      if (quizScore >= 90) {
        quizReward = 15;
      } else if (quizScore >= 70) {
        quizReward = 10;
      } else if (quizScore >= 50) {
        quizReward = 5;
      }
      expect(quizReward, 15);

      // Rekam Quiz Attempt
      final quizAttempt = QuizAttempt(
        id: 'quiz_e2e_001',
        userId: 'user_test_e2e',
        hskLevel: 1,
        quizType: 'tebak_arti_pinyin',
        score: quizScore,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        coinsEarned: quizReward,
        createdAt: DateTime.now(),
      );
      expect(quizAttempt.score, 90);
      expect(quizAttempt.coinsEarned, 15);

      // 4. LEDGER KOIN: Masukkan transaksi kuis ke buku besar
      final coinLedger = <CoinTransaction>[];
      int userBalance = 50; // Saldo awal

      void recordTransaction(CoinTransaction tx) {
        if (!coinLedger.any((t) => t.attemptId == tx.attemptId)) {
          coinLedger.add(tx);
          userBalance += tx.amount;
        }
      }

      recordTransaction(
        CoinTransaction(
          id: 'tx_quiz_1',
          userId: 'user_test_e2e',
          attemptId: quizAttempt.id,
          amount: quizReward,
          transactionType: 'quiz_reward',
          description: 'Skor kuis 90%',
          createdAt: DateTime.now(),
        ),
      );
      expect(userBalance, 65); // 50 + 15 = 65
      expect(coinLedger.length, 1);

      // 5. LATIHAN PELAFALAN & ANALISIS NADA: Evaluasi nada dari kata yang baru dipelajari
      final detectedTone = ToneAnalysisService.instance.detectToneFromPinyin(mockVocab.pinyin);
      // 'nǐ' memiliki nada 3 (dipping tone)
      expect(detectedTone, MandarinTone.tone3);

      final transcriptionScore = scoreMandarinTranscription(
        mockVocab.hanzi,
        '你好',
      );
      expect(transcriptionScore, 100);

      // Berikan reward pelafalan sah (+5 koin)
      const speechReward = 5;
      recordTransaction(
        CoinTransaction(
          id: 'tx_speech_1',
          userId: 'user_test_e2e',
          attemptId: 'speech_e2e_001',
          amount: speechReward,
          transactionType: 'speech_reward',
          description: 'Pelafalan kata: 你好',
          createdAt: DateTime.now(),
        ),
      );
      expect(userBalance, 70); // 65 + 5 = 70
      expect(coinLedger.length, 2);

      // 6. PENUKARAN BANTUAN (FR-19): Pengguna menukar 20 koin untuk bantuan
      const hintCost = 20;
      expect(userBalance >= hintCost, isTrue);

      recordTransaction(
        CoinTransaction(
          id: 'tx_hint_1',
          userId: 'user_test_e2e',
          attemptId: 'hint_e2e_001',
          amount: -hintCost,
          transactionType: 'quiz_hint',
          description: 'Bantuan kuis',
          createdAt: DateTime.now(),
        ),
      );
      expect(userBalance, 50); // 70 - 20 = 50
      expect(coinLedger.length, 3);

      // 7. PENCEGAHAN TRANSAKSI GANDA: Percobaan ulangi attempt kuis yang sama
      final initialCount = coinLedger.length;
      recordTransaction(
        CoinTransaction(
          id: 'tx_quiz_dup',
          userId: 'user_test_e2e',
          attemptId: quizAttempt.id, // ID attempt sama!
          amount: quizReward,
          transactionType: 'quiz_reward',
          description: 'Skor kuis 90% (duplikat)',
          createdAt: DateTime.now(),
        ),
      );
      // Transaksi duplikat harus ditolak
      expect(coinLedger.length, initialCount);
      expect(userBalance, 50);
    });
  });
}
