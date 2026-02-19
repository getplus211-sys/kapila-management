import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'share_screen.dart';

// ── Dark theme colors ───────────────────────
const _kBg      = Color(0xFF0B0E1A);
const _kSurface = Color(0xFF141828);
const _kSurf2   = Color(0xFF1C2035);
const _kBrand   = Color(0xFF7B4FD6);
const _kAccent  = Color(0xFF9B6FF0);
const _kText1   = Color(0xFFEEEEF5);
const _kText2   = Color(0xFF8890AA);
const _kBorder  = Color(0xFF252A40);

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch post with user data
      final response = await Supabase.instance.client
          .from('ngm_user_posts')
          .select('*, ngm_users(user_id, full_name, username, profile_picture_url, is_verified)')
          .eq('post_id', widget.postId)
          .single();

      if (_currentUserId != null) {
        // Check if liked
        final likeResponse = await Supabase.instance.client
            .from('ngm_post_likes')
            .select()
            .eq('post_id', widget.postId)
            .eq('user_id', _currentUserId!)
            .maybeSingle();
        _isLiked = likeResponse != null;

        // Check if saved
        final saveResponse = await Supabase.instance.client
            .from('ngm_saved_posts')
            .select()
            .eq('post_id', widget.postId)
            .eq('user_id', _currentUserId!)
            .maybeSingle();
        _isSaved = saveResponse != null;

        // Check if following
        final postUserId = response['ngm_users']['user_id'];
        final followResponse = await Supabase.instance.client
            .from('ngm_user_followers')
            .select()
            .eq('follower_user_id', _currentUserId!)
            .eq('following_user_id', postUserId)
            .maybeSingle();
        _isFollowing = followResponse != null;

        // Increment view count
        await Supabase.instance.client.rpc('increment_post_views', params: {
          'post_id_param': widget.postId,
        });
      }

      setState(() {
        _post = response;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading post: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post not found or deleted'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUserId == null) return;
    
    setState(() => _isLiked = !_isLiked);
    
    try {
      if (_isLiked) {
        await Supabase.instance.client.from('ngm_post_likes').insert({
          'post_id': widget.postId,
          'user_id': _currentUserId!,
        });
        setState(() {
          _post!['likes_count'] = (_post!['likes_count'] ?? 0) + 1;
        });
      } else {
        await Supabase.instance.client
            .from('ngm_post_likes')
            .delete()
            .eq('post_id', widget.postId)
            .eq('user_id', _currentUserId!);
        setState(() {
          _post!['likes_count'] = (_post!['likes_count'] ?? 1) - 1;
        });
      }
    } catch (e) {
      setState(() => _isLiked = !_isLiked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleSave() async {
    if (_currentUserId == null) return;
    
    setState(() => _isSaved = !_isSaved);
    
    try {
      if (_isSaved) {
        await Supabase.instance.client.from('ngm_saved_posts').insert({
          'post_id': widget.postId,
          'user_id': _currentUserId!,
        });
      } else {
        await Supabase.instance.client
            .from('ngm_saved_posts')
            .delete()
            .eq('post_id', widget.postId)
            .eq('user_id', _currentUserId!);
      }
    } catch (e) {
      setState(() => _isSaved = !_isSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _post == null) return;
    
    final postUserId = _post!['ngm_users']['user_id'];
    setState(() => _isFollowing = !_isFollowing);
    
    try {
      if (_isFollowing) {
        await Supabase.instance.client.from('ngm_user_followers').insert({
          'follower_user_id': _currentUserId!,
          'following_user_id': postUserId,
        });
      } else {
        await Supabase.instance.client
            .from('ngm_user_followers')
            .delete()
            .eq('follower_user_id', _currentUserId!)
            .eq('following_user_id', postUserId);
      }
    } catch (e) {
      setState(() => _isFollowing = !_isFollowing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showShareSheet() {
    if (_post == null) return;
    
    showShareSheet(
      context,
      ShareContent(
        type: 'link',
        link: 'https://kapilalearning.vercel.app/post/${widget.postId}',
        text: _post!['content'],
      ),
    );
  }

  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsBottomSheet(postId: widget.postId),
    );
  }

  void _launchURL(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildContentWithLinks(String content) {
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)|([a-zA-Z0-9-]+\.(com|org|net|io|in|co\.in)[^\s]*)',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    int lastIndex = 0;
    
    for (final match in urlRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: const TextStyle(fontSize: 16, color: _kText1, height: 1.4),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF60AAFF),
          decoration: TextDecoration.underline,
          height: 1.4,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchURL(match.group(0)!),
      ));
      lastIndex = match.end;
    }
    
    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: const TextStyle(fontSize: 16, color: _kText1, height: 1.4),
      ));
    }
    
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kText1),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(color: _kText1, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kBrand))
          : _post == null
              ? const Center(
                  child: Text(
                    'Post not found',
                    style: TextStyle(color: _kText2, fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kSurface,
                      border: Border(bottom: BorderSide(color: _kBorder)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: _kBrand,
                              backgroundImage: _post!['ngm_users']['profile_picture_url'] != null
                                  ? CachedNetworkImageProvider(
                                      _post!['ngm_users']['profile_picture_url'])
                                  : null,
                              child: _post!['ngm_users']['profile_picture_url'] == null
                                  ? Text(
                                      (_post!['ngm_users']['full_name'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _post!['ngm_users']['full_name'] ??
                                              _post!['ngm_users']['username'] ??
                                              'User',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: _kText1,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_post!['ngm_users']['is_verified'] == true) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, color: _kBrand, size: 18),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '@${_post!['ngm_users']['username'] ?? 'user'}',
                                    style: const TextStyle(fontSize: 14, color: _kText2),
                                  ),
                                ],
                              ),
                            ),
                            // Follow button
                            if (_currentUserId != null &&
                                _currentUserId != _post!['ngm_users']['user_id'])
                              ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing ? _kSurf2 : _kBrand,
                                  foregroundColor: _isFollowing ? _kText1 : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  minimumSize: Size.zero,
                                ),
                                child: Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Content
                        if (_post!['content'] != null && _post!['content'].isNotEmpty)
                          _buildContentWithLinks(_post!['content']),
                        
                        // Media
                        if (_post!['media_url'] != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: _post!['media_url'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 300,
                                color: _kSurf2,
                                child: const Center(
                                  child: CircularProgressIndicator(color: _kBrand),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 300,
                                color: _kSurf2,
                                child: const Icon(Icons.error, color: _kText2),
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 12),
                        
                        // Time
                        Text(
                          timeago.format(DateTime.parse(_post!['created_at'])),
                          style: const TextStyle(fontSize: 14, color: _kText2),
                        ),
                        
                        const Divider(color: _kBorder, height: 32),
                        
                        // Stats
                        Row(
                          children: [
                            _buildStat(
                              '${_post!['likes_count'] ?? 0}',
                              'Likes',
                            ),
                            const SizedBox(width: 16),
                            _buildStat(
                              '${_post!['comments_count'] ?? 0}',
                              'Comments',
                            ),
                            const SizedBox(width: 16),
                            _buildStat(
                              '${_post!['views_count'] ?? 0}',
                              'Views',
                            ),
                          ],
                        ),
                        
                        const Divider(color: _kBorder, height: 32),
                        
                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildActionButton(
                              icon: Icons.chat_bubble_outline,
                              onTap: _showCommentsBottomSheet,
                            ),
                            _buildActionButton(
                              icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                              color: _isLiked ? Colors.pinkAccent : null,
                              onTap: _toggleLike,
                            ),
                            _buildActionButton(
                              icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                              color: _isSaved ? _kAccent : null,
                              onTap: _toggleSave,
                            ),
                            _buildActionButton(
                              icon: Icons.share_outlined,
                              onTap: _showShareSheet,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStat(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kText1,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: _kText2),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 24,
          color: color ?? _kText2,
        ),
      ),
    );
  }
}

