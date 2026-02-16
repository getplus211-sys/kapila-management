import 'package:flutter/material.dart';
import 'dart:async';
import '../services/supabase_service.dart';
import '../models/quiz_attempt.dart';
import '../models/question_attempt.dart';
import 'package:fl_chart/fl_chart.dart';

class KLSPerformanceScreen extends StatefulWidget {
  final String quizAttemptId;

  const KLSPerformanceScreen({Key? key, required this.quizAttemptId}) : super(key: key);

  @override
  State<KLSPerformanceScreen> createState() => _KLSPerformanceScreenState();
}

class _KLSPerformanceScreenState extends State<KLSPerformanceScreen> {
  bool isLoading = true;
  double loadingProgress = 0.0;
  String loadingMessage = 'Initializing...';
  
  QuizAttempt? quizAttempt;
  List<QuestionAttempt> questionAttempts = [];
  List<Map<String, dynamic>> previousAttempts = [];
  
  String userName = 'Student';
  String quizName = '';
  int userRank = 0;
  
  Map<String, Map<String, int>> difficultyStats = {
    'easy': {'correct': 0, 'total': 0},
    'medium': {'correct': 0, 'total': 0},
    'hard': {'correct': 0, 'total': 0},
  };
  
  Map<String, Map<String, dynamic>> chapterStats = {};

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      updateProgress(10, 'તમારી માહિતી લોડ કરી રહ્યા છીએ...');
      
      // Load user profile
      final profile = await SupabaseService.getUserProfile();
      if (profile != null) {
        userName = profile['full_name'] ?? 'Student';
      }
      
      updateProgress(30, 'Performance data તૈયાર કરી રહ્યા છીએ...');
      
      // Load quiz attempt
      final attemptData = await SupabaseService.getQuizAttemptById(widget.quizAttemptId);
      if (attemptData == null) {
        _showError('Attempt not found');
        return;
      }
      
      quizAttempt = QuizAttempt.fromJson(attemptData);
      
      updateProgress(50, 'તમારા results analyze કરી રહ્યા છીએ...');
      
      // Load quiz name
      final quizData = await SupabaseService.getQuizById(quizAttempt!.quizId);
      if (quizData != null) {
        quizName = quizData['quiz_name'] ?? 'Quiz';
      }
      
      updateProgress(70, 'Charts અને graphs બનાવી રહ્યા છીએ...');
      
      // Calculate rank
      final allAttempts = await SupabaseService.getAllQuizAttempts(quizAttempt!.quizId);
      if (allAttempts != null) {
        final sortedAttempts = List<Map<String, dynamic>>.from(allAttempts);
        sortedAttempts.sort((a, b) {
          final scoreCompare = (b['score'] as int).compareTo(a['score'] as int);
          if (scoreCompare != 0) return scoreCompare;
          return (a['total_time_seconds'] as int).compareTo(b['total_time_seconds'] as int);
        });
        
        final myIndex = sortedAttempts.indexWhere((a) => a['user_id'] == quizAttempt!.userId);
        userRank = myIndex + 1;
      }
      
      // Load previous attempts for trend
      previousAttempts = await SupabaseService.getPreviousAttemptsByChapter(
        quizAttempt!.chapterCode,
        limit: 5,
      ) ?? [];
      
      // Load question attempts with difficulty levels
      final attempts = await SupabaseService.getQuestionAttemptsByQuizAttempt(widget.quizAttemptId);
      if (attempts != null) {
        questionAttempts = attempts.map((json) => QuestionAttempt.fromJson(json)).toList();
        
        // Calculate statistics
        _calculateStatistics();
      }
      
