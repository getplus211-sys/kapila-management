import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/chapter.dart';
import '../models/quiz.dart';
import 'quiz_engine_screen.dart';

class ChaptersScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String subjectEmoji;
  final List<Color> gradientColors;

  const ChaptersScreen({
    Key? key,
    required this.subjectId,
    required this.subjectName,
    required this.subjectEmoji,
    required this.gradientColors,
  }) : super(key: key);

  @override
  State<ChaptersScreen> createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  List<Chapter> chapters = [];
  List<Quiz> quizzes = [];
  String? selectedChapterCode;
  String? selectedChapterName;
  bool isLoadingChapters = true;
  bool isLoadingQuizzes = false;

  @override
  void initState() {
    super.initState();
    loadChapters();
  }

  Future<void> loadChapters() async {
    setState(() => isLoadingChapters = true);
    
    try {
      final data = await SupabaseService.getChaptersBySubject(widget.subjectId);
      
      setState(() {
        chapters = data.map((json) => Chapter.fromJson(json)).toList();
        isLoadingChapters = false;
      });
      
      // Auto-select first chapter
      if (chapters.isNotEmpty) {
        selectChapter(chapters[0].chapterCode, chapters[0].name);
      }
    } catch (e) {
      print('Error loading chapters: $e');
      setState(() => isLoadingChapters = false);
    }
  }

  Future<void> selectChapter(String chapterCode, String chapterName) async {
    setState(() {
      selectedChapterCode = chapterCode;
      selectedChapterName = chapterName;
      isLoadingQuizzes = true;
    });
    
    await loadQuizzes(chapterCode);
  }

  Future<void> loadQuizzes(String chapterCode) async {
    try {
      final data = await SupabaseService.getQuizzesByChapter(chapterCode);
      
      setState(() {
        quizzes = data.map((json) => Quiz.fromJson(json)).toList();
        isLoadingQuizzes = false;
      });
    } catch (e) {
      print('Error loading quizzes: $e');
      setState(() => isLoadingQuizzes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(widget.gradientColors[0].value).withOpacity(0.1),
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.gradientColors[0].withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.subjectEmoji} ${widget.subjectName}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'KAPiLa Learning',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  
                  // Chapters horizontal scroll
                  if (isLoadingChapters)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else if (chapters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No chapters found',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  else
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = chapters[index];
                          final isSelected = selectedChapterCode == chapter.chapterCode;
                          
                          return GestureDetector(
                            onTap: () => selectChapter(chapter.chapterCode, chapter.name),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'પ્રકરણ ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? widget.gradientColors[1] : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Chapter title
          if (selectedChapterName != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.gradientColors[0].withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradientColors[0].withOpacity(0.2),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Text(
                selectedChapterName!,
                style: TextStyle(
                  fontSize: 18,
                  color: widget.gradientColors[1],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          
          // Quizzes list
          Expanded(
            child: isLoadingQuizzes
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('લોડિંગ થઈ રહ્યું છે...'),
                      ],
                    ),
                  )
                : quizzes.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'આ પ્રકરણમાં કોઈ quiz નથી',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Quiz જલ્દી LIVE થશે',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: quizzes.length,
                        itemBuilder: (context, index) {
                          final quiz = quizzes[index];
                          return _buildQuizCard(quiz);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(Quiz quiz) {
    Color badgeColor;
    if (quiz.difficultyLevel == 'સરળ') {
      badgeColor = const Color(0xFF22c55e);
    } else if (quiz.difficultyLevel == 'મધ્યમ') {
      badgeColor = const Color(0xFFf59e0b);
    } else {
      badgeColor = const Color(0xFFef4444);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizEngineScreen(quizId: quiz.quizId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.gradientColors[0].withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.gradientColors[0].withOpacity(0.15),
              blurRadius: 15,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    quiz.quizName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.gradientColors[1],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quiz.difficultyLevel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.quiz, size: 16, color: Color(0xFF3f6212)),
                const SizedBox(width: 6),
                Text(
                  '${quiz.totalQuestions} પ્રશ્નો',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF3f6212)),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.timer, size: 16, color: Color(0xFF3f6212)),
                const SizedBox(width: 6),
                Text(
                  '${quiz.timeLimit} મિનિટ',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF3f6212)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}