import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  bool _isLoading = true;
  String _userName = 'Student';
  List<Map<String, dynamic>> _allResults = [];
  List<Map<String, dynamic>> _allAttempts = [];
  Map<String, dynamic> _overallData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load profile
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();
      
      _userName = profileResponse['full_name'] ?? 'Student';

      // Load quiz attempts
      final resultsResponse = await Supabase.instance.client
          .from('kls_quiz_attempts')
          .select('*')
          .eq('user_id', user.id)
          .order('completed_at', ascending: false);
      
      if (resultsResponse.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      
      _allResults = List<Map<String, dynamic>>.from(resultsResponse);

      // Load question attempts
      final resultIds = _allResults.map((r) => r['id']).toList();
      final attemptsResponse = await Supabase.instance.client
          .from('kls_question_attempts')
          .select('''
            *,
            kls_questions (
              *,
              kls_subjects (id, name, subject_code),
              kls_chapters (id, name, chapter_code)
            )
          ''')
          .filter('quiz_attempt_id', 'in', '(${resultIds.join(',')})');
      
      _allAttempts = List<Map<String, dynamic>>.from(attemptsResponse);

      _calculateOverallData();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _calculateOverallData() {
    int totalQuestions = 0, totalCorrect = 0, totalWrong = 0, totalSkipped = 0, totalTime = 0;
    
    for (var r in _allResults) {
      totalQuestions += (r['total_questions'] as int?) ?? 0;
      totalCorrect += (r['correct_answers'] as int?) ?? 0;
      totalWrong += (r['wrong_answers'] as int?) ?? 0;
      totalSkipped += (r['skipped_questions'] as int?) ?? 0;
      totalTime += (r['total_time_seconds'] as int?) ?? 0;
    }

    final overallPercentage = totalQuestions > 0 ? ((totalCorrect / totalQuestions) * 100) : 0.0;
    final avgTimePerQ = totalQuestions > 0 ? (totalTime / totalQuestions).floor() : 0;
    
    final Map<String, dynamic> subjectMap = {};
    
    for (var att in _allAttempts) {
      if (att['kls_questions'] == null || 
          att['kls_questions']['kls_subjects'] == null || 
          att['kls_questions']['kls_chapters'] == null) continue;
      
      final subjId = att['kls_questions']['kls_subjects']['id'].toString();
      final subjName = att['kls_questions']['kls_subjects']['name'];
      final chapterId = att['kls_questions']['kls_chapters']['id'].toString();
      final chapterName = att['kls_questions']['kls_chapters']['name'];
      
      if (!subjectMap.containsKey(subjId)) {
        subjectMap[subjId] = {
          'name': subjName,
          'total': 0,
          'correct': 0,
          'chapters': <String, dynamic>{},
        };
      }
      
      subjectMap[subjId]['total']++;
      if (att['is_correct'] == true) subjectMap[subjId]['correct']++;
      
      if (!subjectMap[subjId]['chapters'].containsKey(chapterId)) {
        subjectMap[subjId]['chapters'][chapterId] = {
          'name': chapterName,
          'total': 0,
          'correct': 0,
        };
      }
      
      subjectMap[subjId]['chapters'][chapterId]['total']++;
      if (att['is_correct'] == true) subjectMap[subjId]['chapters'][chapterId]['correct']++;
    }

    _overallData = {
      'totalQuestions': totalQuestions,
      'totalCorrect': totalCorrect,
      'totalWrong': totalWrong,
      'totalSkipped': totalSkipped,
      'totalTime': totalTime,
      'overallPercentage': overallPercentage,
      'avgTimePerQ': avgTimePerQ,
      'subjectMap': subjectMap,
      'level': _getPerformanceLevel(overallPercentage),
      'concentrationRating': _calculateConcentrationRating(avgTimePerQ, overallPercentage),
    };
  }

  String _getPerformanceLevel(double percentage) {
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

  String _calculateConcentrationRating(int avgTimePerQ, double accuracy) {
    if (accuracy <= 0) return "1.0";
    
    double rating = 10;
    
    if (avgTimePerQ > 10) rating -= 0.5;
    if (avgTimePerQ > 15) rating -= 1;
    if (avgTimePerQ > 20) rating -= 1;
    if (avgTimePerQ > 25) rating -= 1.5;
    if (avgTimePerQ > 30) rating -= 2;
    if (avgTimePerQ > 35) rating -= 3;
    
    if (accuracy < 90) rating -= 0.5;
    if (accuracy < 80) rating -= 1;
    if (accuracy < 70) rating -= 1.5;
    if (accuracy < 60) rating -= 2;
    if (accuracy < 50) rating -= 2;
    if (accuracy < 40) rating -= 2.5;
    if (accuracy < 30) rating -= 2.5;
    if (accuracy < 20) rating -= 3;
    if (accuracy < 10) rating -= 3;
    
    return (rating.clamp(1, 10)).toStringAsFixed(1);
  }

  Color _getPercentageColor(double per) {
    if (per >= 85) return const Color(0xFF22c55e);
    if (per >= 70) return const Color(0xFF10b981);
    if (per >= 55) return const Color(0xFF3b82f6);
    if (per >= 40) return const Color(0xFFf59e0b);
    return const Color(0xFFef4444);
  }

  Color _getLevelColor(String level) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _userName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Text(
              'તમારું Overall Performance',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        '⚠️ No Tests Found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'તમે હજુ સુધી કોઈ ટેસ્ટ આપી નથી',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildStudentCard(),
                        const SizedBox(height: 14),
                        _buildChartsGrid(),
                        const SizedBox(height: 14),
                        _buildStatsGrid(),
                        const SizedBox(height: 14),
                        _buildTrendChart(),
                        const SizedBox(height: 14),
                        _buildSubjectsSection(),
                        const SizedBox(height: 14),
                        ..._buildRecommendations(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStudentCard() {
    final firstLetter = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S';
    final level = _overallData['level'] ?? 'Initial';
    final levelColor = _getLevelColor(level);
    final lastTestDate = _allResults.isNotEmpty
        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(_allResults[0]['completed_at']))
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFf0f9ff), Color(0xFFe0f2fe)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFbae6fd), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3b82f6), Color(0xFF8b5cf6)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3b82f6).withOpacity(0.4),
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
                      _userName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1e293b),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetaBadge('📊 $level', levelColor, onTap: _showLevelInfo),
                        _buildMetaBadge('🏆 Rank: #1', const Color(0xFFf59e0b)),
                        _buildMetaBadge('📅 છેલ્લી: $lastTestDate', const Color(0xFF6366f1)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBadge(String text, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildChartsGrid() {
    return Column(
      children: [
        _buildOverallPieChart(),
        const SizedBox(height: 12),
        _buildSubjectPieChart(),
      ],
    );
  }

  Widget _buildOverallPieChart() {
    final totalCorrect = (_overallData['totalCorrect'] ?? 0);
    final totalWrong = (_overallData['totalWrong'] ?? 0);
    final totalSkipped = (_overallData['totalSkipped'] ?? 0);
    final total = totalCorrect + totalWrong + totalSkipped;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Overall પરિણામ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1f2937),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showChartInfo('overall'),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3b82f6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'i',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // PIE CHART
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: totalCorrect.toDouble(),
                    title: '${totalCorrect}',
                    color: const Color(0xFF22c55e),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: totalWrong.toDouble(),
                    title: '${totalWrong}',
                    color: const Color(0xFFef4444),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: totalSkipped.toDouble(),
                    title: '${totalSkipped}',
                    color: const Color(0xFF6b7280),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 15),
          // LEGEND
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegend('સાચા', const Color(0xFF22c55e)),
              _buildLegend('ખોટા', const Color(0xFFef4444)),
              _buildLegend('બાકી', const Color(0xFF6b7280)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSubjectPieChart() {
    final subjectMap = _overallData['subjectMap'] as Map<String, dynamic>? ?? {};
    
    if (subjectMap.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text('No data available'),
        ),
      );
    }

    final colors = [
      const Color(0xFF3b82f6),
      const Color(0xFF8b5cf6),
      const Color(0xFFec4899),
      const Color(0xFFf59e0b),
      const Color(0xFF10b981),
      const Color(0xFF06b6d4),
    ];

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    subjectMap.forEach((key, value) {
      final subjData = value as Map<String, dynamic>;
      final total = subjData['total'] as int;
      
      sections.add(
        PieChartSectionData(
          value: total.toDouble(),
          title: '${total}',
          color: colors[colorIndex % colors.length],
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'વિષય વાર વિતરણ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1f2937),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showChartInfo('subjects'),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3b82f6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'i',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Subject names legend
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: subjectMap.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final subjData = entry.value.value as Map<String, dynamic>;
              final subjName = subjData['name'] as String;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      subjName,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'label': 'કુલ પ્રશ્નો', 'value': '${_overallData['totalQuestions'] ?? 0}', 'color': const Color(0xFF1f2937)},
      {'label': 'મેળવેલ ગુણ', 'value': '${_overallData['totalCorrect'] ?? 0}', 'color': const Color(0xFF22c55e)},
      {'label': 'Overall ચોકસાઈ', 'value': '${(_overallData['overallPercentage'] ?? 0).toStringAsFixed(1)}%', 'color': const Color(0xFF3b82f6)},
      {'label': 'એકાગ્રતા રેટિંગ ℹ️', 'value': '${_overallData['concentrationRating'] ?? '0.0'}/10', 'color': const Color(0xFFf59e0b), 'onTap': _showConcentrationInfo},
      {'label': 'સમય/પ્રશ્ન', 'value': '${_overallData['avgTimePerQ'] ?? 0}s', 'color': const Color(0xFF1f2937)},
      {'label': 'ખોટા જવાબ', 'value': '${_overallData['totalWrong'] ?? 0}', 'color': const Color(0xFFef4444)},
      {'label': 'Target Score', 'value': '80% (${(_overallData['overallPercentage'] ?? 0).toStringAsFixed(1)}%)', 'color': (_overallData['overallPercentage'] ?? 0) >= 80 ? const Color(0xFF22c55e) : const Color(0xFFef4444)},
      {'label': 'બાકી પ્રશ્નો', 'value': '${_overallData['totalSkipped'] ?? 0}', 'color': const Color(0xFF1f2937)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return GestureDetector(
          onTap: stat['onTap'] as VoidCallback?,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFf8fafc),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stat['label'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6b7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: stat['color'] as Color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendChart() {
    final last5 = _allResults.take(5).toList().reversed.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'તમારી પ્રગતિ (છેલ્લી 5 ટેસ્ટ)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1f2937),
            ),
          ),
          const SizedBox(height: 20),
          ...last5.asMap().entries.map((entry) {
            final index = entry.key;
            final result = entry.value;
            final percentage = (result['percentage'] ?? 0.0).toDouble();
            final testNum = index + 1;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Test $testNum',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1f2937),
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getPercentageColor(percentage),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: const Color(0xFFe5e7eb),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getPercentageColor(percentage),
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSubjectsSection() {
    final subjectMap = _overallData['subjectMap'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 વિષય વાર Overall Analysis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1f2937),
            ),
          ),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: subjectMap.length,
            itemBuilder: (context, index) {
              final entry = subjectMap.entries.elementAt(index);
              final subjId = entry.key;
              final subjData = entry.value as Map<String, dynamic>;
              final subjName = subjData['name'] as String;
              final total = subjData['total'] as int;
              final correct = subjData['correct'] as int;
              final subjPer = total > 0 ? ((correct / total) * 100) : 0.0;
              final subjPerColor = _getPercentageColor(subjPer);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFf8fafc),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      subjName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1f2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: subjPer / 100,
                        backgroundColor: const Color(0xFFe5e7eb),
                        valueColor: AlwaysStoppedAnimation<Color>(subjPerColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${subjPer.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: subjPerColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showChapterDetails(subjId, subjName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3b82f6),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'View Full',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecommendations() {
    final List<Widget> recCards = [];
    final overallPercentage = _overallData['overallPercentage'] ?? 0.0;
    final subjectMap = _overallData['subjectMap'] as Map<String, dynamic>? ?? {};

    // Study Time Recommendation
    if (overallPercentage < 85) {
      final studyHours = overallPercentage < 50 ? '12-14' : 
                         overallPercentage < 70 ? '10-12' : '8-10';
      recCards.add(_buildRecCard(
        '📚 દૈનિક અભ્યાસ સમય ભલામણ',
        [
          'દરરોજ ઓછામાં ઓછા $studyHours કલાક અભ્યાસ કરો',
          'સવારે 4-5 કલાક, બપોરે 3-4 કલાક અને સાંજે 3-4 કલાક',
          'દર 1.5-2 કલાકે 15 મિનિટ નો break લો',
          'શાંત વાતાવરણમાં focused study કરો',
        ],
        const Color(0xFF1e3a8a),
      ));
    }

    // Subject-wise recommendations
    for (var entry in subjectMap.entries) {
      final subjData = entry.value as Map<String, dynamic>;
      final subjName = subjData['name'] as String;
      final total = subjData['total'] as int;
      final correct = subjData['correct'] as int;
      final subjPer = total > 0 ? ((correct / total) * 100) : 0.0;

      if (subjPer < 60) {
        recCards.add(_buildRecCard(
          '🔴 $subjName - તાત્કાલિક ધ્યાન આપો',
          [
            'દરરોજ 50-60 પ્રશ્નો practice કરો',
            'બેસિક concepts મજબૂત કરો',
            'Previous year ના પ્રશ્નો વારંવાર ઉકેલો',
            'Mock tests નિયમિત લો',
          ],
          const Color(0xFF1e3a8a),
        ));
      } else if (subjPer >= 60 && subjPer < 80) {
        recCards.add(_buildRecCard(
          '🟡 $subjName - સારું પ્રદર્શન, થોડો વધુ પ્રયાસ',
          [
            'મુશ્કેલ સવાલો પર વધુ પ્રેક્ટિસ કરો',
            'Speed અને accuracy બંને પર કામ કરો',
            'Time management સુધારો',
          ],
          const Color(0xFF1e3a8a),
        ));
      }
    }

    // KAPiLa Institute Ad
    recCards.add(_buildRecCard(
      '🎓 KAPiLa Institute',
      [
        'તમારી સફળતા અમારો ધ્યેય - KAPiLa Institute તમને શ્રેષ્ઠ તૈયારી પ્રદાન કરે છે',
        'અનુભવી શિક્ષકો, comprehensive study material અને regular mock tests',
        'Individual attention અને personalized guidance દરેક વિદ્યાર્થી માટે',
        'આપના સપનાને સાકાર કરવા માટે અમે તૈયાર છીએ',
        '📞 સંપર્ક કરો અને તમારી તૈયારી શરૂ કરો!',
      ],
      const Color(0xFF059669),
    ));

    return recCards;
  }

  Widget _buildRecCard(String title, List<String> items, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✓ ',
                      style: TextStyle(
                        color: Color(0xFF22c55e),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showChartInfo(String type) {
    final messages = {
      'overall': 'આ chart તમારા બધા tests નો combined પરિણામ બતાવે છે - સાચા, ખોટા અને બાકી પ્રશ્નો.',
      'subjects': 'આ ચાર્ટ બતાવે છે કે તમારા overall performance માંથી કયા વિષય કેટલા ટકા છે. તમને જે આવડે છે એમાંથી કયો વિષય તમને વધારે આવડે છે.',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'overall' ? 'Overall પરિણામ' : 'વિષય વાર વિતરણ'),
        content: Text(messages[type] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('બંધ કરો'),
          ),
        ],
      ),
    );
  }

  void _showConcentrationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('એકાગ્રતા રેટિંગ'),
        content: const Text(
          'આ રેટિંગ તમારી સ્પીડ અને ચોકસાઈ બંને પર આધારિત છે.\n\n'
          'જો તમે બધા પ્રશ્નો સાચા કરો પણ વધુ સમય લો તો, એકાગ્રતા તમારી ઓછી જ ગણાશે. '
          'ઝડપ અને ચોકસાઈ ઉપર એકાગ્રતાનું માપન થાય છે.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('બંધ કરો'),
          ),
        ],
      ),
    );
  }

  void _showLevelInfo() {
    final levels = [
      {'name': 'Initial', 'range': '1-10%', 'color': const Color(0xFFef4444)},
      {'name': 'Starter', 'range': '11-20%', 'color': const Color(0xFFf97316)},
      {'name': 'Good', 'range': '21-30%', 'color': const Color(0xFFf59e0b)},
      {'name': 'Better', 'range': '31-40%', 'color': const Color(0xFFeab308)},
      {'name': 'Nice', 'range': '41-50%', 'color': const Color(0xFF84cc16)},
      {'name': 'Very Good', 'range': '51-60%', 'color': const Color(0xFF22c55e)},
      {'name': 'Very Nice', 'range': '61-70%', 'color': const Color(0xFF10b981)},
      {'name': 'Excellent', 'range': '71-80%', 'color': const Color(0xFF14b8a6)},
      {'name': 'Excellent+', 'range': '81-90%', 'color': const Color(0xFF06b6d4)},
      {'name': 'Perfect', 'range': '91-100%', 'color': const Color(0xFF8b5cf6)},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Levels'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('તમારા પ્રદર્શનના આધારે levels:'),
              const SizedBox(height: 10),
              ...levels.map((level) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf8fafc),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: level['color'] as Color,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            level['name'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          level['range'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748b),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('બંધ કરો'),
          ),
        ],
      ),
    );
  }

  void _showChapterDetails(String subjId, String subjName) {
    final subjectMap = _overallData['subjectMap'] as Map<String, dynamic>? ?? {};
    final subjData = subjectMap[subjId] as Map<String, dynamic>?;
    
    if (subjData == null) return;

    final chapters = subjData['chapters'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$subjName - Chapter-wise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: chapters.entries.map((entry) {
              final chData = entry.value as Map<String, dynamic>;
              final chName = chData['name'] as String;
              final total = chData['total'] as int;
              final correct = chData['correct'] as int;
              final chPer = total > 0 ? ((correct / total) * 100) : 0.0;
              final chPerColor = _getPercentageColor(chPer);

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFe5e7eb), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        chName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    Text(
                      '${chPer.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: chPerColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('બંધ કરો'),
          ),
        ],
      ),
    );
  }
}