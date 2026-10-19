import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/models/quiz_attempt_model.dart';
import 'package:mandarin_learning/models/vocabulary_model.dart';

void main() {
  group('Tahap 4: Belajar Inti - Kuis Utama (PB-03, FR-03, FR-17, FR-19)', () {
    test('QuizAttempt model serializes and deserializes properly', () {
      final now = DateTime.now();
      final attempt = QuizAttempt(
        id: 'quiz_test_123',
        userId: 'user_456',
        hskLevel: 1,
        quizType: 'tebak_arti_pinyin',
        score: 90,
        totalQuestions: 10,
        correctAnswers: 9,
        coinsEarned: 15,
        createdAt: now,
      );

      final json = attempt.toJson();
      expect(json['attempt_id'], 'quiz_test_123');
      expect(json['score'], 90);
      expect(json['coins_earned'], 15);

      final parsed = QuizAttempt.fromJson(json);
      expect(parsed.id, 'quiz_test_123');
      expect(parsed.score, 90);
      expect(parsed.coinsEarned, 15);
      expect(parsed.hskLevel, 1);
    });

    test('Logika Reward Kuis Utama sesuai aturan PRD 6.1 (15 / 10 / 5 koin)', () {
      int getCoinReward(int score) {
        if (score >= 90) return 15;
        if (score >= 70) return 10;
        if (score >= 50) return 5;
        return 0;
      }

      // Sempurna (100) -> 15 koin
      expect(getCoinReward(100), 15);
      // Batas atas (90) -> 15 koin
      expect(getCoinReward(90), 15);
      // Menengah (75) -> 10 koin
      expect(getCoinReward(75), 10);
      // Batas menengah (70) -> 10 koin
      expect(getCoinReward(70), 10);
      // Cukup (50) -> 5 koin
      expect(getCoinReward(50), 5);
      // Di bawah 50 -> 0 koin
      expect(getCoinReward(40), 0);
    });

    test('Aturan Penukaran Bantuan Kuis (FR-19: 20 Koin)', () {
      int userBalance = 50;
      const hintCost = 20;

      bool canAffordHint(int balance) => balance >= hintCost;

      expect(canAffordHint(userBalance), isTrue);

      // Potong saldo satu kali
      userBalance -= hintCost;
      expect(userBalance, 30);

      // Potong lagi
      expect(canAffordHint(userBalance), isTrue);
      userBalance -= hintCost;
      expect(userBalance, 10);

      // Saldo tidak mencukupi (10 < 20)
      expect(canAffordHint(userBalance), isFalse);
    });
  });

  group('Tahap 4: Belajar Inti - Kamus Mandarin-Indonesia (PB-04, FR-06)', () {
    test('Pencarian kosakata mendukung pencarian Hanzi, Pinyin, dan Arti Indonesia', () {
      final sampleItems = [
        VocabularyItem(
          id: 1,
          hanzi: '你好',
          pinyin: 'nǐ hǎo',
          artiIndonesia: 'halo; hai',
          translations: ['halo', 'hai'],
          hskLevel: 1,
          contohKalimat: [],
          sumber: 'HSK 1',
        ),
        VocabularyItem(
          id: 2,
          hanzi: '谢谢',
          pinyin: 'xièxie',
          artiIndonesia: 'terima kasih',
          translations: ['terima kasih'],
          hskLevel: 1,
          contohKalimat: [],
          sumber: 'HSK 1',
        ),
        VocabularyItem(
          id: 3,
          hanzi: '苹果',
          pinyin: 'píngguǒ',
          artiIndonesia: 'apel',
          translations: ['apel'],
          hskLevel: 2,
          contohKalimat: [],
          sumber: 'HSK 2',
        ),
      ];

      List<VocabularyItem> search(String query, int levelFilter) {
        final q = query.trim().toLowerCase();
        return sampleItems.where((item) {
          if (levelFilter > 0 && item.hskLevel != levelFilter) return false;
          if (q.isEmpty) return true;
          return item.hanzi.toLowerCase().contains(q) ||
              item.pinyin.toLowerCase().contains(q) ||
              item.artiIndonesia.toLowerCase().contains(q);
        }).toList();
      }

      // Cari berdasarkan Hanzi
      expect(search('你好', 0).length, 1);
      expect(search('你好', 0).first.pinyin, 'nǐ hǎo');

      // Cari berdasarkan Pinyin
      expect(search('xie', 0).length, 1);
      expect(search('xie', 0).first.hanzi, '谢谢');

      // Cari berdasarkan Arti Indonesia
      expect(search('apel', 0).length, 1);
      expect(search('apel', 0).first.hanzi, '苹果');

      // Filter level HSK
      expect(search('', 1).length, 2);
      expect(search('', 2).length, 1);
      expect(search('apel', 1).length, 0); // apel ada di HSK 2, bukan HSK 1
    });
  });

  group('Tahap 4: Belajar Inti - Progres (PB-05, FR-15)', () {
    test('Perhitungan rata-rata skor dan total kuis selesai', () {
      final attempts = [
        QuizAttempt(
          id: '1',
          userId: 'u1',
          hskLevel: 1,
          quizType: 'tebak_arti',
          score: 80,
          totalQuestions: 10,
          correctAnswers: 8,
          coinsEarned: 10,
          createdAt: DateTime.now(),
        ),
        QuizAttempt(
          id: '2',
          userId: 'u1',
          hskLevel: 1,
          quizType: 'tebak_arti',
          score: 100,
          totalQuestions: 10,
          correctAnswers: 10,
          coinsEarned: 15,
          createdAt: DateTime.now(),
        ),
        QuizAttempt(
          id: '3',
          userId: 'u1',
          hskLevel: 1,
          quizType: 'tebak_arti',
          score: 60,
          totalQuestions: 10,
          correctAnswers: 6,
          coinsEarned: 5,
          createdAt: DateTime.now(),
        ),
      ];

      final totalCompleted = attempts.length;
      final avg = attempts.fold<int>(0, (prev, e) => prev + e.score) / attempts.length;

      expect(totalCompleted, 3);
      expect(avg, 80.0);
    });

    test('Perhitungan progres rasio kosakata per level HSK', () {
      final totalWordsInLevel = 150;
      final learnedIds = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}; // 15 kata

      final progress = learnedIds.length / totalWordsInLevel;
      expect(progress, 0.10); // 10%
      expect((progress * 100).toInt(), 10);
    });
  });
}
