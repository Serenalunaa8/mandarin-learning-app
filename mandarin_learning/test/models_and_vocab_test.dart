import 'package:flutter_test/flutter_test.dart';
import 'package:nihaoki/models/vocabulary_model.dart';
import 'package:nihaoki/models/user_profile_model.dart';
import 'package:nihaoki/models/coin_transaction_model.dart';

void main() {
  group('PBI-002 & PBI-006: UserProfile Model & Coin Logic Tests', () {
    test('UserProfile deserialization and copyWith test', () {
      final json = {
        'id': 'user-123',
        'full_name': 'Serena Luna',
        'avatar_url': 'https://example.com/avatar.png',
        'current_hsk_level': 2,
        'streak': 5,
        'last_active_date': '2026-10-19',
        'coins': 150,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, 'user-123');
      expect(profile.fullName, 'Serena Luna');
      expect(profile.currentHskLevel, 2);
      expect(profile.streak, 5);
      expect(profile.coins, 150);

      // Test copyWith
      final updated = profile.copyWith(coins: 175, streak: 6);
      expect(updated.coins, 175);
      expect(updated.streak, 6);
      expect(updated.fullName, 'Serena Luna');
    });

    test('CoinTransaction model serialization', () {
      final tx = CoinTransaction(
        id: 'tx-001',
        userId: 'user-123',
        attemptId: 'attempt-999',
        amount: 15,
        transactionType: 'quiz_reward',
        description: 'Skor 95 pada Kuis HSK 1',
        createdAt: DateTime.now(),
      );

      final json = tx.toJson();
      expect(json['amount'], 15);
      expect(json['attempt_id'], 'attempt-999');
      expect(json['transaction_type'], 'quiz_reward');

      final fromJson = CoinTransaction.fromJson(json);
      expect(fromJson.amount, 15);
      expect(fromJson.attemptId, 'attempt-999');
    });
  });

  group('PBI-007 & PBI-012: VocabularyItem & ExampleSentence Tests', () {
    test('VocabularyItem parses correctly with tone marks and examples', () {
      final json = {
        'id': 1,
        'hanzi': '爱',
        'pinyin': 'ài',
        'arti_indonesia': 'mencintai; kasih sayang',
        'translations': ['mencintai', 'kasih sayang'],
        'hsk_level': 1,
        'jenis_kata': null,
        'contoh_kalimat': [
          {'hanzi': '我爱你', 'arti': 'Aku cinta kamu'},
        ],
        'sumber': 'HSK 2.0 Official Vocabulary',
      };

      final item = VocabularyItem.fromJson(json);
      expect(item.id, 1);
      expect(item.hanzi, '爱');
      expect(item.pinyin, 'ài');
      expect(item.hskLevel, 1);
      expect(item.translations.length, 2);
      expect(item.contohKalimat.length, 1);
      expect(item.contohKalimat.first.hanzi, '我爱你');
      expect(item.contohKalimat.first.arti, 'Aku cinta kamu');
    });

    test('VocabularyItem handles nulls gracefully', () {
      final json = {'id': 2, 'hanzi': '八', 'pinyin': 'bā'};

      final item = VocabularyItem.fromJson(json);
      expect(item.id, 2);
      expect(item.hanzi, '八');
      expect(item.pinyin, 'bā');
      expect(item.hskLevel, 1);
      expect(item.translations, isEmpty);
      expect(item.contohKalimat, isEmpty);
    });
  });
}
