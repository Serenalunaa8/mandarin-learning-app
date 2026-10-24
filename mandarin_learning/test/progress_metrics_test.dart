import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/models/quiz_attempt_model.dart';
import 'package:mandarin_learning/providers/vocabulary_provider.dart';
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

      await provider.recordQuizAttempt(
        _attempt(id: 'quiz-1', score: 80, correctAnswers: 2),
        correctVocabIds: {10, 11},
      );
      await provider.recordQuizAttempt(
        _attempt(id: 'quiz-2', score: 60, correctAnswers: 2),
        correctVocabIds: {11, 12},
      );

      expect(provider.totalQuizMasteredVocabulary, 3);
      expect(provider.totalQuizzesCompleted, 2);
      expect(provider.averageQuizScore, 70);

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getStringList('quiz_mastered_vocab_ids_guest_local_user'),
        containsAll(['10', '11', '12']),
      );

      final restoredProvider = VocabularyProvider();
      await restoredProvider.initialize('guest_local_user');
      expect(restoredProvider.totalQuizMasteredVocabulary, 3);
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
