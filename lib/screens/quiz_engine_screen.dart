import 'package:flutter/material.dart';
import 'dart:async';
import '../services/supabase_service.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import '../models/quiz_attempt.dart';
import '../models/question_attempt.dart';
import 'package:fl_chart/fl_chart.dart';
import 'kls_performance_screen.dart';

class QuizEngineScreen extends StatefulWidget {
  final String quizId;

  const QuizEngineScreen({Key? key, required this.quizId}) : super(key: key);

  @override
  State<QuizEngineScreen> createState() => _QuizEngineScreenState();
}

class _QuizEngineScreenState extends State<QuizEngineScreen> {
  Quiz? currentQuiz;
  List<Question> questions = [];
  Map<String, int> answers = {}; // question_id -> option number (1-5)
  
  int currentQuestionIndex = 0;
  bool isLoading = true;
  bool hasStarted = false;
  bool submitted = false;
  bool agreedToTerms = false;
  
  DateTime? startTime;
  Timer? timer;
  int elapsedSeconds = 0;
  
  Map<String, dynamic>? existingAttempt;
  String? quizAttemptId;
  
  // For solutions
  List<Map<String, dynamic>> questionAttempts = [];
  bool showingSolutions = false;
  bool showingLeaderboard = false;
  List<Map<String, dynamic>> leaderboardData = [];
  String userName = '';
  int userRank = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> init() async {
    try {
      // Load user name
      final profile = await SupabaseService.getUserProfile();
      userName = profile?['full_name'] ?? 'Student';
      
      // Load quiz
      final quizData = await SupabaseService.getQuizById(widget.quizId);
      if (quizData == null) {
        _showError('Test Not Found');
        return;
      }
      
      currentQuiz = Quiz.fromJson(quizData);
      
      // Check existing attempt
      existingAttempt = await SupabaseService.getQuizAttempt(widget.quizId);
      
      if (existingAttempt != null) {
        quizAttemptId = existingAttempt!['id'];
        setState(() => isLoading = false);
        return;
      }
      
      // Load questions
      final questionsData = await SupabaseService.getQuestionsByQuiz(widget.quizId);
      questions = questionsData.map((json) => Question.fromJson(json)).toList();
      
      if (questions.isEmpty) {
        _showError('No Questions');
        return;
      }
      
      setState(() => isLoading = false);
      
    } catch (e) {
      print('Init error: $e');
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message')),
    );
  }

  void startQuiz() {
    if (!agreedToTerms) {
      _showDialog(
        '⚠️',
        'શરતો સ્વીકારો',
        'ટેસ્ટ શરૂ કરવા માટે કૃપા કરીને શરતો અને નિયમો સ્વીકારો.',
        [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('સમજાયું'),
          ),
        ],
      );
      return;
    }
    
