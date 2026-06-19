import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/backend_config.dart';

class SupabaseService {
  static const String supabaseUrl = BackendConfig.supabaseUrl;
  static const String supabaseAnonKey = BackendConfig.supabaseAnonKey;

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
  static final Map<String, _CacheEntry<dynamic>> _cache =
      <String, _CacheEntry<dynamic>>{};
  static final Map<String, Future<dynamic>> _inflight =
      <String, Future<dynamic>>{};

  static Future<T> _cached<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() loader,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache[key];
      if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
        return cached.value as T;
      }
    }

    final pending = _inflight[key];
    if (!forceRefresh && pending != null) {
      return await pending as T;
    }

    final future = loader();
    _inflight[key] = future;
    try {
      final value = await future;
      _cache[key] = _CacheEntry<dynamic>(
        value: value,
        expiresAt: DateTime.now().add(ttl),
      );
      return value;
    } finally {
      _inflight.remove(key);
    }
  }

  static void _invalidateByPrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
    _inflight.removeWhere((key, _) => key.startsWith(prefix));
  }

  static void clearInMemoryCache() {
    _cache.clear();
    _inflight.clear();
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;

    return _cached<Map<String, dynamic>?>(
      key: 'profile:${currentUser!.id}',
      ttl: const Duration(minutes: 2),
      loader: () async {
        final response = await client
            .from('profiles')
            .select('*')
            .eq('id', currentUser!.id)
            .single();
        return Map<String, dynamic>.from(response);
      },
    );
  }

  // Get all subjects
  static Future<List<Map<String, dynamic>>> getSubjects() async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'subjects:all',
      ttl: const Duration(minutes: 20),
      loader: () async {
        final response = await client
            .from('kls_subjects')
            .select('*')
            .order('created_at');
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  // Get chapters by subject
  static Future<List<Map<String, dynamic>>> getChaptersBySubject(String subjectId) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'chapters:$subjectId',
      ttl: const Duration(minutes: 20),
      loader: () async {
        final response = await client
            .from('kls_chapters')
            .select('*')
            .eq('subject_id', subjectId)
            .order('chapter_code');
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  // Get quizzes by chapter
  static Future<List<Map<String, dynamic>>> getQuizzesByChapter(String chapterCode) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'quizzesByChapter:$chapterCode',
      ttl: const Duration(minutes: 5),
      loader: () async {
        final response = await client
            .from('kls_quizzes')
            .select('*')
            .eq('chapter_code', chapterCode)
            .eq('is_active', true)
            .order('quiz_id');
        final rows = List<Map<String, dynamic>>.from(response);

        // Enforce deterministic part-wise ordering for *_PART_N style quiz ids.
        // This prevents random-looking card order when old/extra quizzes exist.
        int partNo(Map<String, dynamic> q) {
          final id = q['quiz_id']?.toString() ?? '';
          final m = RegExp(r'_PART_(\d+)$', caseSensitive: false).firstMatch(id);
          if (m == null) return 9999;
          return int.tryParse(m.group(1) ?? '') ?? 9999;
        }

        int levelRank(Map<String, dynamic> q) {
          final lvl = (q['difficulty_level']?.toString() ?? '').trim();
          if (lvl == 'સરળ') return 1;
          if (lvl == 'મધ્યમ') return 2;
          if (lvl == 'મુશ્કેલ') return 3;
          return 9;
        }

        rows.sort((a, b) {
          final pa = partNo(a);
          final pb = partNo(b);
          if (pa != pb) return pa.compareTo(pb);

          final la = levelRank(a);
          final lb = levelRank(b);
          if (la != lb) return la.compareTo(lb);

          final qa = a['quiz_id']?.toString() ?? '';
          final qb = b['quiz_id']?.toString() ?? '';
          return qa.compareTo(qb);
        });

        return rows;
      },
    );
  }

  // Get theory parts by chapter
  static Future<List<Map<String, dynamic>>> getTheoryPartsByChapter(
    String chapterCode, {
    bool forceRefresh = false,
  }) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'theoryByChapter:$chapterCode',
      ttl: const Duration(minutes: 5),
      forceRefresh: forceRefresh,
      loader: () async {
        final response = await client
            .from('kls_chapter_theory')
            .select('*')
            .eq('chapter_code', chapterCode)
            .eq('is_active', true)
            .order('part_number')
            .order('created_at');
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  // Get quiz by ID
  static Future<Map<String, dynamic>?> getQuizById(String quizId) async {
    return _cached<Map<String, dynamic>?>(
      key: 'quiz:$quizId',
      ttl: const Duration(minutes: 5),
      loader: () async {
        try {
          final response = await client
              .from('kls_quizzes')
              .select('*')
              .eq('quiz_id', quizId)
              .maybeSingle();
          if (response == null) return null;
          return Map<String, dynamic>.from(response);
        } catch (e) {
          return null;
        }
      },
    );
  }

  // Get questions by quiz
  static Future<List<Map<String, dynamic>>> getQuestionsByQuiz(
    String quizId, {
    bool forceRefresh = false,
  }) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'questions:$quizId',
      ttl: const Duration(minutes: 10),
      forceRefresh: forceRefresh,
      loader: () async {
        final response = await client
            .from('kls_questions')
            .select('*')
            .eq('quiz_id', quizId)
            .order('created_at')
            .order('id');
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getActiveQuizzes({
    bool forceRefresh = false,
  }) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'dailyQuiz:activeQuizzes',
      ttl: const Duration(minutes: 5),
      forceRefresh: forceRefresh,
      loader: () async {
        final response = await client
            .from('kls_quizzes')
            .select('quiz_id, quiz_name, subject_id, chapter_code, difficulty_level, total_questions, time_limit, created_at, is_active')
            .eq('is_active', true)
            .order('created_at', ascending: false);
        final rows = List<Map<String, dynamic>>.from(response);
        rows.removeWhere((row) {
          final quizId = row['quiz_id']?.toString() ?? '';
          return quizId.startsWith('DAILY_');
        });
        return rows;
      },
    );
  }

  static Future<bool> isAdmin() async {
    try {
      final res = await client.rpc('kls_is_admin');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static String dailyQuizIdForDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return 'DAILY_${y}${m}${d}';
  }

  static Future<Map<String, dynamic>?> getDailyQuizForDate(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    final quizId = dailyQuizIdForDate(date);
    final quiz = await getQuizById(quizId);
    if (quiz == null) return null;
    if (quiz['is_active'] != true) return null;
    return quiz;
  }

  static Future<String> publishDailyQuiz({
    required String sourceQuizId,
    required String quizName,
    required List<String> questionIds,
    int timeLimit = 15,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }
    if (!await isAdmin()) {
      throw Exception('ADMIN_REQUIRED');
    }

    final sourceQuiz = await client
        .from('kls_quizzes')
        .select('quiz_id, quiz_name, subject_id, chapter_code, difficulty_level')
        .eq('quiz_id', sourceQuizId)
        .single();

    final quizId = dailyQuizIdForDate(DateTime.now());
    final sourceQuizIdValue = sourceQuiz['quiz_id']?.toString() ?? sourceQuizId;

    await client
        .from('kls_questions')
        .delete()
        .eq('quiz_id', quizId);
    await client
        .from('kls_quizzes')
        .delete()
        .eq('quiz_id', quizId);
    await client
        .from('kls_daily_quiz_questions')
        .delete()
        .eq('quiz_id', quizId);
    await client
        .from('kls_daily_quiz_settings')
        .delete()
        .eq('quiz_id', quizId);

    await client.from('kls_quizzes').insert({
      'quiz_id': quizId,
      'quiz_name': quizName.trim().isEmpty ? 'Daily Learning' : quizName.trim(),
      'subject_id': sourceQuiz['subject_id'],
      'chapter_code': sourceQuiz['chapter_code'],
      'difficulty_level': sourceQuiz['difficulty_level'],
      'total_questions': questionIds.length,
      'time_limit': timeLimit,
      'is_active': true,
    });

    await client.from('kls_daily_quiz_settings').insert({
      'quiz_id': quizId,
      'quiz_name': quizName.trim().isEmpty ? 'Daily Learning' : quizName.trim(),
      'source_quiz_id': sourceQuizIdValue,
      'subject_id': sourceQuiz['subject_id'],
      'chapter_code': sourceQuiz['chapter_code'],
      'difficulty_level': sourceQuiz['difficulty_level'],
      'total_questions': questionIds.length,
      'time_limit': timeLimit,
      'is_enabled': true,
      'created_by': user.id,
      'updated_by': user.id,
    });

    if (questionIds.isEmpty) {
      return quizId;
    }

    final rows = await client
        .from('kls_questions')
        .select(
          'id, question, option_a, option_b, option_c, option_d, option_e, correct_answer, solution, suggestion, difficulty_level, chapter_code, subject_id',
        )
        .inFilter('id', questionIds);
    final sourceRows = List<Map<String, dynamic>>.from(rows);
    final orderMap = {
      for (var i = 0; i < questionIds.length; i++) questionIds[i]: i,
    };

    sourceRows.sort((a, b) {
      final ai = orderMap[a['id']?.toString() ?? ''] ?? 0;
      final bi = orderMap[b['id']?.toString() ?? ''] ?? 0;
      return ai.compareTo(bi);
    });

    final inserts = <Map<String, dynamic>>[];
    for (final row in sourceRows) {
      inserts.add({
        'quiz_id': quizId,
        'question': row['question'],
        'option_a': row['option_a'],
        'option_b': row['option_b'],
        'option_c': row['option_c'],
        'option_d': row['option_d'],
        'option_e': row['option_e'],
        'correct_answer': row['correct_answer'],
        'solution': row['solution'],
        'suggestion': row['suggestion'],
        'difficulty_level': row['difficulty_level'] ?? sourceQuiz['difficulty_level'],
        'chapter_code': row['chapter_code'] ?? sourceQuiz['chapter_code'],
        'subject_id': row['subject_id'] ?? sourceQuiz['subject_id'],
      });
    }

    await client.from('kls_questions').insert(inserts);
    await client.from('kls_daily_quiz_questions').insert([
      for (var i = 0; i < questionIds.length; i++)
        {
          'quiz_id': quizId,
          'question_id': questionIds[i],
          'display_order': i + 1,
        },
    ]);
    _invalidateByPrefix('questions:$quizId');
    _invalidateByPrefix('quiz:$quizId');
    _invalidateByPrefix('dailyQuiz:activeQuizzes');
    return quizId;
  }

  static Future<void> addQuestionToQuiz({
    required String quizId,
    required String question,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    String optionE = '',
    required String correctAnswer,
    required String solution,
    String difficultyLevel = 'સરળ',
    String chapterCode = '',
    String subjectId = '',
    String suggestion = '',
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }
    if (!await isAdmin()) {
      throw Exception('ADMIN_REQUIRED');
    }

    final payload = <String, dynamic>{
      'quiz_id': quizId,
      'question': question.trim(),
      'option_a': optionA.trim(),
      'option_b': optionB.trim(),
      'option_c': optionC.trim(),
      'option_d': optionD.trim(),
      'option_e': optionE.trim(),
      'correct_answer': correctAnswer.trim().toUpperCase(),
      'solution': solution.trim(),
      'suggestion': suggestion.trim(),
      'difficulty_level': difficultyLevel.trim().isEmpty ? 'સરળ' : difficultyLevel.trim(),
      'chapter_code': chapterCode.trim(),
      'subject_id': subjectId.trim(),
    };

    await client.from('kls_questions').insert(payload);
    await client
        .from('kls_quizzes')
        .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('quiz_id', quizId);
    _invalidateByPrefix('questions:$quizId');
    _invalidateByPrefix('quiz:$quizId');
  }

  // ==================== EXAM-WISE MOCK TEST METHODS ====================

  static Future<List<Map<String, dynamic>>> getMockExams() async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'mockExams:active',
      ttl: const Duration(minutes: 5),
      loader: () async {
        final response = await client
            .from('kls_exams')
            .select('*')
            .eq('is_active', true)
            .order('sort_order')
            .order('exam_name');
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getTestSeriesByExam(
    String examCode,
  ) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'testSeries:$examCode',
      ttl: const Duration(minutes: 3),
      loader: () async {
        final response = await client
            .from('kls_test_series')
            .select('*')
            .eq('exam_code', examCode)
            .eq('is_active', true)
            .eq('is_visible', true)
            .order('created_at');
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getPurchasedSeriesByExam(
    String examCode,
  ) async {
    final uid = currentUser?.id;
    if (uid == null) return <Map<String, dynamic>>[];

    return _cached<List<Map<String, dynamic>>>(
      key: 'purchasedSeries:$uid:$examCode',
      ttl: const Duration(seconds: 20),
      loader: () async {
        final rows = await client
            .from('kls_user_series_access')
            .select('access_status, grace_until, kls_test_series(*)')
            .eq('user_id', uid)
            .inFilter('access_status', ['active', 'expired']);

        final now = DateTime.now().toUtc();
        final out = <Map<String, dynamic>>[];
        for (final item in List<Map<String, dynamic>>.from(rows)) {
          final ts = item['kls_test_series'];
          if (ts is! Map) continue;
          final series = Map<String, dynamic>.from(ts);
          if (series['exam_code']?.toString() != examCode) continue;
          final grace = item['grace_until']?.toString();
          final graceOk = grace == null ||
              grace.isEmpty ||
              (DateTime.tryParse(grace)?.toUtc().isAfter(now) ?? false);
          if (!graceOk && item['access_status']?.toString() != 'active') continue;
          out.add(series);
        }
        return out;
      },
    );
  }

  static Future<Map<String, bool>> getUserSeriesAccessMap(
    List<String> seriesIds,
  ) async {
    final uid = currentUser?.id;
    if (uid == null || seriesIds.isEmpty) return <String, bool>{};

    final cacheKey = 'userSeriesAccess:$uid:${seriesIds.join(",")}';
    return _cached<Map<String, bool>>(
      key: cacheKey,
      ttl: const Duration(seconds: 20),
      loader: () async {
        final response = await client
            .from('kls_user_series_access')
            .select('test_series_id, access_status, access_end_at')
            .eq('user_id', uid)
            .inFilter('test_series_id', seriesIds);

        final now = DateTime.now().toUtc();
        final map = <String, bool>{};
        for (final row in List<Map<String, dynamic>>.from(response)) {
          final seriesId = row['test_series_id']?.toString();
          if (seriesId == null || seriesId.isEmpty) continue;

          final status = row['access_status']?.toString() ?? '';
          final endAtRaw = row['access_end_at']?.toString();
          final hasNotExpired = endAtRaw == null ||
              endAtRaw.isEmpty ||
              DateTime.tryParse(endAtRaw)?.toUtc().isAfter(now) == true;

          map[seriesId] = status == 'active' && hasNotExpired;
        }
        return map;
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getMocksBySeries(
    String testSeriesId,
  ) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'seriesMocks:$testSeriesId',
      ttl: const Duration(seconds: 30),
      loader: () async {
        final rows = await client
            .from('kls_test_series_mocks')
            .select('display_order, mock_test_id')
            .eq('test_series_id', testSeriesId)
            .order('display_order');

        final mapRows = List<Map<String, dynamic>>.from(rows);
        if (mapRows.isEmpty) return <Map<String, dynamic>>[];

        final orderedIds = mapRows
            .map((r) => r['mock_test_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList();
        if (orderedIds.isEmpty) return <Map<String, dynamic>>[];

        final mockRows = await client
            .from('kls_mock_tests')
            .select('*')
            .inFilter('mock_test_id', orderedIds);

        final byId = <String, Map<String, dynamic>>{};
        for (final m in List<Map<String, dynamic>>.from(mockRows)) {
          final id = m['mock_test_id']?.toString();
          if (id == null || id.isEmpty) continue;
          byId[id] = m;
        }

        final out = <Map<String, dynamic>>[];
        for (final mapRow in mapRows) {
          final id = mapRow['mock_test_id']?.toString() ?? '';
          final mock = byId[id];
          if (mock == null) continue;
          out.add({
            ...mock,
            'display_order': mapRow['display_order'],
          });
        }
        return out;
      },
    );
  }

  static Future<void> enrollInSeries(String testSeriesId) async {
    final uid = currentUser?.id;
    if (uid == null || testSeriesId.trim().isEmpty) {
      throw Exception('AUTH_REQUIRED');
    }

    final existing = await client
        .from('kls_user_series_access')
        .select('user_series_access_id, access_status')
        .eq('user_id', uid)
        .eq('test_series_id', testSeriesId)
        .maybeSingle();

    if (existing != null) {
      return;
    }

    await client.from('kls_user_series_access').insert({
      'user_id': uid,
      'test_series_id': testSeriesId,
      'access_status': 'active',
      'source': 'subscription',
      'purchased_at': DateTime.now().toUtc().toIso8601String(),
      'access_start_at': DateTime.now().toUtc().toIso8601String(),
      'granted_reason': 'self_enroll_from_subscription',
    });
  }

  static Future<Map<String, int>> getSeriesEnrollmentCounts(List<String> seriesIds) async {
    if (seriesIds.isEmpty) return <String, int>{};

    final response = await client.rpc(
      'kls_get_series_enrollment_counts',
      params: {'p_series_ids': seriesIds},
    );

    final rows = List<Map<String, dynamic>>.from(response as List);
    final out = <String, int>{};
    for (final row in rows) {
      final sid = row['test_series_id']?.toString();
      if (sid == null || sid.isEmpty) continue;
      out[sid] = (row['enrolled_count'] as num?)?.toInt() ?? 0;
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> getMockQuestionsByMockTest(
    String mockTestId,
  ) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'mockQuestions:$mockTestId',
      ttl: const Duration(seconds: 30),
      loader: () async {
        final response = await client
            .from('kls_mock_questions')
            .select('*')
            .eq('mock_test_id', mockTestId)
            .order('question_order');
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  static Future<Map<String, dynamic>> startMockAttempt(String mockTestId) async {
    final response = await client.rpc(
      'kls_start_mock_attempt',
      params: {'p_mock_test_id': mockTestId},
    );

    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Failed to start mock attempt');
  }

  static Future<Map<String, dynamic>?> getLatestMockAttemptForUser(String mockTestId) async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    final row = await client
        .from('kls_mock_attempts')
        .select(
            'mock_attempt_id,mock_test_id,status,engine_type,negative_mark,positive_mark,total_questions,started_at,submitted_at,score,percentage,correct_answers,wrong_answers,skipped_questions,attempted_questions,total_time_seconds')
        .eq('user_id', uid)
        .eq('mock_test_id', mockTestId)
        .inFilter('status', ['in_progress', 'submitted', 'auto_submitted'])
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  static Future<Map<String, dynamic>> submitMockAttempt({
    required String mockAttemptId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final response = await client.rpc(
      'kls_submit_mock_attempt',
      params: {
        'p_mock_attempt_id': mockAttemptId,
        'p_answers': answers,
      },
    );

    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Failed to submit mock attempt');
  }

  static Future<List<Map<String, dynamic>>> getMockAttemptSolutions(
    String mockAttemptId,
  ) async {
    final rows = await client
        .from('kls_mock_attempt_answers')
        .select('''
          answer_id,
          selected_answer,
          is_correct,
          is_skipped,
          time_taken_seconds,
          question_order,
          kls_mock_questions(
            mock_question_id,
            subject_id,
            subject_name,
            chapter_code,
            chapter_name,
            question_text,
            option_a,
            option_b,
            option_c,
            option_d,
            option_e,
            correct_answer,
            explanation
          )
        ''')
        .eq('mock_attempt_id', mockAttemptId)
        .order('question_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> getMockLeaderboard(
    String mockTestId,
  ) async {
    final rows = await client
        .from('kls_mock_attempts')
        .select('user_id, score, total_questions, total_time_seconds, submitted_at')
        .eq('mock_test_id', mockTestId)
        .inFilter('status', ['submitted', 'auto_submitted'])
        .order('score', ascending: false)
        .order('total_time_seconds', ascending: true)
        .order('submitted_at', ascending: true)
        .limit(100);

    final out = List<Map<String, dynamic>>.from(rows);
    for (var i = 0; i < out.length; i++) {
      final uid = out[i]['user_id']?.toString();
      if (uid == null || uid.isEmpty) {
        out[i]['name'] = 'User';
        continue;
      }
      try {
        final profile = await client
            .from('ngm_users')
            .select('full_name')
            .eq('user_id', uid)
            .maybeSingle();
        out[i]['name'] = profile?['full_name']?.toString() ?? 'User';
      } catch (_) {
        out[i]['name'] = 'User';
      }
    }
    return out;
  }

  static Future<bool> userHasMockAccess(String mockTestId) async {
    final uid = currentUser?.id;
    if (uid == null) return false;
    final response = await client.rpc('kls_user_has_mock_access', params: {
      'p_mock_test_id': mockTestId,
      'p_user_id': uid,
    });
    return response == true;
  }

  static Future<bool> hasPaidQuizEngineAccess() async {
    final uid = currentUser?.id;
    if (uid == null) return false;

    final response = await client
        .from('kls_user_entitlements')
        .select('is_quiz_engine_paid, paid_until')
        .eq('user_id', uid)
        .maybeSingle();

    if (response == null) return false;

    final isPaid = response['is_quiz_engine_paid'] == true;
    if (!isPaid) return false;

    final paidUntilRaw = response['paid_until']?.toString();
    if (paidUntilRaw == null || paidUntilRaw.isEmpty) return true;

    final paidUntil = DateTime.tryParse(paidUntilRaw)?.toUtc();
    if (paidUntil == null) return false;
    return paidUntil.isAfter(DateTime.now().toUtc());
  }

  static Future<bool> hasActiveSubscription() async {
    final uid = currentUser?.id;
    if (uid == null) return false;
    try {
      final response = await client.rpc(
        'kls_is_user_subscription_active',
        params: {'p_user_id': uid},
      );
      return response == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getActiveSubscriptionDetail() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await client
          .from('kls_user_subscriptions')
          .select('user_subscription_id,starts_at,ends_at,status,subscription_plan_id')
          .eq('user_id', uid)
          .eq('status', 'active')
          .gt('ends_at', DateTime.now().toUtc().toIso8601String())
          .order('ends_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    final rows = await client
        .from('kls_subscription_plans')
        .select('*')
        .eq('is_active', true)
        .order('price');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> getMyPurchases() async {
    final uid = currentUser?.id;
    if (uid == null) return <Map<String, dynamic>>[];

    final rows = await client
        .from('kls_v_my_purchases')
        .select('*')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows).where((row) {
      final status = (row['payment_status']?.toString() ?? '').toLowerCase();
      return status == 'paid';
    }).toList();
  }

  static Future<Map<String, dynamic>?> getAffiliateProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final row = await client
        .from('kls_affiliate_profiles')
        .select('*')
        .eq('user_id', uid)
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  static Future<Map<String, dynamic>?> getAffiliateApplication() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final row = await client
        .from('kls_affiliate_applications')
        .select('*')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  static Future<Map<String, dynamic>> validateAffiliateCode(String code) async {
    final rows = await client.rpc(
      'kls_validate_affiliate_code',
      params: {'p_code': code},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) {
      return {
        'is_valid': false,
        'normalized_code': null,
        'message': 'UNKNOWN',
      };
    }
    return list.first;
  }

  static Future<void> applyAffiliate({
    required String fullName,
    required String phone,
    required String email,
    required String district,
    String? telegramUrl,
    String? instagramUrl,
    String? youtubeUrl,
    String? facebookUrl,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) throw Exception('User not logged in');

    await client.from('kls_affiliate_applications').upsert({
      'user_id': uid,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'district': district,
      'telegram_url': telegramUrl,
      'instagram_url': instagramUrl,
      'youtube_url': youtubeUrl,
      'facebook_url': facebookUrl,
      'status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>> getAffiliateDashboardSummary() async {
    final uid = currentUser?.id;
    if (uid == null) throw Exception('User not logged in');
    final data = await client.rpc(
      'kls_get_affiliate_dashboard_summary',
      params: {'p_user_id': uid},
    );
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{'has_affiliate': false};
  }

  static Future<Map<String, dynamic>> createSeriesPaymentTransaction({
    required String testSeriesId,
    required double amount,
    String currencyCode = 'INR',
    String provider = 'razorpay',
    String? gatewayOrderId,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) throw Exception('User not logged in');

    final generatedOrderId =
        gatewayOrderId ?? 'APP_${DateTime.now().millisecondsSinceEpoch}_$uid';

    final response = await client
        .from('kls_payment_transactions')
        .insert({
          'user_id': uid,
          'test_series_id': testSeriesId,
          'provider': provider,
          'gateway_order_id': generatedOrderId,
          'amount': amount,
          'currency_code': currencyCode.toUpperCase(),
          'status': 'created',
          'metadata': metadata ?? const <String, dynamic>{},
        })
        .select()
        .single();

    _invalidateByPrefix('payments:$uid');
    return Map<String, dynamic>.from(response);
  }

  static Future<void> finalizeSeriesPaymentSuccess({
    required String paymentTxnId,
    required String gatewayPaymentId,
    String? gatewaySignature,
  }) async {
    await client.rpc(
      'kls_finalize_series_payment',
      params: {
        'p_payment_txn_id': paymentTxnId,
        'p_gateway_payment_id': gatewayPaymentId,
        'p_gateway_signature': gatewaySignature,
      },
    );

    final uid = currentUser?.id;
    if (uid != null) {
      _invalidateByPrefix('userSeriesAccess:$uid:');
      _invalidateByPrefix('payments:$uid');
    }
  }

  static Future<Map<String, dynamic>> createRazorpayOrderForSeries({
    required String testSeriesId,
    String? affiliateCode,
  }) async {
    final response = await client.functions.invoke(
      'kls-create-razorpay-order',
      body: {
        'product_type': 'test_series',
        'test_series_id': testSeriesId,
        'affiliate_code': affiliateCode,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Invalid response from create order function');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<void> verifyRazorpayPaymentForSeries({
    required String paymentTxnId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await client.functions.invoke(
      'kls-verify-razorpay-payment',
      body: {
        'payment_txn_id': paymentTxnId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Invalid response from verify payment function');
    }
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Payment verify failed');
    }

    final uid = currentUser?.id;
    if (uid != null) {
      _invalidateByPrefix('userSeriesAccess:$uid:');
      _invalidateByPrefix('payments:$uid');
    }
  }

  static Future<Map<String, dynamic>> createRazorpayOrderForSubscription({
    required String subscriptionPlanId,
    String? affiliateCode,
  }) async {
    final response = await client.functions.invoke(
      'kls-create-razorpay-order',
      body: {
        'product_type': 'subscription',
        'subscription_plan_id': subscriptionPlanId,
        'affiliate_code': affiliateCode,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Invalid response from create order function');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<void> verifyRazorpayPaymentForSubscription({
    required String paymentTxnId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await client.functions.invoke(
      'kls-verify-razorpay-payment',
      body: {
        'payment_txn_id': paymentTxnId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Invalid response from verify payment function');
    }
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Payment verify failed');
    }

    final uid = currentUser?.id;
    if (uid != null) {
      _invalidateByPrefix('payments:$uid');
      _invalidateByPrefix('subscriptionPlans:');
    }
  }

  // Check if user has attempted quiz
  static Future<Map<String, dynamic>?> getQuizAttempt(String quizId) async {
    if (currentUser == null) return null;

    return _cached<Map<String, dynamic>?>(
      key: 'quizAttempt:${currentUser!.id}:$quizId',
      ttl: const Duration(seconds: 20),
      loader: () async {
        final response = await client
            .from('kls_quiz_attempts')
            .select('*')
            .eq('user_id', currentUser!.id)
            .eq('quiz_id', quizId)
            .maybeSingle();
        return response == null ? null : Map<String, dynamic>.from(response);
      },
    );
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
    final uid = currentUser?.id;
    if (uid == null) {
      throw Exception('User not logged in');
    }
    final response = await client
        .from('kls_quiz_attempts')
        .insert({
          'user_id': uid,
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

    _invalidateByPrefix('quizAttempt:$uid:');
    _invalidateByPrefix('attemptById:');
    _invalidateByPrefix('allAttempts:$quizId');
    _invalidateByPrefix('leaderboard:$quizId');
    _invalidateByPrefix('previousByChapter:$uid:');
    _invalidateByPrefix('previousOverall:$uid:');
    return Map<String, dynamic>.from(response);
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
    final uid = currentUser?.id;
    if (uid == null) {
      throw Exception('User not logged in');
    }
    await client.from('kls_question_attempts').insert({
      'quiz_attempt_id': quizAttemptId,
      'question_id': questionId,
      'user_id': uid,
      'quiz_id': quizId,
      'selected_answer': selectedAnswer,
      'is_correct': isCorrect,
      'time_taken_seconds': timeTakenSeconds,
      'question_order': questionOrder,
    });
  }

  // Save all question attempts in a single insert call (faster than per-row inserts)
  static Future<void> saveQuestionAttemptsBatch(
    List<Map<String, dynamic>> attempts,
  ) async {
    if (attempts.isEmpty) return;
    await client.from('kls_question_attempts').insert(attempts);
    _invalidateByPrefix('questionAttemptsWithQuestions:');
    _invalidateByPrefix('questionAttemptsByQuizAttempt:');
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
    final uid = currentUser?.id;
    if (uid != null) {
      _invalidateByPrefix('quizAttempt:$uid:');
      _invalidateByPrefix('previousByChapter:$uid:');
      _invalidateByPrefix('previousOverall:$uid:');
    }
    _invalidateByPrefix('attemptById:$attemptId');
    _invalidateByPrefix('questionAttemptsWithQuestions:$attemptId');
    _invalidateByPrefix('questionAttemptsByQuizAttempt:$attemptId');
    _invalidateByPrefix('leaderboard:');
    _invalidateByPrefix('allAttempts:');
  }

  // Get leaderboard
  static Future<List<Map<String, dynamic>>> getLeaderboard(String quizId) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'leaderboard:$quizId',
      ttl: const Duration(seconds: 20),
      loader: () async {
        final response = await client
            .from('kls_quiz_attempts')
            .select(
                'user_id, score, total_time_seconds, correct_answers, total_questions, percentage')
            .eq('quiz_id', quizId)
            .order('score', ascending: false)
            .order('total_time_seconds', ascending: true)
            .limit(50);
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  // Get question attempts with questions
  static Future<List<Map<String, dynamic>>> getQuestionAttemptsWithQuestions(String attemptId) async {
    return _cached<List<Map<String, dynamic>>>(
      key: 'questionAttemptsWithQuestions:$attemptId',
      ttl: const Duration(minutes: 3),
      loader: () async {
        final response = await client
            .from('kls_question_attempts')
            .select('*, kls_questions(*)')
            .eq('quiz_attempt_id', attemptId);
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  // ==================== PERFORMANCE SCREEN METHODS ====================

  // Get quiz attempt by ID (for performance screen)
  static Future<Map<String, dynamic>?> getQuizAttemptById(String attemptId) async {
    try {
      return _cached<Map<String, dynamic>?>(
        key: 'attemptById:$attemptId',
        ttl: const Duration(seconds: 30),
        loader: () async {
          final response = await client
              .from('kls_quiz_attempts')
              .select('*')
              .eq('id', attemptId)
              .single();
          return Map<String, dynamic>.from(response);
        },
      );
    } catch (e) {
      print('Get quiz attempt by ID error: $e');
      return null;
    }
  }

  // Get all quiz attempts for a quiz (for ranking)
  static Future<List<Map<String, dynamic>>?> getAllQuizAttempts(String quizId) async {
    try {
      return _cached<List<Map<String, dynamic>>?>(
        key: 'allAttempts:$quizId',
        ttl: const Duration(seconds: 20),
        loader: () async {
          final response = await client
              .from('kls_quiz_attempts')
              .select('user_id, score, total_time_seconds')
              .eq('quiz_id', quizId)
              .order('score', ascending: false)
              .order('total_time_seconds', ascending: true);
          return List<Map<String, dynamic>>.from(response);
        },
      );
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

      return _cached<List<Map<String, dynamic>>?>(
        key: 'previousByChapter:${currentUser!.id}:$chapterCode:$limit',
        ttl: const Duration(seconds: 30),
        loader: () async {
          final response = await client
              .from('kls_quiz_attempts')
              .select('score, percentage, completed_at')
              .eq('user_id', currentUser!.id)
              .eq('chapter_code', chapterCode)
              .order('completed_at', ascending: false)
              .limit(limit);
          return List<Map<String, dynamic>>.from(response);
        },
      );
    } catch (e) {
      print('Get previous attempts error: $e');
      return null;
    }
  }

  // Get previous attempts across all subjects/chapters for current user
  static Future<List<Map<String, dynamic>>?> getPreviousAttemptsOverall({
    int limit = 3,
  }) async {
    try {
      if (currentUser == null) return null;

      return _cached<List<Map<String, dynamic>>?>(
        key: 'previousOverall:${currentUser!.id}:$limit',
        ttl: const Duration(seconds: 30),
        loader: () async {
          final response = await client
              .from('kls_quiz_attempts')
              .select('score, percentage, completed_at')
              .eq('user_id', currentUser!.id)
              .order('completed_at', ascending: false)
              .limit(limit);

          return List<Map<String, dynamic>>.from(response);
        },
      );
    } catch (e) {
      print('Get overall previous attempts error: $e');
      return null;
    }
  }

  // Get question attempts with difficulty levels (for performance analysis)
  static Future<List<Map<String, dynamic>>?> getQuestionAttemptsByQuizAttempt(String quizAttemptId) async {
    try {
      return _cached<List<Map<String, dynamic>>?>(
        key: 'questionAttemptsByQuizAttempt:$quizAttemptId',
        ttl: const Duration(minutes: 3),
        loader: () async {
          final response = await client
              .from('kls_question_attempts')
              .select('''
            *,
            kls_questions (
              difficulty_level,
              chapter_code
            )
          ''')
              .eq('quiz_attempt_id', quizAttemptId);

          final flattened = (response as List).map((item) {
            final questionData = item['kls_questions'];
            return {
              ...item,
              'difficulty_level': questionData?['difficulty_level'],
              'chapter_name': questionData?['chapter_code'],
            };
          }).toList();

          return List<Map<String, dynamic>>.from(flattened);
        },
      );
    } catch (e) {
      print('Get question attempts with difficulty error: $e');
      return null;
    }
  }
}

class _CacheEntry<T> {
  const _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final T value;
  final DateTime expiresAt;
}
