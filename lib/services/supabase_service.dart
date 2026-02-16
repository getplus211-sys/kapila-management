import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://bhmycvrbucmbbrpzeane.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXljdnJidWNtYmJycHplYW5lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2OTQwOTYsImV4cCI6MjA4MDI3MDA5Nn0.qQ3bw9cADG0P8hbGwx76Oeg54l-9FbRWxc92nZdSPL4';

  static SupabaseClient get client => Supabase.instance.client;

  // Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Get current user
  static User? get currentUser => client.auth.currentUser;

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    
    final response = await client
        .from('profiles')
        .select('*')
        .eq('id', currentUser!.id)
        .single();
    
    return response;
  }

  // Get all subjects
  static Future<List<Map<String, dynamic>>> getSubjects() async {
    final response = await client
        .from('kls_subjects')
        .select('*')
        .order('created_at');
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Get chapters by subject
  static Future<List<Map<String, dynamic>>> getChaptersBySubject(String subjectId) async {
    final response = await client
        .from('kls_chapters')
        .select('*')
        .eq('subject_id', subjectId)
        .order('chapter_code');
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Get quizzes by chapter
  static Future<List<Map<String, dynamic>>> getQuizzesByChapter(String chapterCode) async {
    final response = await client
        .from('kls_quizzes')
        .select('*')
        .eq('chapter_code', chapterCode)
        .eq('is_active', true)
        .order('difficulty_level');
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Get quiz by ID
  static Future<Map<String, dynamic>?> getQuizById(String quizId) async {
    final response = await client
        .from('kls_quizzes')
        .select('*')
        .eq('quiz_id', quizId)
        .single();
    
    return response;
  }

  // Get questions by quiz
  static Future<List<Map<String, dynamic>>> getQuestionsByQuiz(String quizId) async {
    final response = await client
        .from('kls_questions')
        .select('*')
        .eq('quiz_id', quizId);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Check if user has attempted quiz
  static Future<Map<String, dynamic>?> getQuizAttempt(String quizId) async {
    if (currentUser == null) return null;
    
    final response = await client
        .from('kls_quiz_attempts')
        .select('*')
        .eq('user_id', currentUser!.id)
        .eq('quiz_id', quizId)
        .maybeSingle();
    
    return response;
  }

  // Save quiz attempt
  static Future<Map<String, dynamic>> saveQuizAttempt({
    required String quizId,
    required String subjectId,
    required String chapterCode,
    required int totalQuestions,
    required int attemptedQuestions,
    required int correctAnswers,
    required int wrongAnswers,
    required int skippedQuestions,
    required int eOptionUsed,
    required int score,
    required double percentage,
    required int totalTimeSeconds,
    required DateTime startedAt,
    required DateTime completedAt,
  }) async {
    final response = await client
        .from('kls_quiz_attempts')
        .insert({
          'user_id': currentUser!.id,
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
          'started_at': startedAt.toIso8601String(),
          'completed_at': completedAt.toIso8601String(),
        })
        .select()
        .single();
    
    return response;
  }

  // Save question attempt
  static Future<void> saveQuestionAttempt({
    required String quizAttemptId,
    required String questionId,
    required String quizId,
    required String selectedAnswer,
    required bool isCorrect,
    required int timeTakenSeconds,
    required int questionOrder,
  }) async {
    await client.from('kls_question_attempts').insert({
      'quiz_attempt_id': quizAttemptId,
      'question_id': questionId,
      'user_id': currentUser!.id,
      'quiz_id': quizId,
      'selected_answer': selectedAnswer,
      'is_correct': isCorrect,
      'time_taken_seconds': timeTakenSeconds,
      'question_order': questionOrder,
    });
  }

  // Delete quiz attempt (for retake)
  static Future<void> deleteQuizAttempt(String attemptId) async {
    // Delete question attempts first
    await client
        .from('kls_question_attempts')
        .delete()
        .eq('quiz_attempt_id', attemptId);
    
    // Delete quiz attempt
    await client
        .from('kls_quiz_attempts')
        .delete()
        .eq('id', attemptId);
  }

  // Get leaderboard
  static Future<List<Map<String, dynamic>>> getLeaderboard(String quizId) async {
    final response = await client
        .from('kls_quiz_attempts')
        .select('user_id, score, total_time_seconds, correct_answers, total_questions, percentage')
        .eq('quiz_id', quizId)
        .order('score', ascending: false)
        .order('total_time_seconds', ascending: true)
        .limit(50);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Get question attempts with questions
  static Future<List<Map<String, dynamic>>> getQuestionAttemptsWithQuestions(String attemptId) async {
    final response = await client
        .from('kls_question_attempts')
        .select('*, kls_questions(*)')
        .eq('quiz_attempt_id', attemptId);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== PERFORMANCE SCREEN METHODS ====================

  // Get quiz attempt by ID (for performance screen)
  static Future<Map<String, dynamic>?> getQuizAttemptById(String attemptId) async {
    try {
      final response = await client
          .from('kls_quiz_attempts')
          .select('*')
          .eq('id', attemptId)
          .single();
      
      return response;
    } catch (e) {
      print('Get quiz attempt by ID error: $e');
      return null;
    }
  }

  // Get all quiz attempts for a quiz (for ranking)
  static Future<List<Map<String, dynamic>>?> getAllQuizAttempts(String quizId) async {
    try {
      final response = await client
          .from('kls_quiz_attempts')
          .select('user_id, score, total_time_seconds')
          .eq('quiz_id', quizId)
          .order('score', ascending: false)
          .order('total_time_seconds', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Get all quiz attempts error: $e');
      return null;
    }
  }

  // Get previous attempts by chapter for trend graph
  static Future<List<Map<String, dynamic>>?> getPreviousAttemptsByChapter(
    String chapterCode, {
    int limit = 5,
  }) async {
    try {
      if (currentUser == null) return null;
      
      final response = await client
          .from('kls_quiz_attempts')
          .select('score, percentage, completed_at')
          .eq('user_id', currentUser!.id)
          .eq('chapter_code', chapterCode)
          .order('completed_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Get previous attempts error: $e');
      return null;
    }
  }

  // Get question attempts with difficulty levels (for performance analysis)
  static Future<List<Map<String, dynamic>>?> getQuestionAttemptsByQuizAttempt(String quizAttemptId) async {
    try {
      final response = await client
          .from('kls_question_attempts')
          .select('''
            *,
            kls_questions (
              difficulty_level,
              chapter_name
            )
          ''')
          .eq('quiz_attempt_id', quizAttemptId);
      
      // Flatten the nested structure
      final flattened = (response as List).map((item) {
        final questionData = item['kls_questions'];
        return {
          ...item,
          'difficulty_level': questionData?['difficulty_level'],
          'chapter_name': questionData?['chapter_name'],
        };
      }).toList();
      
      return List<Map<String, dynamic>>.from(flattened);
    } catch (e) {
      print('Get question attempts with difficulty error: $e');
      return null;
    }
  }
}