    setState(() {
      hasStarted = true;
      startTime = DateTime.now();
    });
    
    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        elapsedSeconds = DateTime.now().difference(startTime!).inSeconds;
      });
    });
  }

  void selectOption(int optionNumber) {
    setState(() {
      answers[questions[currentQuestionIndex].id] = optionNumber;
    });
  }

  void nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() => currentQuestionIndex++);
    }
  }

  void previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() => currentQuestionIndex--);
    }
  }

  void jumpToQuestion(int index) {
    setState(() => currentQuestionIndex = index);
  }

  void confirmSubmit() {
    int unanswered = questions.length - answers.length;
    
    _showDialog(
      '❓',
      'ટેસ્ટ સબમિટ કરો?',
      'શું તમે ખરેખર આ ટેસ્ટ સબમિટ કરવા માંગો છો? તમે પછી કોઈ જવાબ બદલી શકશો નહીં.${unanswered > 0 ? '\n\n$unanswered પ્રશ્નો બાકી છે!' : ''}',
      [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('રદ કરો'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            submitTest();
          },
          child: const Text('હા, સબમિટ કરો'),
        ),
      ],
    );
  }

  Future<void> submitTest() async {
    if (submitted) return;
    
    setState(() => submitted = true);
    timer?.cancel();
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('સબમિટ થઈ રહ્યું છે...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      int correct = 0, wrong = 0, skipped = 0, eOption = 0;
      
      for (var question in questions) {
        final userAnswer = answers[question.id];
        final correctOption = question.getCorrectOptionNumber();
        
        if (userAnswer == 5) {
          eOption++;
        } else if (userAnswer == null) {
          skipped++;
        } else if (userAnswer == correctOption) {
          correct++;
        } else {
          wrong++;
        }
      }
      
      final score = correct;
      final timeTaken = elapsedSeconds;
      final percentage = (correct / questions.length * 100);
      
      // Save quiz attempt
      final attemptData = await SupabaseService.saveQuizAttempt(
        quizId: widget.quizId,
        subjectId: currentQuiz!.subjectId,
        chapterCode: currentQuiz!.chapterCode,
        totalQuestions: questions.length,
        attemptedQuestions: correct + wrong,
        correctAnswers: correct,
        wrongAnswers: wrong,
        skippedQuestions: skipped,
        eOptionUsed: eOption,
        score: score,
        percentage: percentage,
        totalTimeSeconds: timeTaken,
        startedAt: startTime!,
        completedAt: DateTime.now(),
      );
      
      quizAttemptId = attemptData['id'];
      
      // Save question attempts
      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        final userAnswer = answers[question.id];
        final correctOption = question.getCorrectOptionNumber();
        
        String selectedAnswer;
        bool isCorrect;
        
        if (userAnswer == 5) {
          selectedAnswer = 'E';
          isCorrect = false;
        } else if (userAnswer == null) {
          selectedAnswer = 'SKIPPED';
          isCorrect = false;
        } else {
          selectedAnswer = userAnswer == 1 ? 'A' : userAnswer == 2 ? 'B' : userAnswer == 3 ? 'C' : 'D';
          isCorrect = userAnswer == correctOption;
        }
        
        await SupabaseService.saveQuestionAttempt(
          quizAttemptId: quizAttemptId!,
          questionId: question.id,
          quizId: widget.quizId,
          selectedAnswer: selectedAnswer,
          isCorrect: isCorrect,
          timeTakenSeconds: timeTaken ~/ questions.length,
          questionOrder: i + 1,
        );
      }
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Update state to show result
      setState(() {
        hasStarted = false;
        existingAttempt = {
          'id': quizAttemptId,
          'score': score,
          'correct_answers': correct,
          'wrong_answers': wrong,
          'skipped_questions': skipped,
          'e_option_used': eOption,
          'total_time_seconds': timeTaken,
          'total_questions': questions.length,
          'percentage': percentage,
        };
      });
      
    } catch (e) {
      Navigator.pop(context);
      _showError('Submit failed: $e');
      setState(() => submitted = false);
    }
  }

  void _showDialog(String icon, String title, String message, List<Widget> actions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: actions,
      ),
    );
  }
  
  Future<void> loadSolutions() async {
    setState(() => isLoading = true);
    
    try {
      final attempts = await SupabaseService.getQuestionAttemptsWithQuestions(quizAttemptId!);
      
      setState(() {
        questionAttempts = attempts ?? [];
        showingSolutions = true;
        showingLeaderboard = false;
        isLoading = false;
      });
    } catch (e) {
      _showError('Failed to load solutions: $e');
      setState(() => isLoading = false);
    }
  }
  
  Future<void> loadLeaderboard() async {
    setState(() => isLoading = true);
    
    try {
      final allAttempts = await SupabaseService.getAllQuizAttempts(widget.quizId);
      
      if (allAttempts != null) {
        // Calculate user rank
        final myIndex = allAttempts.indexWhere((a) => a['user_id'] == SupabaseService.currentUser?.id);
        userRank = myIndex + 1;
        
        // Get top 50
        final top50 = allAttempts.take(50).toList();
        
        // Get user names
        final userIds = top50.map((a) => a['user_id'] as String).toList();
        final profiles = await Future.wait(
          userIds.map((id) => SupabaseService.client
              .from('profiles')
              .select('id, full_name')
              .eq('id', id)
              .single())
        );
        
        // Merge data
        for (int i = 0; i < top50.length; i++) {
          top50[i]['name'] = profiles[i]['full_name'] ?? 'User';
        }
        
        setState(() {
          leaderboardData = top50;
          showingLeaderboard = true;
          showingSolutions = false;
          isLoading = false;
        });
      }
    } catch (e) {
      _showError('Failed to load leaderboard: $e');
      setState(() => isLoading = false);
    }
  }
  
  void backToResult() {
    setState(() {
      showingSolutions = false;
      showingLeaderboard = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFf1f5f9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('લોડ થઈ રહ્યું છે...'),
            ],
          ),
        ),
      );
    }
    
    // Show solutions screen
    if (showingSolutions) {
      return _buildSolutionsScreen();
    }
    
    // Show leaderboard screen
    if (showingLeaderboard) {
      return _buildLeaderboardScreen();
    }
    
    // Show result if already attempted
    if (existingAttempt != null && !hasStarted) {
      return _buildResultScreen();
    }
    
    // Show instructions if not started
    if (!hasStarted) {
      return _buildInstructionsScreen();
    }
    
    // Show quiz screen
    return _buildQuizScreen();
  }

  Widget _buildInstructionsScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: const Text('Instructions'),
        backgroundColor: const Color(0xFF8b5cf6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Instructions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  currentQuiz!.quizName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text('Total Questions: ${questions.length}'),
                Text('Duration: ${currentQuiz!.timeLimit} minutes'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf1f5f9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Guidelines:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('• દરેક પ્રશ્નમાં એક જ સાચો જવાબ છે'),
                      Text('• તમે કોઈપણ સમયે પ્રશ્નો વચ્ચે આગળ-પાછળ જઈ શકો છો'),
                      Text('• E વિકલ્પ નો ઉપયોગ કરી શકો છો જો જરૂર હોય'),
                      Text('• સબમિટ કર્યા પછી જવાબ બદલી શકાશે નહીં'),
                      Text('• આ ટેસ્ટ માત્ર એક જ વાર આપી શકાય છે'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: agreedToTerms,
                  onChanged: (val) => setState(() => agreedToTerms = val ?? false),
                  title: const Text('હું શરતો અને નિયમોને સ્વીકારું છું'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: startQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22c55e),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Text('▶️ ટેસ્ટ શરૂ કરો', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← પાછા જાઓ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizScreen() {
    final question = questions[currentQuestionIndex];
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    
    return WillPopScope(
      onWillPop: () async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Warning'),
            content: const Text('શું તમે ખરેખર આ પેજ છોડવા માંગો છો? તમારો પ્રગતિ સેવ થશે નહીં!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('રહો'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('છોડો'),
              ),
            ],
          ),
        ) ?? false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFf1f5f9),
        body: SafeArea(
          child: Column(
            children: [
              // Timer and progress
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '⏱️ $minutes:${seconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'પ્રશ્ન ${currentQuestionIndex + 1}/${questions.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              
              // Question - FULL SCREEN CARD
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Question Card - Full Screen
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  question.question,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildOption('A', question.optionA, 1),
                                _buildOption('B', question.optionB, 2),
                                _buildOption('C', question.optionC, 3),
                                _buildOption('D', question.optionD, 4),
                                if (question.optionE != null && question.optionE!.isNotEmpty)
                                  _buildOption('E', question.optionE!, 5, isEOption: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Navigation Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            if (currentQuestionIndex > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: previousQuestion,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(14),
                                  ),
                                  child: const Text('⬅ પાછળ'),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: currentQuestionIndex == questions.length - 1
                                  ? ElevatedButton(
                                      onPressed: confirmSubmit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFdc2626),
                                        padding: const EdgeInsets.all(14),
                                      ),
                                      child: const Text('✓ સબમિટ કરો'),
                                    )
                                  : ElevatedButton(
                                      onPressed: nextQuestion,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.all(14),
                                      ),
                                      child: const Text('આગળ ➡'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Question Navigator
                      Card(
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Question Navigator',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(questions.length, (index) {
                                  final isAnswered = answers.containsKey(questions[index].id);
                                  final isCurrent = index == currentQuestionIndex;
                                  
                                  return GestureDetector(
                                    onTap: () => jumpToQuestion(index),
                                    child: Container(
                                      width: 45,
                                      height: 45,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? const Color(0xFF3b82f6)
                                            : isAnswered
                                                ? const Color(0xFF22c55e)
                                                : Colors.white,
                                        border: Border.all(
                                          color: isCurrent
                                              ? const Color(0xFF3b82f6)
                                              : isAnswered
                                                  ? const Color(0xFF22c55e)
                                                  : const Color(0xFFddd),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: (isCurrent || isAnswered)
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(String letter, String text, int optionNumber, {bool isEOption = false}) {
    final isSelected = answers[questions[currentQuestionIndex].id] == optionNumber;
    
    return GestureDetector(
      onTap: () => selectOption(optionNumber),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22c55e) : Colors.white,
          border: Border.all(
            color: isEOption
                ? const Color(0xFFd1d5db)
                : isSelected
                    ? const Color(0xFF22c55e)
                    : const Color(0xFFddd),
            width: isEOption ? 2 : 2,
            style: isEOption ? BorderStyle.solid : BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$letter. $text',
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: isSelected ? Colors.white : (isEOption ? const Color(0xFF6b7280) : Colors.black),
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final attempt = existingAttempt!;
    final minutes = attempt['total_time_seconds'] ~/ 60;
    final seconds = attempt['total_time_seconds'] % 60;
    
    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: const Text('પરિણામ'),
        backgroundColor: const Color(0xFF8b5cf6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22c55e),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'KAPiLa',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your Score: ${attempt['score']}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('Correct: ${attempt['correct_answers']} | Wrong: ${attempt['wrong_answers']}'),
                    const SizedBox(height: 4),
                    Text('Skipped: ${attempt['skipped_questions']} | E Options: ${attempt['e_option_used']}'),
                    const SizedBox(height: 4),
                    Text('Time Taken: ${minutes}m ${seconds}s'),
                    const SizedBox(height: 20),
                    
                    // Pie Chart
                    SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: attempt['correct_answers'].toDouble(),
                              title: 'સાચા\n${attempt['correct_answers']}',
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
                              value: attempt['wrong_answers'].toDouble(),
                              title: 'ખોટા\n${attempt['wrong_answers']}',
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
                              value: attempt['skipped_questions'].toDouble(),
                              title: 'બાકી\n${attempt['skipped_questions']}',
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
                    
                    const SizedBox(height: 20),
                    
                    // Buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KLSPerformanceScreen(
                                quizAttemptId: quizAttemptId!,
                              ),
                            ),
                          );
                        },
                        icon: const Text('📊'),
                        label: const Text('Performance Report જુઓ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22c55e),
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: loadLeaderboard,
                        icon: const Text('🏆'),
                        label: const Text('View Leaderboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3b82f6),
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: loadSolutions,
                        icon: const Text('📝'),
                        label: const Text('View Solutions'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('🔄 ફરી ટેસ્ટ આપો'),
                              content: const Text('શું તમે ખરેખર આ ટેસ્ટ ફરીથી આપવા માંગો છો?\n\nનોંધ: તમારો જૂનો સ્કોર અને પ્રયાસ delete થઈ જશે.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('ના, રદ કરો'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('હા, ફરી ટેસ્ટ આપું'),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirm == true && quizAttemptId != null) {
                            try {
                              await SupabaseService.deleteQuizAttempt(quizAttemptId!);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QuizEngineScreen(quizId: widget.quizId),
                                ),
                              );
                            } catch (e) {
                              _showError('Delete failed: $e');
                            }
                          }
                        },
                        icon: const Text('🔄'),
                        label: const Text('શું તમે ફરી ટેસ્ટ આપવા માંગો છો?'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8b5cf6),
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('← પાછા જાઓ'),
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
  
  Widget _buildSolutionsScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: const Text('Answer Key & Solutions'),
        backgroundColor: const Color(0xFF8b5cf6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: backToResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.all(14),
                ),
                child: const Text('← પાછા જાઓ'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Question Navigator
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Question Navigator',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(questionAttempts.length, (index) {
                        final attempt = questionAttempts[index];
                        final isCorrect = attempt['is_correct'];
                        final isSkipped = attempt['selected_answer'] == 'SKIPPED';
                        
                        return Container(
                          width: 45,
                          height: 45,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSkipped
                                ? const Color(0xFFcbd5e1)
                                : isCorrect
                                    ? const Color(0xFF22c55e)
                                    : const Color(0xFFef4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Solutions
            ...questionAttempts.asMap().entries.map((entry) {
              final index = entry.key;
              final attempt = entry.value;
              final q = attempt['kls_questions'];
              final userAns = attempt['selected_answer'];
              final correctAns = q['correct_answer'];
              final isCorrect = attempt['is_correct'];
              final isSkipped = userAns == 'SKIPPED';
              
              String getUserAnswer() {
                if (userAns == 'SKIPPED') return 'છોડી દીધો';
                if (userAns == 'A') return q['option_a'];
                if (userAns == 'B') return q['option_b'];
                if (userAns == 'C') return q['option_c'];
                if (userAns == 'D') return q['option_d'];
                if (userAns == 'E') return q['option_e'];
                return 'N/A';
              }
              
              String getCorrectAnswer() {
                if (correctAns == 'A') return q['option_a'];
                if (correctAns == 'B') return q['option_b'];
                if (correctAns == 'C') return q['option_c'];
                if (correctAns == 'D') return q['option_d'];
                if (correctAns == 'E') return q['option_e'];
                return 'N/A';
              }
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSkipped
                        ? const Color(0xFFcbd5e1)
                        : isCorrect
                            ? const Color(0xFF22c55e)
                            : const Color(0xFFef4444),
                    width: 3,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1}: ${q['question']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your Answer: ${getUserAnswer()}',
                        style: TextStyle(
                          color: isSkipped
                              ? Colors.grey
                              : isCorrect
                                  ? const Color(0xFF22c55e)
                                  : const Color(0xFFef4444),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Correct Answer: ${getCorrectAnswer()}',
                        style: const TextStyle(
                          color: Color(0xFF22c55e),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (q['solution'] != null && q['solution'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFf8fafc),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Solution:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(q['solution']),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLeaderboardScreen() {
    final myAttempt = existingAttempt!;
    
    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: const Text('🏆 Leaderboard'),
        backgroundColor: const Color(0xFF8b5cf6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: backToResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.all(14),
                ),
                child: const Text('← Back to Result'),
              ),
            ),
            const SizedBox(height: 16),
            
            // User's Rank Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF22c55e), width: 2),
              ),
              color: const Color(0xFFf0fdf4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Rank: #$userRank',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text('Name: $userName'),
                    Text('Score: ${myAttempt['score']}/${myAttempt['total_questions']}'),
                    Text('Accuracy: ${myAttempt['percentage'].toStringAsFixed(2)}%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              '🏆 Leaderboard (Top 50)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Leaderboard List
            ...leaderboardData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final isCurrentUser = data['user_id'] == SupabaseService.currentUser?.id;
              final minutes = data['total_time_seconds'] ~/ 60;
              final seconds = data['total_time_seconds'] % 60;
              final percentage = ((data['score'] / data['total_questions']) * 100).toStringAsFixed(2);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isCurrentUser
                      ? const BorderSide(color: Color(0xFF22c55e), width: 2)
                      : BorderSide.none,
                ),
                color: isCurrentUser ? const Color(0xFFf0fdf4) : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rank #${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text('Name: ${data['name']} ${isCurrentUser ? '(તમે)' : ''}'),
                      Text('Score: ${data['score']}/${data['total_questions']}'),
                      Text('Accuracy: $percentage%'),
                      Text('Time: ${minutes}m ${seconds}s'),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}