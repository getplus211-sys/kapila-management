import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'theme_provider.dart';

class BlockedUsersScreen extends StatefulWidget {
  final String userId;
  const BlockedUsersScreen({super.key, required this.userId});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('ngm_blocked_users')
          .select('blocked_user_id, blocked_at, reason')
          .eq('user_id', widget.userId);

      final ids = (data as List).map((e) => e['blocked_user_id'] as String).toList();
      List<Map<String, dynamic>> result = [];

      if (ids.isNotEmpty) {
        final users = await Supabase.instance.client
            .from('ngm_users')
            .select('user_id, full_name, username, profile_picture_url')
            .inFilter('user_id', ids);

        final userMap = <String, Map<String, dynamic>>{
          for (var u in (users as List)) u['user_id'] as String: Map<String, dynamic>.from(u)
        };

        for (var b in data) {
          final uid = b['blocked_user_id'] as String;
          if (userMap.containsKey(uid)) {
            result.add({
              ...userMap[uid]!,
              'blocked_at': b['blocked_at'],
              'reason': b['reason'],
              'block_target_id': uid,
            });
          }
        }
      }

      setState(() {
        _blockedUsers = result;
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

  Future<void> _unblockUser(String blockedUserId, String name) async {
    final t = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border),
        ),
        title: Text('Unblock $name?', style: TextStyle(color: t.text1)),
        content: Text('$name ને unblock કરવામાં આવશે.', style: TextStyle(color: t.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.text2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: t.brand),
            child: const Text('Unblock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('ngm_blocked_users')
            .delete()
            .eq('user_id', widget.userId)
            .eq('blocked_user_id', blockedUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name ને unblock કરવામાં આવ્યા ✓'), backgroundColor: Colors.green),
          );
        }
        _loadBlockedUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
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
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: t.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(t),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: t.brand))
                    : _blockedUsers.isEmpty
                        ? _buildEmpty(t)
                        : RefreshIndicator(
                            onRefresh: _loadBlockedUsers,
                            color: t.brand,
                            backgroundColor: t.surface,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _blockedUsers.length,
                              itemBuilder: (_, i) => _buildUserTile(_blockedUsers[i], t),
                            ),
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
              Text('Blocked Users',
                  style: TextStyle(color: t.text1, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_blockedUsers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text('${_blockedUsers.length} blocked',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeProvider t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block_rounded, size: 64, color: t.text2),
          const SizedBox(height: 16),
          Text('કોઈ blocked users નથી',
              style: TextStyle(color: t.text1, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Block કેલા users અહીં દેખાશે',
              style: TextStyle(color: t.text2, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, ThemeProvider t) {
    final name      = user['full_name'] ?? user['username'] ?? 'User';
    final username  = user['username'] ?? '';
    final picUrl    = user['profile_picture_url'] as String?;
    final blockedAt = user['blocked_at'] != null
        ? DateTime.tryParse(user['blocked_at'].toString())
        : null;
    final targetId  = user['block_target_id'] as String;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.glassBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.red.withOpacity(0.15),
                    backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
                    child: picUrl == null
                        ? Text(name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18))
                        : null,
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle,
                        border: Border.all(color: t.bg, width: 2),
                      ),
                      child: const Icon(Icons.block, color: Colors.white, size: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(color: t.text1, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (username.isNotEmpty)
                      Text('@$username', style: TextStyle(color: t.text2, fontSize: 12)),
                    if (blockedAt != null)
                      Text('Blocked ${blockedAt.day}/${blockedAt.month}/${blockedAt.year}',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _unblockUser(targetId, name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.brand.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.brand.withOpacity(0.3)),
                  ),
                  child: Text('Unblock',
                      style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}