// Comments Bottom Sheet (simplified for detail screen)
class _CommentsBottomSheet extends StatefulWidget {
  final String postId;
  const _CommentsBottomSheet({required this.postId});

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final response = await Supabase.instance.client
          .from('ngm_post_comments')
          .select('*, ngm_users(user_id, full_name, username, profile_picture_url)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false);
      setState(() {
        _comments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    try {
      await Supabase.instance.client.from('ngm_post_comments').insert({
        'post_id': widget.postId,
        'user_id': user.id,
        'comment_text': _commentController.text.trim(),
      });
      _commentController.clear();
      _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kText1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _kText2),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kBrand))
                  : _comments.isEmpty
                      ? const Center(
                          child: Text(
                            'No comments yet',
                            style: TextStyle(color: _kText2),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final user = comment['ngm_users'];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _kBrand,
                                backgroundImage: user['profile_picture_url'] != null
                                    ? CachedNetworkImageProvider(
                                        user['profile_picture_url'])
                                    : null,
                                child: user['profile_picture_url'] == null
                                    ? Text(
                                        user['full_name']?[0] ?? 'U',
                                        style: const TextStyle(color: Colors.white),
                                      )
                                    : null,
                              ),
                              title: Text(
                                user['full_name'] ?? user['username'] ?? 'User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _kText1,
                                ),
                              ),
                              subtitle: Text(
                                comment['comment_text'],
                                style: const TextStyle(color: _kText2),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: _kSurface,
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: _kText1),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: _kText2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _kBrand),
                        ),
                        filled: true,
                        fillColor: _kSurf2,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: _kBrand),
                    onPressed: _postComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}