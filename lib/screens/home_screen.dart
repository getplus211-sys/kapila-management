import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:ui';
import 'theme_provider.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'faq_screen.dart';
import 'terms_conditions_screen.dart';
import 'chapters_screen.dart';
import 'user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blocks   = [];
  List<Map<String, dynamic>> _subjects = [];
  String _userName = '';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final Map<String, Map<String, dynamic>> _subjectConfig = {
    'GUJARATI_GRAMMAR':   {'emoji': '📝', 'colors': [Color(0xFF06b6d4), Color(0xFF0891b2)], 'section': 'gujarat'},
    'GUJARATI_SAHITYA':   {'emoji': '📚', 'colors': [Color(0xFFd946ef), Color(0xFFc026d3)], 'section': 'gujarat'},
    'GUJARAT_HISTORY':    {'emoji': '🏰', 'colors': [Color(0xFF22c55e), Color(0xFF16a34a)], 'section': 'gujarat'},
    'GUJARAT_CULTURE':    {'emoji': '🪔', 'colors': [Color(0xFF14b8a6), Color(0xFF0d9488)], 'section': 'gujarat'},
    'GUJARAT_GEOGRAPHY':  {'emoji': '🌍', 'colors': [Color(0xFF3b82f6), Color(0xFF2563eb)], 'section': 'gujarat'},
    'MATHS':              {'emoji': '📐', 'colors': [Color(0xFFef4444), Color(0xFFdc2626)], 'section': 'core'},
    'REASONING':          {'emoji': '🧠', 'colors': [Color(0xFFf97316), Color(0xFFea580c)], 'section': 'core'},
    'DATA_INTERPRETATION':{'emoji': '📊', 'colors': [Color(0xFFf43f5e), Color(0xFFe11d48)], 'section': 'core'},
    'INDIAN_HISTORY':     {'emoji': '🏛️', 'colors': [Color(0xFF84cc16), Color(0xFF65a30d)], 'section': 'india'},
    'INDIAN_CULTURE':     {'emoji': '🎭', 'colors': [Color(0xFF10b981), Color(0xFF059669)], 'section': 'india'},
    'INDIAN_GEOGRAPHY':   {'emoji': '🗺️', 'colors': [Color(0xFF0ea5e9), Color(0xFF0284c7)], 'section': 'india'},
    'CONSTITUTION':       {'emoji': '⚖️', 'colors': [Color(0xFFf59e0b), Color(0xFFd97706)], 'section': 'other'},
    'INDIAN_ECONOMY':     {'emoji': '💰', 'colors': [Color(0xFF6366f1), Color(0xFF4f46e5)], 'section': 'other'},
    'ENGLISH_GRAMMAR':    {'emoji': '🅰️', 'colors': [Color(0xFFa855f7), Color(0xFF9333ea)], 'section': 'other'},
    'GENERAL_SCIENCE':    {'emoji': '🔬', 'colors': [Color(0xFF8b5cf6), Color(0xFF7c3aed)], 'section': 'other'},
    'SCIENCE_AND_TECH':   {'emoji': '🚀', 'colors': [Color(0xFFec4899), Color(0xFFdb2777)], 'section': 'other'},
    'CURRENT_AFFAIRS':    {'emoji': '📰', 'colors': [Color(0xFFef4444), Color(0xFFdc2626)], 'section': 'other'},
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final p = await Supabase.instance.client
            .from('profiles').select('full_name').eq('id', user.id).single();
        _userName = p['full_name'] ?? user.email?.split('@')[0] ?? 'Student';
      }
      final b = await Supabase.instance.client
          .from('app_home_blocks').select('*').eq('is_active', true).order('display_order');
      final s = await Supabase.instance.client
          .from('kls_subjects').select('*').order('created_at');

      setState(() {
        _blocks   = List<Map<String, dynamic>>.from(b);
        _subjects = List<Map<String, dynamic>>.from(s);
        _isLoading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleMenuSelection(String value) async {
    final routes = {
      'about':   () => const AboutUsScreen(),
      'privacy': () => const PrivacyPolicyScreen(),
      'terms':   () => const TermsConditionsScreen(),
      'contact': () => const ContactUsScreen(),
      'faq':     () => const FaqScreen(),
    };
    if (value == 'logout') {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    } else if (routes.containsKey(value)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => routes[value]!()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: t.bg,
        extendBody: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: t.bgGradient,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(t),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: t.brand))
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: RefreshIndicator(
                            onRefresh: _loadData,
                            color: t.brand,
                            backgroundColor: t.surface,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                              itemCount: _blocks.length,
                              itemBuilder: (ctx, i) => _buildBlock(_blocks[i], t),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════
  //  TOP BAR
  // ════════════════════════════════
  Widget _buildTopBar(ThemeProvider t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _iconBtn(Icons.settings_outlined, t, () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                userId: Supabase.instance.client.auth.currentUser?.id ?? '',
              ),
            ));
          }),
          const SizedBox(width: 12),
          _iconBtn(Icons.search_rounded, t, () {}),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: t.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_rounded, color: t.brand, size: 18),
                const SizedBox(width: 8),
                Text('KAPiLa', style: TextStyle(
                  color: t.text1, fontSize: 14,
                  fontWeight: FontWeight.w800, letterSpacing: 1.2,
                )),
              ],
            ),
          ),
          const Spacer(),
          _iconBtn(Icons.notifications_outlined, t, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          }),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            color: t.surface2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: t.border),
            ),
            onSelected: _handleMenuSelection,
            itemBuilder: (_) => [
              _menuItem('about',   Icons.info_outline,             'About Us',          t),
              _menuItem('privacy', Icons.privacy_tip_outlined,     'Privacy Policy',    t),
              _menuItem('terms',   Icons.article_outlined,         'Terms & Conditions',t),
              _menuItem('contact', Icons.contact_support_outlined, 'Contact Us',        t),
              _menuItem('faq',     Icons.help_outline,             'FAQ',               t),
              const PopupMenuDivider(),
              _menuItem('logout',  Icons.logout,                   'Logout',            t, isRed: true),
            ],
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
              child: Icon(Icons.menu_rounded, color: t.text1, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, String label, ThemeProvider t, {bool isRed = false}) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, color: isRed ? Colors.redAccent : t.accent, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: isRed ? Colors.redAccent : t.text1, fontSize: 13)),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, ThemeProvider t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Icon(icon, color: t.text1, size: 20),
      ),
    );
  }

  // ════════════════════════════════
  //  BLOCK ROUTER
  // ════════════════════════════════
  Widget _buildBlock(Map<String, dynamic> block, ThemeProvider t) {
    final type = block['block_type'] ?? '';
    final name = block['block_name'] ?? '';
    final data = block['block_data'] is String
        ? jsonDecode(block['block_data']) as Map<String, dynamic>
        : block['block_data'] as Map<String, dynamic>;

    if (type == 'widget' && name == 'subject_cards') return _buildSubjectCardsWidget(t);

    switch (type) {
      case 'welcome':      return _buildWelcomeCard(data, t);
      case 'quick_links':  return _buildQuickLinks(data, t);
      case 'subjects':     return _buildSubjects(data, t);
      case 'announcement': return _buildAnnouncement(data, t);
      case 'html':
        if (name.contains('_title')) {
          return _sectionTitle(_extractTitle(data['html'] ?? ''), t);
        }
        return const SizedBox.shrink();
      default: return const SizedBox.shrink();
    }
  }

  String _extractTitle(String html) {
    final m = RegExp(r'>([^<]+)</').firstMatch(html);
    return m?.group(1) ?? '';
  }

  // ════════════════════════════════
  //  WELCOME CARD
  // ════════════════════════════════
  Widget _buildWelcomeCard(Map<String, dynamic> data, ThemeProvider t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: t.isDark
              ? [const Color(0xFF1C1A3A), const Color(0xFF0F1628)]
              : [Colors.white.withOpacity(0.9), t.brand.withOpacity(0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.brand.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: t.brand.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'નમસ્તે, ${_userName.isNotEmpty ? _userName.split(' ').first : 'Student'} 👋',
            style: TextStyle(color: t.text2, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(data['title'] ?? 'KAPILA Learning',
              style: TextStyle(color: t.text1, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(data['subtitle'] ?? '',
              style: TextStyle(color: t.text2, fontSize: 12)),
        ])),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [t.brand, const Color(0xFF6B3FC6)]),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
        ),
      ]),
    );
  }

  // ════════════════════════════════
  //  SUBJECT CARDS GRID
  // ════════════════════════════════
  Widget _buildSubjectCardsWidget(ThemeProvider t) {
    if (_subjects.isEmpty) return const SizedBox.shrink();

    final map = <String, List<Map<String, dynamic>>>{
      'gujarat': [], 'core': [], 'india': [], 'other': [],
    };

    for (var s in _subjects) {
      final code   = s['subject_code'] ?? '';
      final config = _subjectConfig[code];
      if (config != null) {
        final sec = config['section'] as String;
        map[sec]?.add({...s, 'emoji': config['emoji'], 'colors': config['colors']});
      }
    }

    Widget grid(List<Map<String, dynamic>> items) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.55,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildSubjectCard(items[i], t),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (map['gujarat']!.isNotEmpty) ...[_sectionTitle('📚 ગુજરાત સંબંધિત', t), grid(map['gujarat']!), const SizedBox(height: 8)],
        if (map['core']!.isNotEmpty)    ...[_sectionTitle('🔢 કોર સબ્જેક્ટ્સ',  t), grid(map['core']!),   const SizedBox(height: 8)],
        if (map['india']!.isNotEmpty)   ...[_sectionTitle('🇮🇳 ભારત સંબંધિત',   t), grid(map['india']!),  const SizedBox(height: 8)],
        if (map['other']!.isNotEmpty)   ...[_sectionTitle('⚖️ અન્ય વિષયો',       t), grid(map['other']!),  const SizedBox(height: 8)],
      ],
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, ThemeProvider t) {
    final colors = subject['colors'] as List<Color>? ?? [const Color(0xFF3b82f6), const Color(0xFF2563eb)];
    final emoji  = subject['emoji'] as String? ?? '📚';
    final name   = subject['name']  as String? ?? '';
    final id     = subject['id']    as String? ?? '';

    return _GlassCard(
      colors: colors, emoji: emoji, name: name, t: t,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChaptersScreen(
          subjectId: id, subjectName: name,
          subjectEmoji: emoji, gradientColors: colors,
        ),
      )),
    );
  }

  // ════════════════════════════════
  //  QUICK LINKS
  // ════════════════════════════════
  Widget _buildQuickLinks(Map<String, dynamic> data, ThemeProvider t) {
    final links = data['links'] as List? ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((data['title'] as String?)?.isNotEmpty == true) _sectionTitle(data['title'], t),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55,
            ),
            itemCount: links.length,
            itemBuilder: (_, i) {
              final lnk = links[i];
              return GestureDetector(
                onTap: () => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Opening ${lnk['name']}'))),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(lnk['icon'] ?? '📚', style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(lnk['name'] ?? '',
                        style: TextStyle(color: t.text1, fontSize: 13, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════
  //  SUBJECTS LIST
  // ════════════════════════════════
  Widget _buildSubjects(Map<String, dynamic> data, ThemeProvider t) {
    final items = data['items'] as List? ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((data['title'] as String?)?.isNotEmpty == true)
            Text(data['title'],
                style: TextStyle(color: t.text1, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final s = items[i];
              final c = _parseColor(s['color'] ?? '#7B4FD6');
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(left: BorderSide(color: c, width: 3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(s['name'] ?? '',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c)),
                  Text(s['nameEn'] ?? '',
                      style: TextStyle(fontSize: 11, color: t.text2)),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════
  //  ANNOUNCEMENT
  // ════════════════════════════════
  Widget _buildAnnouncement(Map<String, dynamic> data, ThemeProvider t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.isDark ? const Color(0xFF1A1500) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.campaign_rounded, color: Color(0xFFF59E0B), size: 28),
        const SizedBox(width: 10),
        Expanded(child: Text(data['message'] ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFFFBBF24), fontWeight: FontWeight.w500))),
      ]),
    );
  }

  // ════════════════════════════════
  //  SECTION TITLE
  // ════════════════════════════════
  Widget _sectionTitle(String title, ThemeProvider t) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(children: [
        Container(width: 3, height: 18,
            decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
            color: t.text1, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      ]),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

// ════════════════════════════════════════════════════════
//  💎 GLASS CARD — theme-aware
// ════════════════════════════════════════════════════════
class _GlassCard extends StatefulWidget {
  final List<Color> colors;
  final String emoji;
  final String name;
  final ThemeProvider t;
  final VoidCallback onTap;

  const _GlassCard({
    required this.colors, required this.emoji,
    required this.name,   required this.t, required this.onTap,
  });

  @override
  State<_GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<_GlassCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t  = widget.t;
    final c1 = widget.colors[0];
    final c2 = widget.colors.length > 1 ? widget.colors[1] : c1;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: t.surface,
            border: Border.all(color: t.border),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(t.isDark ? 0.3 : 0.08),
              blurRadius: 10, offset: const Offset(0, 4),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              // Left accent bar
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c1, c2],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // Glow top-right
              Positioned(
                right: -20, top: -20,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [c1.withOpacity(0.18), Colors.transparent]),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [c1.withOpacity(0.25), c2.withOpacity(0.15)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: c1.withOpacity(0.3)),
                      ),
                      child: Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.name,
                            style: TextStyle(
                              color: t.text1, fontSize: 13,
                              fontWeight: FontWeight.w700, height: 1.3,
                            ),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Row(children: [
                          Text('Start', style: TextStyle(color: c1, fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded, size: 9, color: c1),
                        ]),
                      ],
                    )),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}