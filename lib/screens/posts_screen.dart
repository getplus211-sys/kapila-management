import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'theme_provider.dart';
import 'share_screen.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedPosts = {};
  Set<String> _savedPosts = {};
  Set<String> _followingUsers = {};
  final ScrollController _scrollController = ScrollController();
  int _currentOffset = 0;
  final int _postsPerPage = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _showSecondaryHeader = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _isLoading = true;
        _posts.clear();
        _currentOffset = 0;
        _hasMore = true;
      });
      _loadPosts();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMore) _loadMorePosts();
    }
    final currentOffset = _scrollController.offset;
    if (currentOffset > _lastScrollOffset && currentOffset > 100) {
      if (_showSecondaryHeader) setState(() => _showSecondaryHeader = false);
    } else if (currentOffset < _lastScrollOffset) {
      if (!_showSecondaryHeader) setState(() => _showSecondaryHeader = true);
    }
    _lastScrollOffset = currentOffset;
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await _loadUserInteractions(user.id);
      if (_tabController.index == 0) {
        await _loadForYouPosts(user.id);
      } else {
        await _loadFollowingPosts(user.id);
      }
      await _incrementViewCounts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _incrementViewCounts() async {
    for (var post in _posts) {
      try {
        await Supabase.instance.client.rpc('increment_post_views', params: {'post_id_param': post['post_id']});
      } catch (e) {
        debugPrint('Error incrementing view: $e');
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      _currentOffset += _postsPerPage;
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      if (_tabController.index == 0) {
        await _loadForYouPosts(user.id);
      } else {
        await _loadFollowingPosts(user.id);
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadUserInteractions(String userId) async {
    final likesRes = await Supabase.instance.client.from('ngm_post_likes').select('post_id').eq('user_id', userId);
    _likedPosts = Set<String>.from((likesRes as List).map((e) => e['post_id'].toString()));

    final savesRes = await Supabase.instance.client.from('ngm_saved_posts').select('post_id').eq('user_id', userId);
    _savedPosts = Set<String>.from((savesRes as List).map((e) => e['post_id'].toString()));

    final followRes = await Supabase.instance.client.from('ngm_user_followers').select('following_user_id').eq('follower_user_id', userId);
    _followingUsers = Set<String>.from((followRes as List).map((e) => e['following_user_id'].toString()));
  }

  Future<void> _loadForYouPosts(String userId) async {
    final response = await Supabase.instance.client
        .from('ngm_user_posts')
        .select('*, ngm_users(user_id, full_name, username, profile_picture_url, is_verified)')
        .eq('post_type', 'post').eq('is_public', true)
        .order('created_at', ascending: false)
        .range(_currentOffset, _currentOffset + _postsPerPage - 1);
    if (response.isEmpty || (response as List).length < _postsPerPage) _hasMore = false;
    setState(() { _posts.addAll(List<Map<String, dynamic>>.from(response)); });
  }

  Future<void> _loadFollowingPosts(String userId) async {
    final followRes = await Supabase.instance.client.from('ngm_user_followers').select('following_user_id').eq('follower_user_id', userId);
    if ((followRes as List).isEmpty) { _hasMore = false; setState(() {}); return; }
    final ids = followRes.map((e) => e['following_user_id']).toList();
    final response = await Supabase.instance.client
        .from('ngm_user_posts')
        .select('*, ngm_users(user_id, full_name, username, profile_picture_url, is_verified)')
        .inFilter('user_id', ids).eq('post_type', 'post').eq('is_public', true)
        .order('created_at', ascending: false)
        .range(_currentOffset, _currentOffset + _postsPerPage - 1);
    if (response.isEmpty || (response as List).length < _postsPerPage) _hasMore = false;
    setState(() { _posts.addAll(List<Map<String, dynamic>>.from(response)); });
  }

  Future<void> _toggleLike(String postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final isLiked = _likedPosts.contains(postId);
    try {
      if (isLiked) {
        await Supabase.instance.client.from('ngm_post_likes').delete().eq('post_id', postId).eq('user_id', user.id);
        setState(() {
          _likedPosts.remove(postId);
          final i = _posts.indexWhere((p) => p['post_id'] == postId);
          if (i != -1) _posts[i]['likes_count'] = (_posts[i]['likes_count'] ?? 1) - 1;
        });
      } else {
        await Supabase.instance.client.from('ngm_post_likes').insert({'post_id': postId, 'user_id': user.id});
        setState(() {
          _likedPosts.add(postId);
          final i = _posts.indexWhere((p) => p['post_id'] == postId);
          if (i != -1) _posts[i]['likes_count'] = (_posts[i]['likes_count'] ?? 0) + 1;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleSave(String postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final isSaved = _savedPosts.contains(postId);
    try {
      if (isSaved) {
        await Supabase.instance.client.from('ngm_saved_posts').delete().eq('post_id', postId).eq('user_id', user.id);
        setState(() => _savedPosts.remove(postId));
      } else {
        await Supabase.instance.client.from('ngm_saved_posts').insert({'post_id': postId, 'user_id': user.id});
        setState(() => _savedPosts.add(postId));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleFollow(String userId, String targetUserId) async {
    final isFollowing = _followingUsers.contains(targetUserId);
    try {
      if (isFollowing) {
        await Supabase.instance.client.from('ngm_user_followers').delete()
            .eq('follower_user_id', userId).eq('following_user_id', targetUserId);
        setState(() => _followingUsers.remove(targetUserId));
      } else {
        await Supabase.instance.client.from('ngm_user_followers')
            .insert({'follower_user_id': userId, 'following_user_id': targetUserId});
        setState(() => _followingUsers.add(targetUserId));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reportPost(String postId) async {
    final t = context.read<ThemeProvider>();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Report Post', style: TextStyle(color: t.text1)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('Spam',                   style: TextStyle(color: t.text1)), onTap: () => Navigator.pop(context, 'spam')),
          ListTile(title: Text('Inappropriate Content',  style: TextStyle(color: t.text1)), onTap: () => Navigator.pop(context, 'inappropriate')),
          ListTile(title: Text('Harassment',             style: TextStyle(color: t.text1)), onTap: () => Navigator.pop(context, 'harassment')),
          ListTile(title: Text('Other',                  style: TextStyle(color: t.text1)), onTap: () => Navigator.pop(context, 'other')),
        ]),
      ),
    );
    if (reason != null) {
      try {
        await Supabase.instance.client.from('ngm_post_reports').insert({
          'post_id': postId, 'reported_by': user.id,
          'report_reason': reason, 'status': 'pending',
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post reported successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addInterest(String postId, Map<String, dynamic> post) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final content = post['content'] ?? '';
      await Supabase.instance.client.from('ngm_user_interests').insert({
        'user_id': user.id, 'interest_type': 'post_interaction',
        'interest_value': content.substring(0, content.length > 50 ? 50 : content.length),
        'score': 1,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interest added')));
    } catch (e) { debugPrint('Error adding interest: $e'); }
  }

  void _showCommentsBottomSheet(String postId) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => CommentsBottomSheet(postId: postId));
  }

  void _showShareBottomSheet(String postId, Map<String, dynamic> post) {
    showShareSheet(context, ShareContent(
      type: 'link',
      link: 'https://kapilalearning.vercel.app/post/$postId',
      text: post['content'],
    ));
  }

  void _launchURL(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'https://$url';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            toolbarHeight: 50,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: t.isDark
                    ? [const Color(0xFF1C1035), t.surface]
                    : [const Color(0xFFE8E4FF), t.surface]),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
                  ),
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
              ),
            ),
            title: Text('Nandigram',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: t.text1, letterSpacing: 0.5)),
            actions: [
              IconButton(icon: Icon(Icons.search, color: t.text1, size: 22),
                  onPressed: () => Navigator.pushNamed(context, '/global_search')),
              IconButton(icon: Icon(Icons.add_circle_outline, color: t.text1, size: 22),
                  onPressed: () => Navigator.pushNamed(context, '/create_post')),
              const SizedBox(width: 4),
            ],
          ),

          if (_showSecondaryHeader)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SecondaryHeaderDelegate(tabController: _tabController, t: t),
            ),

          _isLoading
              ? SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: t.brand)))
              : _posts.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState(t))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          const suggestionInterval = 12;
                          final suggestionCount = index ~/ (suggestionInterval + 1);
                          final postIndex = index - suggestionCount;
                          if (index > 0 && (index % (suggestionInterval + 1) == suggestionInterval)) {
                            return _buildAccountSuggestion(t);
                          }
                          if (postIndex == _posts.length) {
                            return _isLoadingMore
                                ? Center(child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: CircularProgressIndicator(color: t.brand)))
                                : const SizedBox.shrink();
                          }
                          if (postIndex < _posts.length) return _buildPostCard(_posts[postIndex], t);
                          return const SizedBox.shrink();
                        },
                        childCount: _posts.length + (_posts.length ~/ 12) + (_isLoadingMore ? 1 : 0),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildAccountSuggestion(ThemeProvider t) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border), bottom: BorderSide(color: t.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Suggested for you',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.text1)),
              TextButton(onPressed: () {},
                  child: Text('See all', style: TextStyle(fontSize: 14, color: t.accent))),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchRandomSuggestion(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final user = snapshot.data!;
              return Row(children: [
                CircleAvatar(
                  radius: 24, backgroundColor: t.brand,
                  backgroundImage: user['profile_picture_url'] != null
                      ? CachedNetworkImageProvider(user['profile_picture_url']) : null,
                  child: user['profile_picture_url'] == null
                      ? Text((user['full_name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(user['full_name'] ?? user['username'] ?? 'User',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text1),
                        overflow: TextOverflow.ellipsis)),
                    if (user['is_verified'] == true) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified, color: t.brand, size: 16),
                    ],
                  ]),
                  Text('@${user['username'] ?? 'user'}',
                      style: TextStyle(fontSize: 13, color: t.text2)),
                ])),
                ElevatedButton(
                  onPressed: () async {
                    final cu = Supabase.instance.client.auth.currentUser;
                    if (cu != null) await _toggleFollow(cu.id, user['user_id']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.brand, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text('Follow', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchRandomSuggestion() async {
    try {
      final cu = Supabase.instance.client.auth.currentUser;
      if (cu == null) return null;
      final res = await Supabase.instance.client.from('ngm_users')
          .select('user_id, full_name, username, profile_picture_url, is_verified, followers_count')
          .neq('user_id', cu.id).order('followers_count', ascending: false).limit(20);
      if ((res as List).isEmpty) return null;
      final users = List<Map<String, dynamic>>.from(res);
      return users[DateTime.now().microsecondsSinceEpoch % users.length];
    } catch (e) { return null; }
  }

  Widget _buildEmptyState(ThemeProvider t) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.article_outlined, size: 80, color: t.text2.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text(_tabController.index == 0 ? 'કોઈ posts નથી' : 'કોઈ following posts નથી',
            style: TextStyle(fontSize: 18, color: t.text2)),
        const SizedBox(height: 8),
        Text(_tabController.index == 0 ? 'Posts અહીં દેખાશે' : 'Follow કરો posts જોવા માટે',
            style: TextStyle(fontSize: 14, color: t.text2.withOpacity(0.7))),
      ]),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, ThemeProvider t) {
    final user         = post['ngm_users'];
    final currentUser  = Supabase.instance.client.auth.currentUser;
    final userName     = user['full_name'] ?? user['username'] ?? 'User';
    final username     = user['username'] ?? 'user';
    final profilePic   = user['profile_picture_url'];
    final isVerified   = user['is_verified'] ?? false;
    final content      = post['content'] ?? '';
    final mediaUrl     = post['media_url'];
    final likesCount   = post['likes_count'] ?? 0;
    final commentsCount = post['comments_count'] ?? 0;
    final viewsCount   = post['views_count'] ?? 0;
    final createdAt    = DateTime.parse(post['created_at']);
    final postId       = post['post_id'];
    final postUserId   = user['user_id'];
    final isLiked      = _likedPosts.contains(postId);
    final isSaved      = _savedPosts.contains(postId);

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20, backgroundColor: t.brand,
            backgroundImage: profilePic != null ? CachedNetworkImageProvider(profilePic) : null,
            child: profilePic == null
                ? Text(userName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(userName,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.text1),
                  overflow: TextOverflow.ellipsis)),
              if (isVerified) ...[
                const SizedBox(width: 4),
                Icon(Icons.verified, color: t.brand, size: 18),
              ],
            ]),
            Text('@$username · ${timeago.format(createdAt, locale: 'en_short')}',
                style: TextStyle(fontSize: 14, color: t.text2)),
          ])),
          IconButton(
            icon: Icon(Icons.more_vert, size: 20, color: t.text2),
            onPressed: () => _showPostMenu(postId, postUserId, post, currentUser?.id, t)),
        ]),

        if (content.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildContentWithLinks(content, t),
        ],

        if (mediaUrl != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: mediaUrl, fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 200, color: t.surface2,
                child: Center(child: CircularProgressIndicator(color: t.brand))),
              errorWidget: (_, __, ___) => Container(
                height: 200, color: t.surface2,
                child: Icon(Icons.error, color: t.text2)),
            ),
          ),
        ],

        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionButton(icon: Icons.chat_bubble_outline, count: commentsCount, t: t,
                onTap: () => _showCommentsBottomSheet(postId)),
            _buildActionButton(icon: isLiked ? Icons.favorite : Icons.favorite_border,
                count: likesCount, color: isLiked ? Colors.pinkAccent : null, t: t,
                onTap: () => _toggleLike(postId)),
            _buildActionButton(icon: Icons.visibility_outlined, count: viewsCount, t: t, onTap: () {}),
            _buildActionButton(icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: isSaved ? t.accent : null, t: t, onTap: () => _toggleSave(postId)),
            _buildActionButton(icon: Icons.share_outlined, t: t,
                onTap: () => _showShareBottomSheet(postId, post)),
          ],
        ),
      ]),
    );
  }

  Widget _buildContentWithLinks(String content, ThemeProvider t) {
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)|([a-zA-Z0-9-]+\.(com|org|net|io|in|co\.in)[^\s]*)',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    int lastIndex = 0;
    for (final match in urlRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: content.substring(lastIndex, match.start),
            style: TextStyle(fontSize: 15, color: t.text1, height: 1.3)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(fontSize: 15, color: Color(0xFF60AAFF), decoration: TextDecoration.underline, height: 1.3),
        recognizer: TapGestureRecognizer()..onTap = () => _launchURL(match.group(0)!),
      ));
      lastIndex = match.end;
    }
    if (lastIndex < content.length) {
      spans.add(TextSpan(text: content.substring(lastIndex),
          style: TextStyle(fontSize: 15, color: t.text1, height: 1.3)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  void _showPostMenu(String postId, String postUserId, Map<String, dynamic> post, String? currentUserId, ThemeProvider t) {
    final isOwnPost    = currentUserId == postUserId;
    final isFollowing  = _followingUsers.contains(postUserId);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!isOwnPost) ...[
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            title: Text('Report', style: TextStyle(color: t.text1)),
            onTap: () { Navigator.pop(context); _reportPost(postId); }),
          ListTile(
            leading: Icon(isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined, color: t.text1),
            title: Text(isFollowing ? 'Unfollow' : 'Follow', style: TextStyle(color: t.text1)),
            onTap: () { Navigator.pop(context); if (currentUserId != null) _toggleFollow(currentUserId, postUserId); }),
          ListTile(
            leading: Icon(Icons.interests_outlined, color: t.text1),
            title: Text('Add Interest', style: TextStyle(color: t.text1)),
            onTap: () { Navigator.pop(context); _addInterest(postId, post); }),
        ],
        const SizedBox(height: 8),
      ])),
    );
  }

  Widget _buildActionButton({required IconData icon, int? count, Color? color, required ThemeProvider t, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: color ?? t.text2),
          if (count != null && count > 0) ...[
            const SizedBox(width: 4),
            Text(_formatCount(count), style: TextStyle(fontSize: 13, color: color ?? t.text2)),
          ],
        ]),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

