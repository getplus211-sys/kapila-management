import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // null means current user's profile

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _isOwnProfile = false;
  Map<String, dynamic>? _profileUser;
  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedPosts = {};
  
  final List<String> _tabs = ['Posts', 'Replies', 'Media', 'Likes'];
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        _loadPosts();
      }
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoading = true);
      
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userId = widget.userId ?? currentUser.id;
      _isOwnProfile = userId == currentUser.id;

      final response = await _supabase
          .from('ngm_users')
          .select()
          .eq('user_id', userId)
          .single();

      setState(() {
        _profileUser = response;
        _isLoading = false;
      });

      await _loadPosts();
      await _loadLikedPosts();

    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPosts() async {
    try {
      if (_profileUser == null) return;

      // Build query step by step
      var query = _supabase
          .from('ngm_user_posts')
          .select('*, ngm_users(full_name, username, profile_picture_url, is_verified)')
          .eq('user_id', _profileUser!['user_id'])
          .eq('post_type', 'post');

      if (_currentTabIndex == 2) { // Media tab
        query = query.not('media_url', 'is', null);
      }

      // Execute query with order
      final response = await query.order('created_at', ascending: false);
      
      setState(() {
        _posts = List<Map<String, dynamic>>.from(response as List);
      });

    } catch (e) {
      debugPrint('Error loading posts: $e');
    }
  }

  Future<void> _loadLikedPosts() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final response = await _supabase
          .from('ngm_post_likes')
          .select('post_id')
          .eq('user_id', currentUser.id);

      setState(() {
        _likedPosts = (response as List)
            .map((like) => like['post_id'] as String)
            .toSet();
      });

    } catch (e) {
      debugPrint('Error loading liked posts: $e');
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || _profileUser == null) return;

      final existingFollow = await _supabase
          .from('ngm_user_followers')
          .select()
          .eq('follower_user_id', currentUser.id)
          .eq('following_user_id', _profileUser!['user_id'])
          .maybeSingle();

      if (existingFollow != null) {
        await _supabase
            .from('ngm_user_followers')
            .delete()
            .eq('follower_user_id', currentUser.id)
            .eq('following_user_id', _profileUser!['user_id']);
      } else {
        await _supabase
            .from('ngm_user_followers')
            .insert({
              'follower_user_id': currentUser.id,
              'following_user_id': _profileUser!['user_id'],
            });
      }

      _loadProfile();

    } catch (e) {
      debugPrint('Error toggling follow: $e');
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      if (_likedPosts.contains(postId)) {
        await _supabase
            .from('ngm_post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUser.id);
        
        setState(() => _likedPosts.remove(postId));
      } else {
        await _supabase
            .from('ngm_post_likes')
            .insert({'post_id': postId, 'user_id': currentUser.id});
        
        setState(() => _likedPosts.add(postId));
      }

      _loadPosts();

    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFFF6F00),
      const Color(0xFF1d9bf0),
      const Color(0xFF00ba7c),
      const Color(0xFF7856ff),
      const Color(0xFFf91880),
      const Color(0xFF00b8a9),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('User not found')),
      );
    }

    final name = _profileUser!['full_name'] ?? _profileUser!['username'] ?? 'User';
    final username = _profileUser!['username'] ?? 'user';

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(name),
            _buildProfileHeader(name, username),
          ];
        },
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
      floatingActionButton: _isOwnProfile
          ? FloatingActionButton(
              onPressed: () {
                // Navigate to create post
                Navigator.pushNamed(context, '/create_post');
              },
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAppBar(String name) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: 0.5,
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(
            '${_posts.length} ${_posts.length == 1 ? 'post' : 'posts'}',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            Share.share('Check out ${name}\'s profile!');
          },
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            if (_isOwnProfile)
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 12),
                  Text('Share Profile'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileHeader(String name, String username) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Stack(
            children: [
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6F00), Color(0xFFE65100), Color(0xFFFF8C00)],
                  ),
                ),
              ),
              Positioned(
                bottom: -67.5,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: _profileUser!['profile_picture_url'] != null
                      ? CircleAvatar(
                          radius: 67.5,
                          backgroundImage: CachedNetworkImageProvider(
                            _profileUser!['profile_picture_url'],
                          ),
                        )
                      : CircleAvatar(
                          radius: 67.5,
                          backgroundColor: _getAvatarColor(name),
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isOwnProfile)
                  OutlinedButton(
                    onPressed: () {
                      // Navigate to edit profile
                    },
                    child: const Text('Edit profile'),
                  )
                else ...[
                  ElevatedButton(
                    onPressed: _toggleFollow,
                    child: const Text('Follow'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      // Navigate to chat
                    },
                    child: const Text('Message'),
                  ),
                ],
              ],
            ),
          ),
          
          // Profile info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_profileUser!['is_verified'] == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Color(0xFF1d9bf0), size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                if (_profileUser!['bio'] != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _profileUser!['bio'],
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_profileUser!['account_created_at'] != null) ...[
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Joined ${_formatJoinDate(_profileUser!['account_created_at'])}',
                        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatItem(
                      '${_profileUser!['following_count'] ?? 0}',
                      'Following',
                      () {},
                    ),
                    const SizedBox(width: 20),
                    _buildStatItem(
                      '${_profileUser!['followers_count'] ?? 0}',
                      'Followers',
                      () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            count,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Theme.of(context).primaryColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No posts yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _isOwnProfile
                  ? 'Share your thoughts with the world'
                  : 'This user hasn\'t posted anything yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return _buildPostCard(_posts[index]);
        },
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final user = post['ngm_users'];
    final name = user['full_name'] ?? user['username'] ?? 'User';
    final username = user['username'] ?? 'user';
    final isLiked = _likedPosts.contains(post['post_id']);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to post detail
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: _getAvatarColor(name),
                backgroundImage: user['profile_picture_url'] != null
                    ? CachedNetworkImageProvider(user['profile_picture_url'])
                    : null,
                child: user['profile_picture_url'] == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Post content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (user['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Color(0xFF1d9bf0), size: 16),
                        ],
                        const SizedBox(width: 4),
                        Text(
                          '@$username',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· ${_formatTime(post['created_at'])}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
                      ],
                    ),
                    if (post['content'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        post['content'],
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                    if (post['media_url'] != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: post['media_url'],
                          fit: BoxFit.cover,
                          height: 200,
                          width: double.infinity,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(
                          Icons.comment_outlined,
                          post['comments_count'] ?? 0,
                          () {},
                        ),
                        _buildActionButton(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          post['likes_count'] ?? 0,
                          () => _toggleLike(post['post_id']),
                          color: isLiked ? Colors.pink : null,
                        ),
                        _buildActionButton(
                          Icons.share_outlined,
                          0,
                          () {
                            Share.share('Check out this post!');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, int count, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? Colors.grey[600]),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(count),
                style: TextStyle(fontSize: 13, color: color ?? Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    final date = DateTime.parse(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return '1d';
    if (diff.inDays < 7) return '${diff.inDays}d';
    
    return '${date.month}/${date.day}';
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String _formatJoinDate(String timestamp) {
    final date = DateTime.parse(timestamp);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }
}