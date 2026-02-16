import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'faq_screen.dart';
import 'terms_conditions_screen.dart';
import 'chapters_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blocks = [];
  List<Map<String, dynamic>> _subjects = []; // Dynamic subjects from database
  String _userName = '';

  // Subject colors and emojis mapping by subject_code
  final Map<String, Map<String, dynamic>> _subjectConfig = {
    'GUJARATI_GRAMMAR': {'emoji': '📝', 'colors': [Color(0xFF06b6d4), Color(0xFF0891b2)], 'section': 'gujarat'},
    'GUJARATI_SAHITYA': {'emoji': '📚', 'colors': [Color(0xFFd946ef), Color(0xFFc026d3)], 'section': 'gujarat'},
    'GUJARAT_HISTORY': {'emoji': '🏰', 'colors': [Color(0xFF22c55e), Color(0xFF16a34a)], 'section': 'gujarat'},
    'GUJARAT_CULTURE': {'emoji': '🪔', 'colors': [Color(0xFF14b8a6), Color(0xFF0d9488)], 'section': 'gujarat'},
    'GUJARAT_GEOGRAPHY': {'emoji': '🌍', 'colors': [Color(0xFF3b82f6), Color(0xFF2563eb)], 'section': 'gujarat'},
    'MATHS': {'emoji': '📐', 'colors': [Color(0xFFef4444), Color(0xFFdc2626)], 'section': 'core'},
    'REASONING': {'emoji': '🧠', 'colors': [Color(0xFFf97316), Color(0xFFea580c)], 'section': 'core'},
    'DATA_INTERPRETATION': {'emoji': '📊', 'colors': [Color(0xFFf43f5e), Color(0xFFe11d48)], 'section': 'core'},
    'INDIAN_HISTORY': {'emoji': '🏛️', 'colors': [Color(0xFF84cc16), Color(0xFF65a30d)], 'section': 'india'},
    'INDIAN_CULTURE': {'emoji': '🎭', 'colors': [Color(0xFF10b981), Color(0xFF059669)], 'section': 'india'},
    'INDIAN_GEOGRAPHY': {'emoji': '🗺️', 'colors': [Color(0xFF0ea5e9), Color(0xFF0284c7)], 'section': 'india'},
    'CONSTITUTION': {'emoji': '⚖️', 'colors': [Color(0xFFf59e0b), Color(0xFFd97706)], 'section': 'other'},
    'INDIAN_ECONOMY': {'emoji': '💰', 'colors': [Color(0xFF6366f1), Color(0xFF4f46e5)], 'section': 'other'},
    'ENGLISH_GRAMMAR': {'emoji': '🅰️', 'colors': [Color(0xFFa855f7), Color(0xFF9333ea)], 'section': 'other'},
    'GENERAL_SCIENCE': {'emoji': '🔬', 'colors': [Color(0xFF8b5cf6), Color(0xFF7c3aed)], 'section': 'other'},
    'SCIENCE_AND_TECH': {'emoji': '🚀', 'colors': [Color(0xFFec4899), Color(0xFFdb2777)], 'section': 'other'},
    'CURRENT_AFFAIRS': {'emoji': '📰', 'colors': [Color(0xFFef4444), Color(0xFFdc2626)], 'section': 'other'},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();
        _userName = profileResponse['full_name'] ?? user.email?.split('@')[0] ?? 'Student';
      }

      // Load blocks
      final blocksResponse = await Supabase.instance.client
          .from('app_home_blocks')
          .select('*')
          .eq('is_active', true)
          .order('display_order');

      // Load subjects from database
      final subjectsResponse = await Supabase.instance.client
          .from('kls_subjects')
          .select('*')
          .order('created_at');

      setState(() {
        _blocks = List<Map<String, dynamic>>.from(blocksResponse);
        _subjects = List<Map<String, dynamic>>.from(subjectsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleMenuSelection(String value) async {
    if (value == 'logout') {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } else if (value == 'about') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AboutUsScreen()),
      );
    } else if (value == 'privacy') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
      );
    } else if (value == 'terms') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
      );
    } else if (value == 'contact') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ContactUsScreen()),
      );
    } else if (value == 'faq') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FaqScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KAPILA Learning',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              'Digital Learning Platform',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1F2937)),
                    SizedBox(width: 12),
                    Text('About Us'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: Color(0xFF1F2937)),
                    SizedBox(width: 12),
                    Text('Privacy Policy'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'terms',
                child: Row(
                  children: [
                    Icon(Icons.article_outlined, color: Color(0xFF1F2937)),
                    SizedBox(width: 12),
                    Text('Terms & Conditions'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'contact',
                child: Row(
                  children: [
                    Icon(Icons.contact_support_outlined, color: Color(0xFF1F2937)),
                    SizedBox(width: 12),
                    Text('Contact Us'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'faq',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Color(0xFF1F2937)),
                    SizedBox(width: 12),
                    Text('FAQ'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blocks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'કોઈ content નથી',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blocks.length,
                    itemBuilder: (context, index) {
                      final block = _blocks[index];
                      return _buildBlock(block);
                    },
                  ),
                ),
    );
  }

  Widget _buildBlock(Map<String, dynamic> block) {
    final String blockType = block['block_type'] ?? '';
    final String blockName = block['block_name'] ?? '';
    final Map<String, dynamic> blockData = block['block_data'] is String
        ? jsonDecode(block['block_data'])
        : block['block_data'];

    // Subject Cards Widget (Special widget for all subjects)
    if (blockType == 'widget' && blockName == 'subject_cards') {
      return _buildSubjectCardsWidget();
    }

    switch (blockType) {
      case 'welcome':
        return _buildWelcomeCard(blockData);
      case 'quick_links':
        return _buildQuickLinks(blockData);
      case 'subjects':
        return _buildSubjects(blockData);
      case 'announcement':
        return _buildAnnouncement(blockData);
      case 'html':
        // For HTML blocks, show title if it's a title block
        if (blockName.contains('_title')) {
          String title = _extractTitle(blockData['html'] ?? '');
          return Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1f2937),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  String _extractTitle(String html) {
    RegExp exp = RegExp(r'>([^<]+)</');
    var match = exp.firstMatch(html);
    return match?.group(1) ?? '';
  }

  // Build Subject Cards Widget with all subjects organized by sections
  Widget _buildSubjectCardsWidget() {
    if (_subjects.isEmpty) {
      return const Center(child: Text('કોઈ subjects નથી'));
    }

    // Organize subjects by section
    final gujaratSubjects = <Map<String, dynamic>>[];
    final coreSubjects = <Map<String, dynamic>>[];
    final indiaSubjects = <Map<String, dynamic>>[];
    final otherSubjects = <Map<String, dynamic>>[];

    for (var subject in _subjects) {
      final subjectCode = subject['subject_code'] ?? '';
      final config = _subjectConfig[subjectCode];
      
      if (config != null) {
        final section = config['section'];
        final subjectWithConfig = {
          ...subject,
          'emoji': config['emoji'],
          'colors': config['colors'],
        };
        
        if (section == 'gujarat') {
          gujaratSubjects.add(subjectWithConfig);
        } else if (section == 'core') {
          coreSubjects.add(subjectWithConfig);
        } else if (section == 'india') {
          indiaSubjects.add(subjectWithConfig);
        } else {
          otherSubjects.add(subjectWithConfig);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ગુજરાત સંબંધિત
        if (gujaratSubjects.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 16, left: 4),
            child: Text(
              '📚 ગુજરાત સંબંધિત વિષયો',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1f2937),
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: gujaratSubjects.length,
            itemBuilder: (context, index) => _buildSubjectCard(gujaratSubjects[index]),
          ),
        ],
        
        // કોર સબ્જેક્ટ્સ
        if (coreSubjects.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 24, bottom: 16, left: 4),
            child: Text(
              '🔢 કોર સબ્જેક્ટ્સ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1f2937),
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: coreSubjects.length,
            itemBuilder: (context, index) => _buildSubjectCard(coreSubjects[index]),
          ),
        ],
        
        // ભારત સંબંધિત
        if (indiaSubjects.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 24, bottom: 16, left: 4),
            child: Text(
              '🇮🇳 ભારત સંબંધિત વિષયો',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1f2937),
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: indiaSubjects.length,
            itemBuilder: (context, index) => _buildSubjectCard(indiaSubjects[index]),
          ),
        ],
        
        // અન્ય મહત્વના
        if (otherSubjects.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 24, bottom: 16, left: 4),
            child: Text(
              '⚖️ અન્ય મહત્વના વિષયો',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1f2937),
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: otherSubjects.length,
            itemBuilder: (context, index) => _buildSubjectCard(otherSubjects[index]),
          ),
        ],
      ],
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final List<Color> colors = subject['colors'] ?? [Color(0xFF3b82f6), Color(0xFF2563eb)];
    final String emoji = subject['emoji'] ?? '📚';
    final String name = subject['name'] ?? '';
    final String id = subject['id'] ?? '';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChaptersScreen(
              subjectId: id,
              subjectName: name,
              subjectEmoji: emoji,
              gradientColors: colors,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['subtitle'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinks(Map<String, dynamic> data) {
    final List links = data['links'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['title'] ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: links.length,
            itemBuilder: (context, index) {
              final link = links[index];
              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening ${link['name']}')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        link['icon'] ?? '📚',
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        link['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubjects(Map<String, dynamic> data) {
    final List subjects = data['items'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['title'] ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.5,
            ),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final color = _parseColor(subject['color'] ?? '#3b82f6');

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: color, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      subject['name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject['nameEn'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
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

  Widget _buildAnnouncement(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: Color(0xFFD97706), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data['message'] ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}