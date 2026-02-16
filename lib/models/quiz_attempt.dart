class QuizAttempt {
  final String id;
  final String userId;
  final String quizId;
  final String subjectId;
  final String chapterCode;
  final int totalQuestions;
  final int attemptedQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int skippedQuestions;
  final int eOptionUsed;
  final int score;
  final double percentage;
  final int totalTimeSeconds;
  final DateTime? startedAt;
  final DateTime? completedAt;

  QuizAttempt({
    required this.id,
    required this.userId,
    required this.quizId,
    required this.subjectId,
    required this.chapterCode,
    required this.totalQuestions,
    required this.attemptedQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.skippedQuestions,
    required this.eOptionUsed,
    required this.score,
    required this.percentage,
    required this.totalTimeSeconds,
    this.startedAt,
    this.completedAt,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      quizId: json['quiz_id'] as String,
      subjectId: json['subject_id'] as String,
      chapterCode: json['chapter_code'] as String,
      totalQuestions: json['total_questions'] as int,
      attemptedQuestions: json['attempted_questions'] as int,
      correctAnswers: json['correct_answers'] as int,
      wrongAnswers: json['wrong_answers'] as int,
      skippedQuestions: json['skipped_questions'] as int,
      eOptionUsed: json['e_option_used'] as int,
      score: json['score'] as int,
      percentage: (json['percentage'] as num).toDouble(),
      totalTimeSeconds: json['total_time_seconds'] as int,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'quiz_id': quizId,
      'subject_id': subjectId,
      'chapter_code': chapterCode,
      'total_questions': totalQuestions,
      'attempted_questions': attemptedQuestions,
      'correct_answers': correctAnswers,
      'wrong_answers': wrongAnswers,
      'skipped_questions': skippedQuestions,
      'e_option_used': eOptionUsed,
      'score': score,
      'percentage': percentage,
      'total_time_seconds': totalTimeSeconds,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}