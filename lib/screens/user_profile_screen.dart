import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'theme_provider.dart';
import 'edit_profile_screen.dart';
import 'my_posts_screen.dart';
import 'followers_screen.dart';
import 'blocked_users_screen.dart';
import 'login_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _ngmUser;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('ngm_users')
            .select('*')
            .eq('user_id', widget.userId)
            .maybeSingle(),
        Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', widget.userId)
            .maybeSingle(),
      ]);

      // ✅ FIX: posts_count — fetch actual count if column is 0/null
      Map<String, dynamic>? ngmUser = results[0] as Map<String, dynamic>?;
      if (ngmUser != null && (ngmUser['posts_count'] ?? 0) == 0) {
        final countRes = await Supabase.instance.client
            .from('ngm_user_posts')
            .select('post_id')
            .eq('user_id', widget.userId);
        ngmUser = {...ngmUser, 'posts_count': (countRes as List).length};
      }

      setState(() {
        _ngmUser  = ngmUser;
        _profile  = results[1] as Map<String, dynamic>?;
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

  Future<void> _logout() async {
    final t = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: t.border),
        ),
        title: Text('Logout?', style: TextStyle(color: t.text1, fontWeight: FontWeight.w700)),
        content: Text('તમે logout કરવા માંગો છો?', style: TextStyle(color: t.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.text2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final t    = context.read<ThemeProvider>();
    final ctrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
        title: Row(children: [
          const Icon(Icons.warning_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          Text('Account Delete', style: TextStyle(color: t.text1, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚠️ આ action irreversible છે. બધો data permanently delete થઈ જશે.',
                style: TextStyle(color: t.text2, fontSize: 13)),
            const SizedBox(height: 14),
            Text('Confirm કરવા "DELETE" type કરો:', style: TextStyle(color: t.text2, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              style: TextStyle(color: t.text1),
              decoration: InputDecoration(
                filled: true,
                fillColor: t.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                hintText: 'DELETE',
                hintStyle: TextStyle(color: t.text2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.text2)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim() == 'DELETE') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please type DELETE to confirm'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: context.read<ThemeProvider>().surface,
          content: Row(children: [
            CircularProgressIndicator(color: context.read<ThemeProvider>().brand),
            const SizedBox(width: 16),
            const Text('Deleting...', style: TextStyle(color: Colors.white)),
          ]),
        ),
      );

      final uid = widget.userId;
      final sb  = Supabase.instance.client;

      await sb.from('ngm_message_reactions').delete().eq('user_id', uid);
      await sb.from('ngm_message_status').delete().eq('user_id', uid);
      await sb.from('ngm_deleted_messages').delete().eq('user_id', uid);
      await sb.from('ngm_story_views').delete().eq('viewer_id', uid);
      await sb.from('ngm_stories').delete().eq('user_id', uid);
      await sb.from('ngm_post_likes').delete().eq('user_id', uid);
      await sb.from('ngm_post_comments').delete().eq('user_id', uid);
      await sb.from('ngm_post_collaborators').delete().eq('collaborator_user_id', uid);
      await sb.from('ngm_post_mentions').delete().eq('mentioned_user_id', uid);
      await sb.from('ngm_saved_posts').delete().eq('user_id', uid);
      await sb.from('ngm_user_engagement').delete().eq('user_id', uid);
      await sb.from('ngm_user_posts').delete().eq('user_id', uid);
      await sb.from('ngm_user_followers').delete().or('follower_user_id.eq.$uid,following_user_id.eq.$uid');
      await sb.from('ngm_blocked_users').delete().or('user_id.eq.$uid,blocked_user_id.eq.$uid');
      await sb.from('ngm_contacts').delete().or('user_id.eq.$uid,contact_user_id.eq.$uid');
      await sb.from('ngm_notification_tokens').delete().eq('user_id', uid);
      await sb.from('ngm_user_interests').delete().eq('user_id', uid);
      await sb.from('ngm_2fa_settings').delete().eq('user_id', uid);
      await sb.from('ngm_app_lock').delete().eq('user_id', uid);
      await sb.from('ngm_account_autodestruct').delete().eq('user_id', uid);
      await sb.from('ngm_active_sessions').delete().eq('user_id', uid);
      await sb.from('ngm_user_settings').delete().eq('user_id', uid);
      await sb.from('ngm_backups').delete().eq('user_id', uid);
      await sb.from('ngm_users').delete().eq('user_id', uid);
      await sb.from('profiles').delete().eq('id', uid);
      await sb.auth.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: t.bgGradient,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: t.brand))
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: t.brand,
                  backgroundColor: t.surface,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildHeader(t),
                      _buildCreditsCard(t),
                      const SizedBox(height: 16),
                      _buildStatsRow(t),
                      const SizedBox(height: 16),
                      _buildPersonalInfo(t),
                      const SizedBox(height: 16),
                      _buildAccountSection(t),
                      const SizedBox(height: 16),
                      _buildDangerZone(t),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider t) {
    final name       = _ngmUser?['full_name'] ?? _profile?['full_name'] ?? 'User';
    final picUrl     = _ngmUser?['profile_picture_url'] as String?;
    final isVerified = _ngmUser?['is_verified'] == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
              child: Icon(Icons.close_rounded, color: t.text1, size: 20),
            ),
          ),
          const Spacer(),
          Text('Profile', style: TextStyle(color: t.text1, fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          // ✅ Theme toggle button
          GestureDetector(
            onTap: () => t.toggle(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: t.isDark ? t.surface2 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
                boxShadow: t.isDark ? [] : [BoxShadow(color: t.brand.withOpacity(0.15), blurRadius: 8)],
              ),
              child: Icon(
                t.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: t.isDark ? const Color(0xFFFBBF24) : t.brand,
                size: 20,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        Stack(children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: t.isDark
                    ? [const Color(0xFFB06AB3), const Color(0xFF4568DC)]
                    : [t.brand.withOpacity(0.6), t.accent],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border.all(color: t.brand.withOpacity(0.4), width: 2),
            ),
            child: ClipOval(
              child: picUrl != null
                  ? Image.network(picUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person_rounded,
                          color: Colors.white.withOpacity(0.9), size: 48))
                  : Icon(Icons.person_rounded, color: Colors.white.withOpacity(0.9), size: 48),
            ),
          ),
          if (isVerified) Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: t.brand, shape: BoxShape.circle,
                border: Border.all(color: t.bg, width: 2),
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(name, style: TextStyle(color: t.text1, fontSize: 18, fontWeight: FontWeight.w800)),
        if ((_ngmUser?['username'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('@${_ngmUser!['username']}', style: TextStyle(color: t.text2, fontSize: 13)),
        ],
        if ((_ngmUser?['bio'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_ngmUser!['bio'].toString(),
              style: TextStyle(color: t.text2, fontSize: 13),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (_ngmUser == null || _profile == null) return;
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => EditProfileScreen(
                ngmUser: _ngmUser!,
                profile: _profile!,
                onSaved: _loadProfile,
              ),
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: t.isDark ? Colors.white38 : t.border, width: 1.2,
              ),
              color: t.isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_rounded, size: 14, color: t.text1),
              const SizedBox(width: 6),
              Text('Edit', style: TextStyle(color: t.text1, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildCreditsCard(ThemeProvider t) {
    final credits = _profile?['credits'] ?? 0;
    final level   = _profile?['current_level'] ?? 'Free';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: t.isDark
              ? [const Color(0xFF1C1A3A), const Color(0xFF0F1628)]
              : [Colors.white.withOpacity(0.85), t.brand.withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: t.isDark ? t.brand.withOpacity(0.25) : t.border),
        boxShadow: [BoxShadow(color: t.brand.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(children: [
          Text('$credits', style: TextStyle(color: t.text1, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Text('Credits', style: TextStyle(color: t.text2, fontSize: 14)),
          Icon(Icons.chevron_right_rounded, color: t.text2, size: 18),
          const Spacer(),
          Icon(Icons.diamond_rounded, color: t.brand, size: 18),
          const SizedBox(width: 6),
          Text(level, style: TextStyle(color: t.text1, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4568DC), Color(0xFF7B4FD6)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Upgrade Plan', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('View Plan', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Center(child: Text('💎', style: TextStyle(fontSize: 16))),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFf97316), Color(0xFFfbbf24)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Invite Friends', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Earn More Credits', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Center(child: Text('🎁', style: TextStyle(fontSize: 16))),
                ),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildStatsRow(ThemeProvider t) {
    // ✅ FIX: posts_count directly from _ngmUser (already fetched correctly)
    final posts     = _ngmUser?['posts_count']     ?? 0;
    final followers = _ngmUser?['followers_count'] ?? 0;
    final following = _ngmUser?['following_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _statBtn('Posts', posts, () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => MyPostsScreen(userId: widget.userId))), t),
        const SizedBox(width: 10),
        _statBtn('Followers', followers, () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FollowersScreen(userId: widget.userId, initialTab: 0))), t),
        const SizedBox(width: 10),
        _statBtn('Following', following, () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FollowersScreen(userId: widget.userId, initialTab: 1))), t),
      ]),
    );
  }

  Widget _statBtn(String label, dynamic val, VoidCallback onTap, ThemeProvider t) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: t.glassBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.glassBorder),
              ),
              child: Column(children: [
                Text('$val', style: TextStyle(color: t.text1, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: t.text2, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfo(ThemeProvider t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Personal Information',
            style: TextStyle(color: t.text2, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: t.glassBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.glassBorder),
              ),
              child: Column(children: [
                _infoRow(Icons.alternate_email_rounded, 'Username',  _ngmUser?['username'] ?? '-', t),
                _divider(t),
                _infoRow(Icons.email_outlined,          'Email',     _ngmUser?['email'] ?? _profile?['email'] ?? '-', t),
                _divider(t),
                _infoRow(Icons.phone_outlined,          'Phone',     _ngmUser?['mobile'] ?? _profile?['mobile'] ?? '-', t),
                _divider(t),
                _infoRow(Icons.cake_outlined,           'Birthday',  _ngmUser?['date_of_birth'] ?? _profile?['date_of_birth'] ?? '-', t),
                _divider(t),
                _infoRow(Icons.location_on_outlined,    'District',  _profile?['district'] ?? '-', t),
                _divider(t),
                _infoRow(Icons.star_outline_rounded,    'Level',     _profile?['current_level'] ?? '-', t),
                _divider(t),
                _infoRow(Icons.leaderboard_outlined,    'Rank',      '#${_profile?['current_rank'] ?? '-'}', t),
                _divider(t),
                _infoRow(Icons.quiz_outlined,           'Tests',     '${_profile?['total_tests_taken'] ?? 0}', t),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value, ThemeProvider t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: t.text2, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: t.text2, fontSize: 11)),
          Text(value?.toString() ?? '-',
              style: TextStyle(color: t.text1, fontSize: 14, fontWeight: FontWeight.w500)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, color: t.text2.withOpacity(0.5), size: 14),
      ]),
    );
  }

  Widget _divider(ThemeProvider t) =>
      Divider(color: t.border, height: 1, indent: 50);

  Widget _buildAccountSection(ThemeProvider t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Account',
            style: TextStyle(color: t.text2, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: t.glassBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.glassBorder),
              ),
              child: Column(children: [
                _menuTile(Icons.grid_on_rounded, 'My Posts', t, onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MyPostsScreen(userId: widget.userId),
                  ));
                }),
                _divider(t),
                _menuTile(Icons.people_outline_rounded, 'Followers & Following', t, onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FollowersScreen(userId: widget.userId),
                  ));
                }),
                _divider(t),
                // ✅ FIX: BlockedUsersScreen correct navigation
                _menuTile(Icons.block_rounded, 'Blocked Users', t, iconColor: Colors.redAccent, onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BlockedUsersScreen(userId: widget.userId),
                  ));
                }),
                _divider(t),
                _themeToggleTile(t),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _menuTile(IconData icon, String label, ThemeProvider t,
      {Color? iconColor, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: (iconColor ?? t.brand).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor ?? t.brand, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: t.text1, fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: t.text2.withOpacity(0.5), size: 14),
        ]),
      ),
    );
  }

  Widget _themeToggleTile(ThemeProvider t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            t.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: const Color(0xFFFBBF24), size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(t.isDark ? 'Dark Mode' : 'Light Mode',
            style: TextStyle(color: t.text1, fontSize: 14, fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: () => t.toggle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52, height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: t.isDark ? t.brand : const Color(0xFFD1D5DB),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              alignment: t.isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 22, height: 22,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(
                  child: Text(t.isDark ? '🌙' : '☀️', style: const TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildDangerZone(ThemeProvider t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Account Actions',
            style: TextStyle(color: t.text2, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: t.glassBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.glassBorder),
              ),
              child: Column(children: [
                GestureDetector(
                  onTap: _logout,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.orange, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text('Logout',
                          style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                Divider(color: t.border, height: 1, indent: 62),
                GestureDetector(
                  onTap: _deleteAccount,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Delete Account',
                            style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('All data permanently deleted',
                            style: TextStyle(color: Colors.red, fontSize: 11)),
                      ])),
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}