import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'theme_provider.dart';

class MyPostsScreen extends StatefulWidget {
  final String userId;
  const MyPostsScreen({super.key, required this.userId});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('ngm_user_posts')
          .select('*')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      setState(() {
        _posts = List<Map<String, dynamic>>.from(data);
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

  Future<void> _deletePost(String postId) async {
    final t = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border),
        ),
        title: Text('Post Delete કરો?', style: TextStyle(color: t.text1)),
        content: Text('આ post કાયમ માટે delete થઈ જશે.', style: TextStyle(color: t.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.text2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('ngm_user_posts')
            .delete()
            .eq('post_id', postId);
        _loadPosts();
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
                    : _posts.isEmpty
                        ? _buildEmpty(t)
                        : RefreshIndicator(
                            onRefresh: _loadPosts,
                            color: t.brand,
                            backgroundColor: t.surface,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _posts.length,
                              itemBuilder: (_, i) => _buildPostCard(_posts[i], t),
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
              Text('My Posts',
                  style: TextStyle(color: t.text1, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: t.brand.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.brand.withOpacity(0.3)),
                ),
                child: Text('${_posts.length} posts',
                    style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.w600)),
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
          Icon(Icons.grid_off_rounded, size: 64, color: t.text2),
          const SizedBox(height: 16),
          Text('કોઈ posts નથી',
              style: TextStyle(color: t.text1, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('તમારી first post share કરો!',
              style: TextStyle(color: t.text2, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, ThemeProvider t) {
    final createdAt = post['created_at'] != null
        ? DateTime.tryParse(post['created_at'].toString())
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.brand.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post['post_type'] ?? 'post',
                      style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  if (createdAt != null)
                    Text(_formatTime(createdAt),
                        style: TextStyle(color: t.text2, fontSize: 12)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deletePost(post['post_id']),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                    ),
                  ),
                ],
              ),
              if ((post['content'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(post['content'],
                    style: TextStyle(color: t.text1, fontSize: 14, height: 1.5)),
              ],
              if (post['media_url'] != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    post['media_url'],
                    height: 180, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 60, color: t.surface2,
                      child: Icon(Icons.image_not_supported, color: t.text2),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                _statChip(Icons.favorite_rounded, '${post['likes_count'] ?? 0}', Colors.redAccent),
                const SizedBox(width: 12),
                _statChip(Icons.comment_rounded, '${post['comments_count'] ?? 0}', const Color(0xFF06b6d4)),
                const SizedBox(width: 12),
                _statChip(Icons.visibility_rounded, '${post['views_count'] ?? 0}', t.text2),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String count, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(count, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}