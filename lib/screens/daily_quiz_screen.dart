import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../utils/error_handler.dart';
import 'quiz_engine_screen.dart';

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  bool _loading = true;
  Map<String, dynamic>? _dailyQuiz;
  Map<String, dynamic>? _dailySettings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.getDailyQuizForDate(DateTime.now(), forceRefresh: true),
        SupabaseService.client
            .from('kls_daily_quiz_settings')
            .select('*')
            .eq('quiz_id', SupabaseService.dailyQuizIdForDate(DateTime.now()))
            .maybeSingle(),
      ]);
      if (!mounted) return;
      setState(() {
        _dailyQuiz = results[0] as Map<String, dynamic>?;
        _dailySettings = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ErrorHandler.showFriendlyError(context, e);
    }
  }

  void _startQuiz() {
    final quizId = _dailyQuiz?['quiz_id']?.toString() ?? '';
    if (quizId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizEngineScreen(quizId: quizId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizId = _dailyQuiz?['quiz_id']?.toString() ?? '';
    final title = _dailyQuiz?['quiz_name']?.toString() ??
        _dailySettings?['quiz_name']?.toString() ??
        'Daily Learning';
    final questionCount = (_dailyQuiz?['total_questions'] as num?)?.toInt() ??
        (_dailySettings?['total_questions'] as num?)?.toInt() ??
        0;
    final timeLimit = (_dailyQuiz?['time_limit'] as num?)?.toInt() ??
        (_dailySettings?['time_limit'] as num?)?.toInt() ??
        0;
    final isEnabled = _dailySettings?['is_enabled'] == true;
    final hasPublishedQuiz = _dailyQuiz != null || _dailySettings != null;
    final dateLabel = DateTime.now().toLocal();
    final dateText =
        '${dateLabel.year}-${dateLabel.month.toString().padLeft(2, '0')}-${dateLabel.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF060F14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF060F14), Color(0xFF0D2030)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Daily Learning',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                  child: Container(
                                    width: double.infinity,
                                    constraints: const BoxConstraints(maxWidth: 520),
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: const Color(0xFF00BFA5).withOpacity(0.25),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 58,
                                              height: 58,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00BFA5).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(18),
                                              ),
                                              child: const Icon(
                                                Icons.event_note_rounded,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    dateText,
                                                    style: const TextStyle(
                                                      color: Color(0xFF9CC8C1),
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    !hasPublishedQuiz
                                                        ? 'Not available'
                                                        : title,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          !hasPublishedQuiz
                                              ? 'Today\'s quiz has not been published yet.'
                                              : isEnabled
                                                  ? 'Ready to start ${questionCount} questions with a ${timeLimit > 0 ? '$timeLimit minute' : 'no'} timer.'
                                                  : 'Daily quiz is currently turned off by admin.',
                                          style: const TextStyle(
                                            color: Color(0xFFD8E7E4),
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                        if (hasPublishedQuiz) ...[
                                          const SizedBox(height: 20),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: [
                                              _InfoChip(
                                                label: 'Quiz ID',
                                                value: quizId,
                                              ),
                                              _InfoChip(
                                                label: 'Questions',
                                                value: questionCount.toString(),
                                              ),
                                              const _InfoChip(
                                                label: 'Mode',
                                                value: 'Same engine',
                                              ),
                                              _InfoChip(
                                                label: 'Status',
                                                value: isEnabled ? 'On' : 'Off',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: isEnabled ? _startQuiz : null,
                                                  icon: const Icon(Icons.play_arrow_rounded),
                                                  label: Text(isEnabled ? 'Start Today' : 'Turned Off'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF00BFA5),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CC8C1),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
