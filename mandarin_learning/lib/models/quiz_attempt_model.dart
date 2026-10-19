class QuizAttempt {
  final String id;
  final String userId;
  final int hskLevel;
  final String quizType;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final int coinsEarned;
  final DateTime createdAt;

  QuizAttempt({
    required this.id,
    required this.userId,
    required this.hskLevel,
    required this.quizType,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.coinsEarned,
    required this.createdAt,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: (json['attempt_id'] ?? json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      hskLevel: (json['hsk_level'] as num?)?.toInt() ?? 1,
      quizType: (json['quiz_type'] ?? 'tebak_arti').toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 10,
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_id': id,
    'user_id': userId,
    'hsk_level': hskLevel,
    'quiz_type': quizType,
    'score': score,
    'total_questions': totalQuestions,
    'correct_answers': correctAnswers,
    'coins_earned': coinsEarned,
    'created_at': createdAt.toIso8601String(),
  };
}
