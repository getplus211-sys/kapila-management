import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isDarkMode = false;

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
    // Handle infinite scroll
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMore) {
        _loadMorePosts();
      }
    }

    // Handle secondary header show/hide
    final currentOffset = _scrollController.offset;
    if (currentOffset > _lastScrollOffset && currentOffset > 100) {
      // Scrolling down
      if (_showSecondaryHeader) {
        setState(() => _showSecondaryHeader = false);
      }
    } else if (currentOffset < _lastScrollOffset) {
      // Scrolling up
      if (!_showSecondaryHeader) {
        setState(() => _showSecondaryHeader = true);
      }
    }
    _lastScrollOffset = currentOffset;
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Load user interactions
      await _loadUserInteractions(user.id);

      // Load posts based on tab
      if (_tabController.index == 0) {
        await _loadForYouPosts(user.id);
      } else {
        await _loadFollowingPosts(user.id);
      }

      // Increment view counts for loaded posts
      await _incrementViewCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _incrementViewCounts() async {
    for (var post in _posts) {
      try {
        await Supabase.instance.client.rpc('increment_post_views', params: {
          'post_id_param': post['post_id'],
        });
      } catch (e) {
        debugPrint('Error incrementing view for post ${post['post_id']}: $e');
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
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadUserInteractions(String userId) async {
    // Load liked posts
    final likesResponse = await Supabase.instance.client
        .from('ngm_post_likes')
        .select('post_id')
        .eq('user_id', userId);

    _likedPosts = Set<String>.from(
      (likesResponse as List).map((e) => e['post_id'].toString()),
    );

    // Load saved posts
    final savesResponse = await Supabase.instance.client
        .from('ngm_saved_posts')
        .select('post_id')
        .eq('user_id', userId);

    _savedPosts = Set<String>.from(
      (savesResponse as List).map((e) => e['post_id'].toString()),
    );

    // Load following users
    final followingResponse = await Supabase.instance.client
        .from('ngm_user_followers')
        .select('following_user_id')
        .eq('follower_user_id', userId);

    _followingUsers = Set<String>.from(
      (followingResponse as List).map((e) => e['following_user_id'].toString()),
    );
  }

  Future<void> _loadForYouPosts(String userId) async {
    final response = await Supabase.instance.client
        .from('ngm_user_posts')
        .select('''
          *,
          ngm_users(user_id, full_name, username, profile_picture_url, is_verified)
        ''')
        .eq('post_type', 'post')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .range(_currentOffset, _currentOffset + _postsPerPage - 1);

    if (response.isEmpty || (response as List).length < _postsPerPage) {
      _hasMore = false;
    }

    setState(() {
      _posts.addAll(List<Map<String, dynamic>>.from(response));
    });
  }

  Future<void> _loadFollowingPosts(String userId) async {
    // Get following users
    final followingResponse = await Supabase.instance.client
        .from('ngm_user_followers')
        .select('following_user_id')
        .eq('follower_user_id', userId);

    if ((followingResponse as List).isEmpty) {
      _hasMore = false;
      setState(() {});
      return;
    }

    final followingIds = followingResponse.map((e) => e['following_user_id']).toList();

    final response = await Supabase.instance.client
        .from('ngm_user_posts')
        .select('''
          *,
          ngm_users(user_id, full_name, username, profile_picture_url, is_verified)
        ''')
        .inFilter('user_id', followingIds)
        .eq('post_type', 'post')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .range(_currentOffset, _currentOffset + _postsPerPage - 1);

    if (response.isEmpty || (response as List).length < _postsPerPage) {
      _hasMore = false;
    }

    setState(() {
      _posts.addAll(List<Map<String, dynamic>>.from(response));
    });
  }

  Future<void> _toggleLike(String postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final isLiked = _likedPosts.contains(postId);

    try {
      if (isLiked) {
        await Supabase.instance.client
            .from('ngm_post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);

        setState(() {
          _likedPosts.remove(postId);
          final index = _posts.indexWhere((p) => p['post_id'] == postId);
          if (index != -1) {
            _posts[index]['likes_count'] = (_posts[index]['likes_count'] ?? 1) - 1;
          }
        });
      } else {
        await Supabase.instance.client
            .from('ngm_post_likes')
            .insert({'post_id': postId, 'user_id': user.id});

        setState(() {
          _likedPosts.add(postId);
          final index = _posts.indexWhere((p) => p['post_id'] == postId);
          if (index != -1) {
            _posts[index]['likes_count'] = (_posts[index]['likes_count'] ?? 0) + 1;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleSave(String postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final isSaved = _savedPosts.contains(postId);

    try {
      if (isSaved) {
        await Supabase.instance.client
            .from('ngm_saved_posts')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);

        setState(() => _savedPosts.remove(postId));
      } else {
        await Supabase.instance.client
            .from('ngm_saved_posts')
            .insert({'post_id': postId, 'user_id': user.id});

        setState(() => _savedPosts.add(postId));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleFollow(String userId, String targetUserId) async {
    final isFollowing = _followingUsers.contains(targetUserId);

    try {
      if (isFollowing) {
        await Supabase.instance.client
            .from('ngm_user_followers')
            .delete()
            .eq('follower_user_id', userId)
            .eq('following_user_id', targetUserId);

        setState(() => _followingUsers.remove(targetUserId));
      } else {
        await Supabase.instance.client
            .from('ngm_user_followers')
            .insert({
          'follower_user_id': userId,
          'following_user_id': targetUserId,
        });

        setState(() => _followingUsers.add(targetUserId));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _reportPost(String postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Spam'),
              onTap: () => Navigator.pop(context, 'spam'),
            ),
            ListTile(
              title: const Text('Inappropriate Content'),
              onTap: () => Navigator.pop(context, 'inappropriate'),
            ),
            ListTile(
              title: const Text('Harassment'),
              onTap: () => Navigator.pop(context, 'harassment'),
            ),
            ListTile(
              title: const Text('Other'),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
      ),
    );

    if (reason != null) {
      try {
        await Supabase.instance.client.from('ngm_post_reports').insert({
          'post_id': postId,
          'reported_by': user.id,
          'report_reason': reason,
          'status': 'pending',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post reported successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _addInterest(String postId, Map<String, dynamic> post) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Extract interest from post content or hashtags
      final content = post['content'] ?? '';
      await Supabase.instance.client.from('ngm_user_interests').insert({
        'user_id': user.id,
        'interest_type': 'post_interaction',
        'interest_value': content.substring(0, content.length > 50 ? 50 : content.length),
        'score': 1,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interest added')),
        );
      }
    } catch (e) {
      debugPrint('Error adding interest: $e');
    }
  }

  void _showCommentsBottomSheet(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(postId: postId),
    );
  }

  void _showShareBottomSheet(String postId, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ShareBottomSheet(postId: postId, post: post),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF000000) : Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(), // Twitter જેવો smooth scroll
        slivers: [
          // Main Header with Glassmorphic Effect
          SliverAppBar(
            pinned: true,
            floating: false,
            toolbarHeight: 50,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: _isDarkMode
                    ? const LinearGradient(
                        colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
              ),
              child: ClipRRect(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _isDarkMode
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.08), // 0.05 થી 0.08
                              Colors.white.withOpacity(0.04), // 0.02 થી 0.04
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.35), // 0.2 થી 0.35
                              Colors.white.withOpacity(0.15), // 0.05 થી 0.15
                            ],
                          ),
                    border: Border(
                      bottom: BorderSide(
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            title: const Text(
              'Nandigram',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600, // w900 થી w600 કર્યું
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            actions: [
              // Search Button
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 22),
                onPressed: () {
                  Navigator.pushNamed(context, '/global_search');
                },
              ),
              // Dark/Light Mode Toggle
              IconButton(
                icon: Icon(
                  _isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () {
                  setState(() => _isDarkMode = !_isDarkMode);
                },
              ),
              // Add Post Button
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                onPressed: () {
                  Navigator.pushNamed(context, '/create_post');
                },
              ),
              const SizedBox(width: 4),
            ],
          ),

          // Secondary Header (For You / Following)
          if (_showSecondaryHeader)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SecondaryHeaderDelegate(
                tabController: _tabController,
                isDarkMode: _isDarkMode,
              ),
            ),

          // Content
          _isLoading
              ? SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _isDarkMode ? Colors.white : const Color(0xFF8B5CF6),
                    ),
                  ),
                )
              : _posts.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // Calculate actual post index accounting for suggestions
                          final suggestionInterval = 12; // દર 12 posts પછી 1 suggestion
                          final suggestionCount = index ~/ (suggestionInterval + 1);
                          final postIndex = index - suggestionCount;
                          
                          // Check if this should be a suggestion card
                          if (index > 0 && (index % (suggestionInterval + 1) == suggestionInterval)) {
                            return _buildAccountSuggestion();
                          }
                          
                          // Loading indicator at end
                          if (postIndex == _posts.length) {
                            return _isLoadingMore
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(
                                        color: _isDarkMode ? Colors.white : const Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          
                          // Regular post
                          if (postIndex < _posts.length) {
                            return _buildPostCard(_posts[postIndex]);
                          }
                          
                          return const SizedBox.shrink();
                        },
                        childCount: _posts.length + (_posts.length ~/ 12) + (_isLoadingMore ? 1 : 0),
                      ),
                    ),
        ],
      ),
    );
  }

  // Account Suggestion Card (દર 12 posts પછી)
  Widget _buildAccountSuggestion() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          bottom: BorderSide(
            color: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Suggested for you',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to all suggestions
                },
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Single user suggestion
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchRandomSuggestion(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              
              final user = snapshot.data!;
              return Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF8B5CF6),
                    backgroundImage: user['profile_picture_url'] != null
                        ? CachedNetworkImageProvider(user['profile_picture_url'])
                        : null,
                    child: user['profile_picture_url'] == null
                        ? Text(
                            (user['full_name'] ?? 'U')[0].toUpperCase(),
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
                                user['full_name'] ?? user['username'] ?? 'User',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _isDarkMode ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user['is_verified'] == true) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF8B5CF6),
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '@${user['username'] ?? 'user'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final currentUser = Supabase.instance.client.auth.currentUser;
                      if (currentUser != null) {
                        await _toggleFollow(currentUser.id, user['user_id']);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Random user suggestion fetch કરવા માટે
  Future<Map<String, dynamic>?> _fetchRandomSuggestion() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return null;

      final response = await Supabase.instance.client
          .from('ngm_users')
          .select('user_id, full_name, username, profile_picture_url, is_verified, followers_count')
          .neq('user_id', currentUser.id)
          .order('followers_count', ascending: false)
          .limit(20);

      if ((response as List).isEmpty) return null;

      final users = List<Map<String, dynamic>>.from(response);
      final randomIndex = DateTime.now().microsecondsSinceEpoch % users.length;
      return users[randomIndex];
    } catch (e) {
      debugPrint('Error fetching suggestion: $e');
      return null;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 80,
            color: _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _tabController.index == 0 ? 'કોઈ posts નથી' : 'કોઈ following posts નથી',
            style: TextStyle(
              fontSize: 18,
              color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tabController.index == 0
                ? 'Posts અહીં દેખાશે'
                : 'Follow કરો posts જોવા માટે',
            style: TextStyle(
              fontSize: 14,
              color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final user = post['ngm_users'];
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userName = user['full_name'] ?? user['username'] ?? 'User';
    final username = user['username'] ?? 'user';
    final profilePic = user['profile_picture_url'];
    final isVerified = user['is_verified'] ?? false;
    final content = post['content'] ?? '';
    final mediaUrl = post['media_url'];
    final likesCount = post['likes_count'] ?? 0;
    final commentsCount = post['comments_count'] ?? 0;
    final viewsCount = post['views_count'] ?? 0;
    final createdAt = DateTime.parse(post['created_at']);
    final postId = post['post_id'];
    final postUserId = user['user_id'];
    final isLiked = _likedPosts.contains(postId);
    final isSaved = _savedPosts.contains(postId);
    final isFollowing = _followingUsers.contains(postUserId);

    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  // Navigate to user profile
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFFF6F00),
                  backgroundImage: profilePic != null
                      ? CachedNetworkImageProvider(profilePic)
                      : null,
                  child: profilePic == null
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
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
                            userName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _isDarkMode ? Colors.white : const Color(0xFF0f1419),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFFFF6F00),
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '@$username · ${timeago.format(createdAt, locale: 'en_short')}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkMode ? Colors.grey.shade400 : const Color(0xFF536471),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                onPressed: () {
                  _showPostMenu(postId, postUserId, post, currentUser?.id);
                },
              ),
            ],
          ),

          // Content with clickable URLs
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContentWithLinks(content),
          ],

          // Media
          if (mediaUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _isDarkMode ? Colors.white : const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  child: const Icon(Icons.error),
                ),
              ),
            ),
          ],

          // Actions with Views
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                count: commentsCount,
                onTap: () => _showCommentsBottomSheet(postId),
              ),
              _buildActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                count: likesCount,
                color: isLiked ? const Color(0xFFFF6F00) : null,
                onTap: () => _toggleLike(postId),
              ),
              _buildActionButton(
                icon: Icons.visibility_outlined,
                count: viewsCount,
                onTap: () {}, // No action for views
              ),
              _buildActionButton(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: isSaved ? const Color(0xFFFF6F00) : null,
                onTap: () => _toggleSave(postId),
              ),
              _buildActionButton(
                icon: Icons.share_outlined,
                onTap: () => _showShareBottomSheet(postId, post),
              ),
            ],
          ),
        ],
      ),
    );
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
          style: TextStyle(
            fontSize: 15,
            color: _isDarkMode ? Colors.white : const Color(0xFF0f1419),
            height: 1.3,
          ),
        ));
      }

      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1DA1F2),
          decoration: TextDecoration.underline,
          height: 1.3,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchURL(match.group(0)!),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: TextStyle(
          fontSize: 15,
          color: _isDarkMode ? Colors.white : const Color(0xFF0f1419),
          height: 1.3,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  void _showPostMenu(String postId, String postUserId, Map<String, dynamic> post, String? currentUserId) {
    final isOwnPost = currentUserId == postUserId;
    final isFollowing = _followingUsers.contains(postUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isOwnPost) ...[
              ListTile(
                leading: Icon(
                  Icons.flag_outlined,
                  color: _isDarkMode ? Colors.red.shade300 : Colors.red,
                ),
                title: Text(
                  'Report',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(postId);
                },
              ),
              ListTile(
                leading: Icon(
                  isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
                title: Text(
                  isFollowing ? 'Unfollow' : 'Follow',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (currentUserId != null) {
                    _toggleFollow(currentUserId, postUserId);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.interests_outlined,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
                title: Text(
                  'Add Interest',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addInterest(postId, post);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    int? count,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: color ?? (_isDarkMode ? Colors.grey.shade400 : const Color(0xFF536471)),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(count),
                style: TextStyle(
                  fontSize: 13,
                  color: color ?? (_isDarkMode ? Colors.grey.shade400 : const Color(0xFF536471)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

// Secondary Header Delegate
class _SecondaryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final bool isDarkMode;

  _SecondaryHeaderDelegate({required this.tabController, required this.isDarkMode});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? const LinearGradient(
                colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
              )
            : const LinearGradient(
                colors: [Color(0xFFF5F5F5), Color(0xFFFFFFFF)],
              ),
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: Container(
          decoration: BoxDecoration(
            gradient: isDarkMode
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.white.withOpacity(0.01),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.5),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
          ),
          child: TabBar(
            controller: tabController,
            indicatorColor: const Color(0xFF8B5CF6),
            indicatorWeight: 3,
            labelColor: isDarkMode ? Colors.white : const Color(0xFF8B5CF6),
            unselectedLabelColor: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'For You'),
              Tab(text: 'Following'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 48.0;

  @override
  double get minExtent => 48.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

// Comments Bottom Sheet
class CommentsBottomSheet extends StatefulWidget {
  final String postId;

  const CommentsBottomSheet({super.key, required this.postId});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
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
          .select('''
            *,
            ngm_users(user_id, full_name, username, profile_picture_url, is_verified)
          ''')
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
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? const Center(child: Text('No comments yet'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final user = comment['ngm_users'];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['profile_picture_url'] != null
                                    ? CachedNetworkImageProvider(user['profile_picture_url'])
                                    : null,
                                child: user['profile_picture_url'] == null
                                    ? Text(user['full_name']?[0] ?? 'U')
                                    : null,
                              ),
                              title: Text(
                                user['full_name'] ?? user['username'] ?? 'User',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(comment['comment_text']),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF8B5CF6)),
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

// Share Bottom Sheet
class ShareBottomSheet extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> post;

  const ShareBottomSheet({super.key, required this.postId, required this.post});

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  List<Map<String, dynamic>> _followers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('ngm_user_followers')
          .select('''
            following_user_id,
            ngm_users!ngm_user_followers_following_user_id_fkey(user_id, full_name, username, profile_picture_url)
          ''')
          .eq('follower_user_id', user.id);

      setState(() {
        _followers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareWithUser(String userId) async {
    // Implement share functionality (create a chat message or send notification)
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post shared successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Share with',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const CircularProgressIndicator()
          else if (_followers.isEmpty)
            const Text('No followers to share with')
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _followers.length,
                itemBuilder: (context, index) {
                  final follower = _followers[index]['ngm_users'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: follower['profile_picture_url'] != null
                          ? CachedNetworkImageProvider(follower['profile_picture_url'])
                          : null,
                      child: follower['profile_picture_url'] == null
                          ? Text(follower['full_name']?[0] ?? 'U')
                          : null,
                    ),
                    title: Text(follower['full_name'] ?? follower['username'] ?? 'User'),
                    subtitle: Text('@${follower['username'] ?? ''}'),
                    onTap: () => _shareWithUser(follower['user_id']),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}