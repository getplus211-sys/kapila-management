class Quiz {
  final String id;
  final String quizId;
  final String subjectId;
  final String chapterCode;
  final String quizName;
  final String? quizNameGujarati;
  final int timeLimit; // in minutes
  final String difficultyLevel;
  final bool isActive;
  final int? totalQuestions;
  final DateTime? createdAt;

  Quiz({
    required this.id,
    required this.quizId,
    required this.subjectId,
    required this.chapterCode,
    required this.quizName,
    this.quizNameGujarati,
    required this.timeLimit,
    required this.difficultyLevel,
    required this.isActive,
    this.totalQuestions,
    this.createdAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      quizId: json['quiz_id'] as String,
      subjectId: json['subject_id'] as String,
      chapterCode: json['chapter_code'] as String,
      quizName: json['quiz_name'] as String,
      quizNameGujarati: json['quiz_name_gujarati'] as String?,
      timeLimit: json['time_limit'] as int,
      difficultyLevel: json['difficulty_level'] as String,
      isActive: json['is_active'] as bool,
      totalQuestions: json['total_questions'] as int?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'subject_id': subjectId,
      'chapter_code': chapterCode,
      'quiz_name': quizName,
      'quiz_name_gujarati': quizNameGujarati,
      'time_limit': timeLimit,
      'difficulty_level': difficultyLevel,
      'is_active': isActive,
      'total_questions': totalQuestions,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}