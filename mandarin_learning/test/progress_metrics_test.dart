import 'package:flutter_test/flutter_test.dart';
import 'package:nihaoki/models/quiz_attempt_model.dart';
import 'package:nihaoki/providers/vocabulary_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'counts unique vocabulary answered correctly in completed quizzes',
    () async {
      final provider = VocabularyProvider();
      await provider.initialize('guest_local_user');

      await provider.recordQuizAttempt(
        _attempt(id: 'quiz-1', score: 80, correctAnswers: 2),
        correctVocabIds: {10, 11},
      );
      await provider.recordQuizAttempt(
        _attempt(id: 'quiz-2', score: 60, correctAnswers: 2),
        correctVocabIds: {11, 12},
      );
      await provider.markAsLearned(
        vocabId: 1,
        userId: 'guest_local_user',
        hskLevel: 1,
      );
      await provider.toggleFavorite(1);

      expect(provider.totalQuizMasteredVocabulary, 3);
      expect(provider.totalQuizzesCompleted, 2);
      expect(provider.averageQuizScore, 70);
      expect(provider.isLearned(1), isTrue);
      expect(provider.isFavorite(1), isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getStringList('quiz_mastered_vocab_ids_guest_local_user'),
        containsAll(['10', '11', '12']),
      );

      final restoredProvider = VocabularyProvider();
      await restoredProvider.initialize('guest_local_user');
      expect(restoredProvider.totalQuizMasteredVocabulary, 3);
      expect(restoredProvider.totalQuizzesCompleted, 2);
      expect(restoredProvider.averageQuizScore, 70);
      expect(restoredProvider.isLearned(1), isTrue);
      expect(restoredProvider.isFavorite(1), isTrue);
    },
  );
}

QuizAttempt _attempt({
  required String id,
  required int score,
  required int correctAnswers,
}) {
  return QuizAttempt(
    id: id,
    userId: 'guest_local_user',
    hskLevel: 1,
    quizType: 'test',
    score: score,
    totalQuestions: 10,
    correctAnswers: correctAnswers,
    coinsEarned: 0,
    createdAt: DateTime(2026, 10, 25),
  );
}