      updateProgress(90, 'લગભગ તૈયાર છે...');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      updateProgress(100, 'તૈયાર છે! ✓');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() => isLoading = false);
      
    } catch (e) {
      print('Performance init error: $e');
      _showError(e.toString());
    }
  }
  
  void updateProgress(double progress, String message) {
    setState(() {
      loadingProgress = progress;
      loadingMessage = message;
    });
  }
  
  void _calculateStatistics() {
    // Reset stats
    difficultyStats = {
      'easy': {'correct': 0, 'total': 0},
      'medium': {'correct': 0, 'total': 0},
      'hard': {'correct': 0, 'total': 0},
    };
    chapterStats = {};
    
    for (var attempt in questionAttempts) {
      // Difficulty stats
      final difficulty = attempt.difficultyLevel ?? 'સરળ';
      if (difficulty == 'સરળ') {
        difficultyStats['easy']!['total'] = (difficultyStats['easy']!['total'] ?? 0) + 1;
        if (attempt.isCorrect) {
          difficultyStats['easy']!['correct'] = (difficultyStats['easy']!['correct'] ?? 0) + 1;
        }
      } else if (difficulty == 'મધ્યમ') {
        difficultyStats['medium']!['total'] = (difficultyStats['medium']!['total'] ?? 0) + 1;
        if (attempt.isCorrect) {
          difficultyStats['medium']!['correct'] = (difficultyStats['medium']!['correct'] ?? 0) + 1;
        }
      } else if (difficulty == 'મુશ્કેલ') {
        difficultyStats['hard']!['total'] = (difficultyStats['hard']!['total'] ?? 0) + 1;
        if (attempt.isCorrect) {
          difficultyStats['hard']!['correct'] = (difficultyStats['hard']!['correct'] ?? 0) + 1;
        }
      }
      
      // Chapter stats
      final chapterName = attempt.chapterName ?? 'Unknown';
      if (!chapterStats.containsKey(chapterName)) {
        chapterStats[chapterName] = {'total': 0, 'correct': 0};
      }
      chapterStats[chapterName]!['total'] = (chapterStats[chapterName]!['total'] ?? 0) + 1;
      if (attempt.isCorrect) {
        chapterStats[chapterName]!['correct'] = (chapterStats[chapterName]!['correct'] ?? 0) + 1;
      }
    }
  }
  
  void _showError(String message) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message')),
    );
  }
  
  String getPerformanceLevel(double percentage) {
    if (percentage <= 10) return "Initial";
    if (percentage <= 20) return "Starter";
    if (percentage <= 30) return "Good";
    if (percentage <= 40) return "Better";
    if (percentage <= 50) return "Nice";
    if (percentage <= 60) return "Very Good";
    if (percentage <= 70) return "Very Nice";
    if (percentage <= 80) return "Excellent";
    if (percentage <= 90) return "Excellent+";
    return "Perfect";
  }
  
  Color getLevelColor(String level) {
    switch (level) {
      case 'Initial': return const Color(0xFFef4444);
      case 'Starter': return const Color(0xFFf97316);
      case 'Good': return const Color(0xFFf59e0b);
      case 'Better': return const Color(0xFFeab308);
      case 'Nice': return const Color(0xFF84cc16);
      case 'Very Good': return const Color(0xFF22c55e);
      case 'Very Nice': return const Color(0xFF10b981);
      case 'Excellent': return const Color(0xFF14b8a6);
      case 'Excellent+': return const Color(0xFF06b6d4);
      case 'Perfect': return const Color(0xFF8b5cf6);
      default: return const Color(0xFF6b7280);
    }
  }
  
  double calculateConcentrationRating(int avgTimePerQ, double accuracy) {
    if (accuracy <= 0) return 1.0;
    
    double rating = 10.0;
    
    // Time-based deductions
    if (avgTimePerQ > 10) rating -= 0.05 * (avgTimePerQ - 10);
    if (avgTimePerQ > 20) rating -= 0.10 * (avgTimePerQ - 20);
    if (avgTimePerQ > 30) rating -= 0.15 * (avgTimePerQ - 30);
    
    // Accuracy-based deductions
    if (accuracy < 100) rating -= 0.01 * (100 - accuracy);
    if (accuracy < 80) rating -= 0.02 * (80 - accuracy);
    if (accuracy < 50) rating -= 0.03 * (50 - accuracy);
    
    return rating.clamp(1.0, 10.0);
  }
  
  double calculateWeightedAccuracy() {
    double weightedMarks = 0;
    double maxWeightedMarks = 0;
    
    for (var attempt in questionAttempts) {
      final difficulty = attempt.difficultyLevel ?? 'સરળ';
      
      if (difficulty == 'સરળ') {
        maxWeightedMarks += 0.33;
        if (attempt.isCorrect) weightedMarks += 0.33;
      } else if (difficulty == 'મધ્યમ') {
        maxWeightedMarks += 0.50;
        if (attempt.isCorrect) weightedMarks += 0.50;
      } else if (difficulty == 'મુશ્કેલ') {
        maxWeightedMarks += 1.00;
        if (attempt.isCorrect) weightedMarks += 1.00;
      }
    }
    
    return maxWeightedMarks > 0 ? (weightedMarks / maxWeightedMarks) * 100 : 0.0;
  }
  
  Color getPercentageColor(double percentage) {
    if (percentage >= 85) return const Color(0xFF22c55e);
    if (percentage >= 70) return const Color(0xFF10b981);
    if (percentage >= 55) return const Color(0xFF3b82f6);
    if (percentage >= 40) return const Color(0xFFf59e0b);
    return const Color(0xFFef4444);
  }
  
  void showConcentrationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('ℹ️', style: TextStyle(fontSize: 32)),
            SizedBox(width: 12),
            Expanded(child: Text('એકાગ્રતા રેટિંગ')),
          ],
        ),
        content: const Text(
          'આ રેટિંગ તમારી સ્પીડ અને ચોકસાઈ બંને પર આધારિત છે.\n\n'
          'જો તમે બધા પ્રશ્નો સાચા કરો પણ વધુ સમય લો તો, એકાગ્રતા તમારી ઓછી જ ગણાશે. '
          'ઝડપ અને ચોકસાઈ ઉપર એકાગ્રતાનું માપન થાય છે.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('સમજાયું'),
          ),
        ],
      ),
    );
  }
  
  void showLevelInfo() {
    final levels = [
      {'name': 'Initial', 'range': '1-10%'},
      {'name': 'Starter', 'range': '11-20%'},
      {'name': 'Good', 'range': '21-30%'},
      {'name': 'Better', 'range': '31-40%'},
      {'name': 'Nice', 'range': '41-50%'},
      {'name': 'Very Good', 'range': '51-60%'},
      {'name': 'Very Nice', 'range': '61-70%'},
      {'name': 'Excellent', 'range': '71-80%'},
      {'name': 'Excellent+', 'range': '81-90%'},
      {'name': 'Perfect', 'range': '91-100%'},
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('📊', style: TextStyle(fontSize: 32)),
            SizedBox(width: 12),
            Expanded(child: Text('Performance Levels')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('તમારા પ્રદર્શનના આધારે levels:\n'),
              ...levels.map((level) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${level['name']}: ${level['range']}'),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('સમજાયું'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingScreen();
    }
    
    return _buildPerformanceScreen();
  }
  
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8b5cf6), Color(0xFF7c3aed)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('🎓', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'KAPiLa Learning',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                loadingMessage,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6b7280)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: loadingProgress / 100,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFe5e7eb),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8b5cf6)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${loadingProgress.toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8b5cf6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPerformanceScreen() {
    if (quizAttempt == null) {
      return Scaffold(
        body: const Center(child: Text('No data available')),
      );
    }
    
    final percentage = quizAttempt!.percentage;
    final level = getPerformanceLevel(percentage);
    final levelColor = getLevelColor(level);
    final timePerQ = (quizAttempt!.totalTimeSeconds / quizAttempt!.totalQuestions).floor();
    final concentrationRating = calculateConcentrationRating(timePerQ, percentage);
    final weightedAccuracy = calculateWeightedAccuracy();
    final improvementNeeded = 100 - percentage.toInt();
    
    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'S';
    
    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance Dashboard', style: TextStyle(fontSize: 16)),
            Text(quizName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: const Color(0xFF8b5cf6),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            icon: const Text('🏠', style: TextStyle(fontSize: 18)),
            label: const Text('Home'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentCard(firstLetter, level, levelColor),
            const SizedBox(height: 14),
            _buildPieChart(),
            const SizedBox(height: 14),
            _buildStatsGrid(timePerQ, concentrationRating, weightedAccuracy, improvementNeeded),
            const SizedBox(height: 14),
            if (previousAttempts.isNotEmpty) _buildTrendChart(),
            if (previousAttempts.isNotEmpty) const SizedBox(height: 14),
            _buildChapterAnalysis(),
            const SizedBox(height: 14),
            _buildRecommendations(percentage),
            const SizedBox(height: 14),
            _buildExtraSuggestions(),
            const SizedBox(height: 14),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStudentCard(String firstLetter, String level, Color levelColor) {
    final date = quizAttempt!.completedAt != null
        ? '${quizAttempt!.completedAt!.day}-${quizAttempt!.completedAt!.month}-${quizAttempt!.completedAt!.year}'
        : '';
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFe9d5ff), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFfaf5ff), Color(0xFFf3e8ff)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      firstLetter,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1e293b),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildMetaBadge('📅', date, const Color(0xFFdbeafe), const Color(0xFFbfdbfe)),
                          _buildMetaBadge('🏆', 'Rank #$userRank', const Color(0xFFfef08a), const Color(0xFFfde047)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: showLevelInfo,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [levelColor, levelColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: levelColor.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('ℹ️', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetaBadge(String icon, String text, Color color1, Color color2) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPieChart() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFfde047), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFfefce8), Color(0xFFfef9c3)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Quiz પરિણામ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF854d0e),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: quizAttempt!.correctAnswers.toDouble(),
                      title: 'સાચા\n${quizAttempt!.correctAnswers}',
                      color: const Color(0xFF22c55e),
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      titlePositionPercentageOffset: 0.5,
                    ),
                    PieChartSectionData(
                      value: quizAttempt!.wrongAnswers.toDouble(),
                      title: 'ખોટા\n${quizAttempt!.wrongAnswers}',
                      color: const Color(0xFFef4444),
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      titlePositionPercentageOffset: 0.5,
                    ),
                    PieChartSectionData(
                      value: quizAttempt!.skippedQuestions.toDouble(),
                      title: 'બાકી\n${quizAttempt!.skippedQuestions}',
                      color: const Color(0xFFe5e7eb),
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                      titlePositionPercentageOffset: 0.5,
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsGrid(int timePerQ, double concentrationRating, double weightedAccuracy, int improvementNeeded) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('કુલ પ્રશ્નો', '${quizAttempt!.totalQuestions}', const Color(0xFFe0e7ff), const Color(0xFFc7d2fe), const Color(0xFF4338ca)),
        _buildStatCard('સાચા જવાબ', '${quizAttempt!.correctAnswers}', const Color(0xFFd1fae5), const Color(0xFFa7f3d0), const Color(0xFF047857)),
        _buildStatCard('ખોટા જવાબ', '${quizAttempt!.wrongAnswers}', const Color(0xFFfee2e2), const Color(0xFFfecaca), const Color(0xFFdc2626)),
        _buildStatCard('ટકાવારી', '${quizAttempt!.percentage.toStringAsFixed(1)}%', const Color(0xFFfef3c7), const Color(0xFFfde68a), const Color(0xFFa16207)),
        _buildStatCard('ચોકસાઈ (Weighted)', '${weightedAccuracy.toStringAsFixed(2)}%', const Color(0xFFe0e7ff), const Color(0xFFc7d2fe), const Color(0xFF4338ca)),
        _buildStatCard('સમય/પ્રશ્ન', '${timePerQ}s', const Color(0xFFf3e8ff), const Color(0xFFe9d5ff), const Color(0xFF7c3aed)),
        _buildStatCard('એકાગ્રતા રેટિંગ ℹ️', '${concentrationRating.toStringAsFixed(2)}/10', const Color(0xFFffedd5), const Color(0xFFfed7aa), const Color(0xFFc2410c), onTap: showConcentrationInfo),
        _buildStatCard('સરળ (સાચા/કુલ)', '${difficultyStats['easy']!['correct']}/${difficultyStats['easy']!['total']}', const Color(0xFFd1fae5), const Color(0xFFa7f3d0), const Color(0xFF047857)),
        _buildStatCard('મધ્યમ (સાચા/કુલ)', '${difficultyStats['medium']!['correct']}/${difficultyStats['medium']!['total']}', const Color(0xFFfef08a), const Color(0xFFfde047), const Color(0xFFa16207)),
        _buildStatCard('મુશ્કેલ (સાચા/કુલ)', '${difficultyStats['hard']!['correct']}/${difficultyStats['hard']!['total']}', const Color(0xFFfecaca), const Color(0xFFfca5a5), const Color(0xFFb91c1c)),
        _buildStatCard('ટાર્ગેટ સ્કોર', '60', const Color(0xFFddd6fe), const Color(0xFFc4b5fd), const Color(0xFF6d28d9)),
        _buildStatCard('સુધારો જરૂર', '$improvementNeeded%', const Color(0xFFfed7aa), const Color(0xFFfdba74), const Color(0xFFc2410c)),
      ],
    );
  }
  
  Widget _buildStatCard(String label, String value, Color color1, Color color2, Color textColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color1, color2]),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6b7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrendChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'તમારી પ્રગતિ (Trend)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < previousAttempts.length) {
                            return Text(
                              'T${previousAttempts.length - index}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minY: 0,
                  maxY: 100,
                  lineTouchData: const LineTouchData(enabled: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: previousAttempts.reversed.toList().asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          (entry.value['percentage'] as num).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF667eea),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF667eea).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChapterAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Chapter વાર એનાલિસિસ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFfef3c7), Color(0xFFfde68a)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFfbbf24), width: 2),
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Table(
                    border: TableBorder.all(color: const Color(0xFFe5e7eb)),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFF667eea)),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: Text('ચેપ્ટર', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: Text('પ્રશ્નો', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                          ),
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: Text('સાચા', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                          ),
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: Text('પરિણામ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                      ...chapterStats.entries.map((entry) {
                        final percentage = (entry.value['correct']! / entry.value['total']!) * 100;
                        final color = getPercentageColor(percentage);
                        
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text('${entry.value['total']}', textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text('${entry.value['correct']}', textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecommendations(double percentage) {
    if (percentage >= 85) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e3a8a), Color(0xFF1e40af)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📚 અભ્યાસ સમય ભલામણ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 15),
          ...[
            'દરરોજ ઓછામાં ઓછા 10-12 કલાક અભ્યાસ કરો',
            'સવારે 3-4 કલાક, બપોરે 3-4 કલાક અને રાત્રે 3-4 કલાક વહેંચો',
            'નિયમિતતા અને discipline જાળવો અને focused study કરો',
            'શાંત વાતાવરણમાં અભ્યાસ કરો અને mobile notifications બંધ રાખો',
          ].map((text) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✓ ', style: TextStyle(color: Color(0xFF22c55e), fontWeight: FontWeight.bold, fontSize: 16)),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildExtraSuggestions() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10b981)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 KAPiLa\'s Extra Suggestions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 15),
          ...[
            'તમારા મિત્રો સાથે નબળા વિષયો પર ચર્ચા કરો - શીખવાનો શ્રેષ્ઠ માર્ગ',
            'જે વિષય તમને ઓછો આવડે છે તેની ચર્ચા કરો અને સમજો',
            'જે વિષય તમારા મિત્રને ઓછો આવડે છે તો તમે તેને શીખવાડો - આથી તમારું પણ રિવિઝન થશે',
            'રોજ રાત્રે સૂતાં પહેલાં દિવસ દરમિયાન જે વાંચ્યું છે તેનું મનન કરો',
            'તે ટોપિક યાદ કરો અને મનમાં revision કરો - આ એક સૌથી મોટી જડીબુટ્ટી છે!',
            'ગ્રુપ સ્ટડી કરવાથી સમજ વધુ સ્પષ્ટ થાય છે અને motivation મળે છે',
            'હેલ્થી lifestyle જાળવો - સારી ઊંઘ, સારું ખાવાનું અને થોડી exercise',
          ].map((text) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✓ ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3b82f6),
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('← પાછા જાઓ'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3b82f6),
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('🏠 Home'),
          ),
        ),
      ],
    );
  }
}