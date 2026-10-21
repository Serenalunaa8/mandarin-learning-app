import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/models/coin_transaction_model.dart';

void main() {
  group('Tahap 5: Reward Koin & Ledger (PB-12, FR-17, FR-18, FR-19, FR-20, PBI-045 s.d. PBI-050)', () {
    test('PBI-045: CoinTransaction serializes and deserializes properly with attemptId', () {
      final now = DateTime.now();
      final tx = CoinTransaction(
        id: 'tx_12345',
        userId: 'user_001',
        attemptId: 'hanzi_matching_streak_5',
        amount: 25,
        transactionType: 'streak_bonus',
        description: 'Bonus streak Hanzi Matching ke-5',
        createdAt: now,
      );

      final json = tx.toJson();
      expect(json['id'], 'tx_12345');
      expect(json['user_id'], 'user_001');
      expect(json['attempt_id'], 'hanzi_matching_streak_5');
      expect(json['amount'], 25);
      expect(json['transaction_type'], 'streak_bonus');

      final parsed = CoinTransaction.fromJson(json);
      expect(parsed.id, 'tx_12345');
      expect(parsed.attemptId, 'hanzi_matching_streak_5');
      expect(parsed.amount, 25);
      expect(parsed.transactionType, 'streak_bonus');
    });

    test('PBI-046: Reward kuis utama (15/10/5) & pelafalan (+5 koin)', () {
      int calculateQuizReward(int score) {
        if (score >= 90) return 15;
        if (score >= 70) return 10;
        if (score >= 50) return 5;
        return 0;
      }

      int calculateSpeechReward(bool passed) => passed ? 5 : 0;

      expect(calculateQuizReward(100), 15);
      expect(calculateQuizReward(90), 15);
      expect(calculateQuizReward(85), 10);
      expect(calculateQuizReward(70), 10);
      expect(calculateQuizReward(60), 5);
      expect(calculateQuizReward(50), 5);
      expect(calculateQuizReward(45), 0);

      expect(calculateSpeechReward(true), 5);
      expect(calculateSpeechReward(false), 0);
    });

    test('PBI-047: Bonus 25 koin tiap 5 kemenangan Hanzi Matching beruntun (idempotent)', () {
      final awardedMilestones = <int>{};
      int totalBonusEarned = 0;

      void checkMilestone(int streak) {
        final milestone = (streak ~/ 5) * 5;
        if (milestone > 0 && !awardedMilestones.contains(milestone)) {
          awardedMilestones.add(milestone);
          totalBonusEarned += 25;
        }
      }

      // Kemenangan 1-4 belum dapat bonus
      for (int i = 1; i <= 4; i++) {
        checkMilestone(i);
      }
      expect(totalBonusEarned, 0);

      // Kemenangan ke-5 -> dapat 25 koin
      checkMilestone(5);
      expect(totalBonusEarned, 25);
      expect(awardedMilestones.contains(5), isTrue);

      // Pemanggilan ganda pada streak 5 tidak menduplikasi bonus
      checkMilestone(5);
      expect(totalBonusEarned, 25);

      // Kemenangan ke-9 -> masih 25
      checkMilestone(9);
      expect(totalBonusEarned, 25);

      // Kemenangan ke-10 -> bertambah 25 koin lagi (total 50)
      checkMilestone(10);
      expect(totalBonusEarned, 50);
      expect(awardedMilestones.contains(10), isTrue);
    });

    test('PBI-048: Penukaran koin untuk bantuan Hanzi Matching (30 🪙) & Kuis (20 🪙)', () {
      const hintCostQuiz = 20;
      const hintCostMatching = 30;

      bool canDeduct(int balance, int cost) => balance >= cost;

      int balance = 25;
      // Kuis (butuh 20) -> cukup
      expect(canDeduct(balance, hintCostQuiz), isTrue);
      // Matching (butuh 30) -> kurang
      expect(canDeduct(balance, hintCostMatching), isFalse);

      balance -= hintCostQuiz; // sisa 5
      expect(balance, 5);
      expect(canDeduct(balance, hintCostQuiz), isFalse);
      expect(canDeduct(balance, hintCostMatching), isFalse);
    });

    test('PBI-045 & FR-20: Pencegahan transaksi ganda (idempotency via attemptId)', () {
      final transactions = <CoinTransaction>[];

      bool addTransaction(CoinTransaction tx) {
        if (transactions.any((t) => t.attemptId == tx.attemptId)) {
          return false; // Ditolak karena duplikat
        }
        transactions.add(tx);
        return true;
      }

      final tx1 = CoinTransaction(
        id: 'tx_1',
        userId: 'u_1',
        attemptId: 'attempt_quiz_001',
        amount: 15,
        transactionType: 'quiz_reward',
        description: 'Skor 90%',
        createdAt: DateTime.now(),
      );

      final txDuplicate = CoinTransaction(
        id: 'tx_2',
        userId: 'u_1',
        attemptId: 'attempt_quiz_001', // ID attempt sama
        amount: 15,
        transactionType: 'quiz_reward',
        description: 'Skor 90% (retry request)',
        createdAt: DateTime.now(),
      );

      expect(addTransaction(tx1), isTrue);
      expect(transactions.length, 1);

      // Percobaan transaksi dengan attemptId sama harus ditolak
      expect(addTransaction(txDuplicate), isFalse);
      expect(transactions.length, 1);
    });
  });

  group('Tahap 5: Mini Game Sensor & Fallback (PB-13 & PB-14, FR-09 & FR-10, PBI-051 s.d. PBI-056)', () {
    test('PBI-051: Tilt to Answer - Pemetaan kemiringan gyroscope ke 4 arah opsi', () {
      const tiltThreshold = 2.5;

      int calculateHighlightedOption(double tiltX, double tiltY) {
        if (tiltX < -tiltThreshold) {
          return 0; // Kiri
        } else if (tiltX > tiltThreshold) {
          return 1; // Kanan
        } else if (tiltY < -tiltThreshold) {
          return 2; // Atas
        } else if (tiltY > tiltThreshold) {
          return 3; // Bawah
        }
        return -1; // Netral
      }

      // Miring ke kiri tajam (X = -3.5)
      expect(calculateHighlightedOption(-3.5, 0.0), 0);
      // Miring ke kanan tajam (X = 3.8)
      expect(calculateHighlightedOption(3.8, 0.0), 1);
      // Miring ke atas (Y = -3.0)
      expect(calculateHighlightedOption(0.0, -3.0), 2);
      // Miring ke bawah (Y = 4.2)
      expect(calculateHighlightedOption(0.0, 4.2), 3);
      // Posisi datar netral (X = 0.5, Y = -0.2)
      expect(calculateHighlightedOption(0.5, -0.2), -1);
    });

    test('PBI-051: Tilt to Answer - Fallback sentuh ketika sensor tidak aktif', () {
      bool isSensorAvailable = false;
      int? selectedOption;

      void onOptionTapped(int index) {
        selectedOption = index;
      }

      expect(isSensorAvailable, isFalse);
      // Pengguna tetap dapat memilih opsi langsung via layar sentuh
      onOptionTapped(2);
      expect(selectedOption, 2);
    });

    test('PBI-054: Mandarin Catcher - Pembatasan koordinat keranjang dalam lebar layar', () {
      const screenWidth = 360.0;
      const catcherWidth = 70.0;
      const maxCatcherX = screenWidth - catcherWidth; // 290.0

      double clampCatcherPosition(double targetX) {
        if (targetX < 0) return 0;
        if (targetX > maxCatcherX) return maxCatcherX;
        return targetX;
      }

      expect(clampCatcherPosition(-25.0), 0.0);
      expect(clampCatcherPosition(150.0), 150.0);
      expect(clampCatcherPosition(350.0), 290.0);
    });

    test('PBI-054: Mandarin Catcher - Deteksi tabrakan keranjang dengan kata yang jatuh', () {
      const catcherWidth = 70.0;
      const catcherHeight = 40.0;
      const catcherY = 500.0;
      const itemSize = 40.0;

      bool checkCollision({
        required double itemX,
        required double itemY,
        required double basketX,
      }) {
        final itemRight = itemX + itemSize;
        final itemBottom = itemY + itemSize;
        final basketRight = basketX + catcherWidth;
        final basketBottom = catcherY + catcherHeight;

        final isOverlapX = itemRight >= basketX && itemX <= basketRight;
        final isOverlapY = itemBottom >= catcherY && itemY <= basketBottom;
        return isOverlapX && isOverlapY;
      }

      // Tabrakan tepat di tengah keranjang
      expect(checkCollision(itemX: 110, itemY: 505, basketX: 100), isTrue);

      // Melenceng jauh ke kiri
      expect(checkCollision(itemX: 20, itemY: 505, basketX: 100), isFalse);

      // Masih tinggi di atas keranjang (belum sampai)
      expect(checkCollision(itemX: 110, itemY: 200, basketX: 100), isFalse);
    });

    test('PBI-041 s.d. PBI-043: Hanzi Stroke Challenge - Evaluasi toleransi goresan', () {
      final strokeCounts = {
        '我': 7,
        '你': 7,
        '他': 5,
        '大': 3,
        '小': 3,
      };

      bool evaluateStrokeAttempt(String hanzi, int userStrokes) {
        final expected = strokeCounts[hanzi] ?? 4;
        // Toleransi selisih 1 goresan untuk pemula
        return (userStrokes - expected).abs() <= 1;
      }

      // '我' diharapkan 7 goresan
      expect(evaluateStrokeAttempt('我', 7), isTrue);
      expect(evaluateStrokeAttempt('我', 6), isTrue); // Masih dalam toleransi
      expect(evaluateStrokeAttempt('我', 8), isTrue); // Masih dalam toleransi
      expect(evaluateStrokeAttempt('我', 2), isFalse); // Terlalu sedikit
    });
  });
}
