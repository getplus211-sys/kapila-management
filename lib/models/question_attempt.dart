class QuestionAttempt {
  final String id;
  final String quizAttemptId;
  final String questionId;
  final String userId;
  final String quizId;
  final String selectedAnswer;
  final bool isCorrect;
  final int timeTakenSeconds;
  final int questionOrder;
  final String? difficultyLevel;
  final String? chapterName;

  QuestionAttempt({
    required this.id,
    required this.quizAttemptId,
    required this.questionId,
    required this.userId,
    required this.quizId,
    required this.selectedAnswer,
    required this.isCorrect,
    required this.timeTakenSeconds,
    required this.questionOrder,
    this.difficultyLevel,
    this.chapterName,
  });

  factory QuestionAttempt.fromJson(Map<String, dynamic> json) {
    return QuestionAttempt(
      id: json['id'] as String,
      quizAttemptId: json['quiz_attempt_id'] as String,
      questionId: json['question_id'] as String,
      userId: json['user_id'] as String,
      quizId: json['quiz_id'] as String,
      selectedAnswer: json['selected_answer'] as String,
      isCorrect: json['is_correct'] as bool,
      timeTakenSeconds: json['time_taken_seconds'] as int,
      questionOrder: json['question_order'] as int,
      difficultyLevel: json['difficulty_level'] as String?,
      chapterName: json['chapter_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_attempt_id': quizAttemptId,
      'question_id': questionId,
      'user_id': userId,
      'quiz_id': quizId,
      'selected_answer': selectedAnswer,
      'is_correct': isCorrect,
      'time_taken_seconds': timeTakenSeconds,
      'question_order': questionOrder,
      'difficulty_level': difficultyLevel,
      'chapter_name': chapterName,
    };
  }
}