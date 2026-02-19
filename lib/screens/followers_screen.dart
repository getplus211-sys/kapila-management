import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'theme_provider.dart';
import 'view_profile_screen.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final int initialTab;
  const FollowersScreen({super.key, required this.userId, this.initialTab = 0});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final followersRes = await Supabase.instance.client
          .from('ngm_user_followers')
          .select('follower_user_id')
          .eq('following_user_id', widget.userId);

      final followingRes = await Supabase.instance.client
          .from('ngm_user_followers')
          .select('following_user_id')
          .eq('follower_user_id', widget.userId);

      final followerIds = (followersRes as List).map((e) => e['follower_user_id'] as String).toList();
      final followingIds = (followingRes as List).map((e) => e['following_user_id'] as String).toList();

      List<Map<String, dynamic>> frs = [];
      List<Map<String, dynamic>> fng = [];

      if (followerIds.isNotEmpty) {
        final users = await Supabase.instance.client
            .from('ngm_users')
            .select('user_id, full_name, username, profile_picture_url, is_verified, is_online, bio')
            .inFilter('user_id', followerIds);
        frs = List<Map<String, dynamic>>.from(users);
      }
      if (followingIds.isNotEmpty) {
        final users = await Supabase.instance.client
            .from('ngm_users')
            .select('user_id, full_name, username, profile_picture_url, is_verified, is_online, bio')
            .inFilter('user_id', followingIds);
        fng = List<Map<String, dynamic>>.from(users);
      }

      setState(() {
        _followers = frs;
        _following = fng;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: t.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(t),
              _buildTabBar(t),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: t.brand))
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildList(_followers, 'followers', t),
                          _buildList(_following, 'following', t),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeProvider t) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: t.glassBg,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border),
                  ),
                  child: Icon(Icons.arrow_back_ios_rounded, color: t.text1, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Text('Connections', style: TextStyle(color: t.text1, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FIX: Clean tab bar - no ugly highlight
  Widget _buildTabBar(ThemeProvider t) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: t.brand,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: t.text2,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [
          Tab(text: 'Followers (${_followers.length})'),
          Tab(text: 'Following (${_following.length})'),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> users, String type, ThemeProvider t) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'followers' ? Icons.people_outline : Icons.person_add_outlined,
              size: 60, color: t.text2,
            ),
            const SizedBox(height: 16),
            Text(
              type == 'followers' ? 'કોઈ followers નથી' : 'કોઈ following નથી',
              style: TextStyle(color: t.text1, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: t.brand,
      backgroundColor: t.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (_, i) => _buildUserTile(users[i], t),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, ThemeProvider t) {
    final name       = user['full_name'] ?? user['username'] ?? 'User';
    final username   = user['username'] ?? '';
    final picUrl     = user['profile_picture_url'] as String?;
    final isVerified = user['is_verified'] == true;
    final isOnline   = user['is_online'] == true;
    final bio        = user['bio'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ViewProfileScreen(userId: user['user_id']),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.glassBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.glassBorder),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: t.brand.withOpacity(0.2),
                      backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
                      child: picUrl == null
                          ? Text(name[0].toUpperCase(),
                              style: TextStyle(color: t.brand, fontWeight: FontWeight.bold, fontSize: 20))
                          : null,
                    ),
                    if (isOnline) Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.bg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(name,
                            style: TextStyle(color: t.text1, fontWeight: FontWeight.w600, fontSize: 14)),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, color: t.brand, size: 14),
                        ],
                      ]),
                      if (username.isNotEmpty)
                        Text('@$username', style: TextStyle(color: t.text2, fontSize: 12)),
                      if (bio.toString().isNotEmpty)
                        Text(bio.toString(),
                            style: TextStyle(color: t.text2, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: t.text2, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}