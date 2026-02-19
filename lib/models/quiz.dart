class Quiz {
  final String quizId;
  final String subjectId;
  final String chapterCode;
  final String quizName;
  final String difficultyLevel;
  final int totalQuestions;
  final int timeLimit;
  final DateTime? createdAt;

  Quiz({
    required this.quizId,
    required this.subjectId,
    required this.chapterCode,
    required this.quizName,
    required this.difficultyLevel,
    required this.totalQuestions,
    required this.timeLimit,
    this.createdAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      quizId: json['quiz_id'] as String,
      subjectId: json['subject_id'] as String,
      chapterCode: json['chapter_code'] as String,
      quizName: json['quiz_name'] as String,
      difficultyLevel: json['difficulty_level'] as String,
      totalQuestions: json['total_questions'] as int,
      timeLimit: json['time_limit'] as int,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'subject_id': subjectId,
      'chapter_code': chapterCode,
      'quiz_name': quizName,
      'difficulty_level': difficultyLevel,
      'total_questions': totalQuestions,
      'time_limit': timeLimit,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}