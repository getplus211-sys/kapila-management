import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'theme_provider.dart';
import 'followers_screen.dart';
import 'my_posts_screen.dart';

class ViewProfileScreen extends StatefulWidget {
  final String userId;
  const ViewProfileScreen({super.key, required this.userId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading  = true;
  bool _isFollowing = false;
  bool _isBlocked  = false;
  bool _followLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await Supabase.instance.client
          .from('ngm_users')
          .select('*')
          .eq('user_id', widget.userId)
          .maybeSingle();

      bool following = false;
      bool blocked   = false;

      if (_currentUserId != null && _currentUserId != widget.userId) {
        final fRow = await Supabase.instance.client
            .from('ngm_user_followers')
            .select('follow_id')
            .eq('follower_user_id', _currentUserId!)
            .eq('following_user_id', widget.userId)
            .maybeSingle();
        following = fRow != null;

        final bRow = await Supabase.instance.client
            .from('ngm_blocked_users')
            .select('block_id')
            .eq('user_id', _currentUserId!)
            .eq('blocked_user_id', widget.userId)
            .maybeSingle();
        blocked = bRow != null;
      }

      setState(() {
        _user       = user;
        _isFollowing = following;
        _isBlocked  = blocked;
        _isLoading  = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _followLoading) return;
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await Supabase.instance.client
            .from('ngm_user_followers')
            .delete()
            .eq('follower_user_id', _currentUserId!)
            .eq('following_user_id', widget.userId);
        setState(() {
          _isFollowing = false;
          if (_user != null) {
            _user!['followers_count'] = ((_user!['followers_count'] ?? 1) - 1).clamp(0, 999999);
          }
        });
      } else {
        await Supabase.instance.client.from('ngm_user_followers').insert({
          'follower_user_id':  _currentUserId,
          'following_user_id': widget.userId,
        });
        setState(() {
          _isFollowing = true;
          if (_user != null) {
            _user!['followers_count'] = (_user!['followers_count'] ?? 0) + 1;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _toggleBlock() async {
    if (_currentUserId == null) return;
    final t    = context.read<ThemeProvider>();
    final name = _user?['full_name'] ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border),
        ),
        title: Text(_isBlocked ? 'Unblock $name?' : 'Block $name?',
            style: TextStyle(color: t.text1)),
        content: Text(
          _isBlocked
              ? '$name ને unblock કરવામાં આવશે.'
              : '$name ને block કરવામાં આવશે.',
          style: TextStyle(color: t.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.text2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _isBlocked ? t.brand : Colors.red),
            child: Text(_isBlocked ? 'Unblock' : 'Block',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_isBlocked) {
        await Supabase.instance.client
            .from('ngm_blocked_users')
            .delete()
            .eq('user_id', _currentUserId!)
            .eq('blocked_user_id', widget.userId);
      } else {
        await Supabase.instance.client.from('ngm_blocked_users').insert({
          'user_id':         _currentUserId,
          'blocked_user_id': widget.userId,
        });
      }
      setState(() => _isBlocked = !_isBlocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t            = context.watch<ThemeProvider>();
    final isOwnProfile = _currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: t.bgGradient,
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : _user == null
                ? Center(child: Text('User not found', style: TextStyle(color: t.text1)))
                : CustomScrollView(
                    slivers: [
                      _buildSliverAppBar(t, isOwnProfile),
                      SliverToBoxAdapter(child: _buildBody(t, isOwnProfile)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeProvider t, bool isOwnProfile) {
    final name   = _user?['full_name'] ?? 'User';
    final picUrl = _user?['profile_picture_url'] as String?;

    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
      backgroundColor: t.bg,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: t.isDark
                      ? [const Color(0xFF1C1A3A), const Color(0xFF0B0E1A)]
                      : [const Color(0xFFE0DCFF), const Color(0xFFEEF0FF)],
                ),
              ),
            ),
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [t.brand.withOpacity(0.2), Colors.transparent]),
                ),
              ),
            ),
            Positioned(
              bottom: 20, left: 0, right: 0,
              child: Column(children: [
                Stack(children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: t.brand, width: 2),
                      color: t.brand.withOpacity(0.15),
                    ),
                    child: ClipOval(
                      child: picUrl != null
                          ? Image.network(picUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(name[0].toUpperCase(),
                                    style: TextStyle(fontSize: 36, color: t.brand, fontWeight: FontWeight.bold))))
                          : Center(
                              child: Text(name[0].toUpperCase(),
                                  style: TextStyle(fontSize: 36, color: t.brand, fontWeight: FontWeight.bold))),
                    ),
                  ),
                  if (_user?['is_online'] == true) Positioned(
                    right: 4, bottom: 4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle,
                        border: Border.all(color: t.bg, width: 2),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(name, style: TextStyle(color: t.text1, fontSize: 20, fontWeight: FontWeight.w800)),
                  if (_user?['is_verified'] == true) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified_rounded, color: t.brand, size: 18),
                  ],
                ]),
                if ((_user?['username'] ?? '').toString().isNotEmpty)
                  Text('@${_user!['username']}', style: TextStyle(color: t.text2, fontSize: 13)),
              ]),
            ),
          ],
        ),
      ),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: t.surface2.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.border),
            ),
            child: Icon(Icons.arrow_back_ios_rounded, color: t.text1, size: 16),
          ),
        ),
      ),
      actions: [
        if (!isOwnProfile)
          PopupMenuButton<String>(
            color: t.surface2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: t.border),
            ),
            onSelected: (v) { if (v == 'block') _toggleBlock(); },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'block',
                child: Row(children: [
                  Icon(_isBlocked ? Icons.lock_open : Icons.block, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(_isBlocked ? 'Unblock' : 'Block User',
                      style: const TextStyle(color: Colors.red)),
                ]),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: t.surface2.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                ),
                child: Icon(Icons.more_vert_rounded, color: t.text1, size: 18),
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(ThemeProvider t, bool isOwnProfile) {
    final bio            = _user?['bio'] ?? '';
    final postsCount     = _user?['posts_count'] ?? 0;
    final followersCount = _user?['followers_count'] ?? 0;
    final followingCount = _user?['following_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Bio
          if (bio.toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.glassBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.glassBorder),
                  ),
                  child: Text(bio.toString(),
                      style: TextStyle(color: t.text1, fontSize: 14, height: 1.5),
                      textAlign: TextAlign.center),
                ),
              ),
            ),

          // ✅ Stats - tappable, navigate to that user's pages
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: t.glassBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.glassBorder),
                ),
                child: Row(children: [
                  _statItem('Posts', postsCount, () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MyPostsScreen(userId: widget.userId),
                    ));
                  }, t),
                  _divider(t),
                  _statItem('Followers', followersCount, () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FollowersScreen(userId: widget.userId, initialTab: 0),
                    ));
                  }, t),
                  _divider(t),
                  _statItem('Following', followingCount, () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FollowersScreen(userId: widget.userId, initialTab: 1),
                    ));
                  }, t),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Follow / Message buttons
          if (!isOwnProfile) ...[
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _followLoading ? null : _toggleFollow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: _isFollowing ? null
                          : LinearGradient(colors: [t.brand, const Color(0xFF6B3FC6)]),
                      color: _isFollowing ? t.surface2 : null,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _isFollowing ? t.border : Colors.transparent),
                    ),
                    child: Center(
                      child: _followLoading
                          ? SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: t.brand, strokeWidth: 2))
                          : Text(
                              _isFollowing ? '✓ Following' : 'Follow',
                              style: TextStyle(
                                color: _isFollowing ? t.text1 : Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.border),
                ),
                child: Icon(Icons.message_outlined, color: t.brand, size: 20),
              ),
            ]),
            const SizedBox(height: 14),
          ],

          // Info list
          _buildInfoSection(t),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _statItem(String label, dynamic count, VoidCallback onTap, ThemeProvider t) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Text('$count',
              style: TextStyle(color: t.text1, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: t.text2, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _divider(ThemeProvider t) =>
      Container(width: 1, height: 30, color: t.border);

  Widget _buildInfoSection(ThemeProvider t) {
    final items = <Map<String, dynamic>>[
      if ((_user?['email'] ?? '').toString().isNotEmpty)
        {'icon': Icons.email_outlined, 'label': 'Email', 'value': _user!['email']},
      if ((_user?['mobile'] ?? '').toString().isNotEmpty)
        {'icon': Icons.phone_outlined, 'label': 'Phone', 'value': _user!['mobile']},
      if (_user?['date_of_birth'] != null)
        {'icon': Icons.cake_outlined, 'label': 'Birthday', 'value': _user!['date_of_birth']},
      if (_user?['account_created_at'] != null)
        {'icon': Icons.calendar_today_outlined, 'label': 'Joined',
         'value': _formatDate(_user!['account_created_at'])},
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: t.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.glassBorder),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final item  = e.value;
              final isLast = e.key == items.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(children: [
                    Icon(item['icon'] as IconData, color: t.brand, size: 18),
                    const SizedBox(width: 12),
                    Text(item['label'] as String,
                        style: TextStyle(color: t.text2, fontSize: 13)),
                    const Spacer(),
                    Text(item['value'].toString(),
                        style: TextStyle(color: t.text1, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
                if (!isLast) Divider(color: t.border, height: 1, indent: 16, endIndent: 16),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic dt) {
    final d = DateTime.tryParse(dt.toString());
    if (d == null) return dt.toString();
    return '${d.day}/${d.month}/${d.year}';
  }
}