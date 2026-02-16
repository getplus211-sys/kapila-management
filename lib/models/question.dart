class Question {
  final String id;
  final String quizId;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String? optionE;
  final String correctAnswer; // 'A', 'B', 'C', 'D', or 'E'
  final String? solution;
  final String? difficultyLevel;
  final String? chapterName;
  final DateTime? createdAt;

  Question({
    required this.id,
    required this.quizId,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    this.optionE,
    required this.correctAnswer,
    this.solution,
    this.difficultyLevel,
    this.chapterName,
    this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      quizId: json['quiz_id'] as String,
      question: json['question'] as String,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      optionC: json['option_c'] as String,
      optionD: json['option_d'] as String,
      optionE: json['option_e'] as String?,
      correctAnswer: json['correct_answer'] as String,
      solution: json['solution'] as String?,
      difficultyLevel: json['difficulty_level'] as String?,
      chapterName: json['chapter_name'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'question': question,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'option_e': optionE,
      'correct_answer': correctAnswer,
      'solution': solution,
      'difficulty_level': difficultyLevel,
      'chapter_name': chapterName,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Helper method to get correct option number (1-5)
  int? getCorrectOptionNumber() {
    switch (correctAnswer.toUpperCase()) {
      case 'A':
        return 1;
      case 'B':
        return 2;
      case 'C':
        return 3;
      case 'D':
        return 4;
      case 'E':
        return 5;
      default:
        return null;
    }
  }
}