// ═══════════════════════════════════════════
//  Secondary Header Delegate
// ═══════════════════════════════════════════
class _SecondaryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final ThemeProvider t;
  _SecondaryHeaderDelegate({required this.tabController, required this.t});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: TabBar(
        controller: tabController,
        indicatorColor: t.brand,
        indicatorWeight: 3,
        labelColor: t.text1,
        unselectedLabelColor: t.text2,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        tabs: const [Tab(text: 'For You'), Tab(text: 'Following')],
      ),
    );
  }

  @override double get maxExtent => 48.0;
  @override double get minExtent => 48.0;
  @override bool shouldRebuild(covariant SliverPersistentHeaderDelegate old) => true;
}

// ═══════════════════════════════════════════
//  Comments Bottom Sheet
// ═══════════════════════════════════════════
class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  const CommentsBottomSheet({super.key, required this.postId});
  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadComments(); }

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _loadComments() async {
    try {
      final res = await Supabase.instance.client
          .from('ngm_post_comments')
          .select('*, ngm_users(user_id, full_name, username, profile_picture_url, is_verified)')
          .eq('post_id', widget.postId).order('created_at', ascending: false);
      setState(() { _comments = List<Map<String, dynamic>>.from(res); _isLoading = false; });
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _postComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('ngm_post_comments').insert({
        'post_id': widget.postId, 'user_id': user.id,
        'comment_text': _commentCtrl.text.trim(),
      });
      _commentCtrl.clear();
      _loadComments();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text1)),
              IconButton(icon: Icon(Icons.close, color: t.text2), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: t.brand))
                : _comments.isEmpty
                    ? Center(child: Text('No comments yet', style: TextStyle(color: t.text2)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final comment = _comments[i];
                          final user    = comment['ngm_users'];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: t.brand,
                              backgroundImage: user['profile_picture_url'] != null
                                  ? CachedNetworkImageProvider(user['profile_picture_url']) : null,
                              child: user['profile_picture_url'] == null
                                  ? Text(user['full_name']?[0] ?? 'U',
                                      style: const TextStyle(color: Colors.white)) : null),
                            title: Text(user['full_name'] ?? user['username'] ?? 'User',
                                style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
                            subtitle: Text(comment['comment_text'],
                                style: TextStyle(color: t.text2)),
                          );
                        }),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(top: BorderSide(color: t.border))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  style: TextStyle(color: t.text1),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: t.text2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: t.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: t.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: t.brand)),
                    filled: true, fillColor: t.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(icon: Icon(Icons.send, color: t.brand), onPressed: _postComment),
            ]),
          ),
        ]),
      ),
    );
  }
}