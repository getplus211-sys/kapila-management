import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_stories_screen.dart';
import 'chat_list_screen.dart';

class AllStoriesScreen extends StatefulWidget {
  const AllStoriesScreen({super.key});

  @override
  State<AllStoriesScreen> createState() => _AllStoriesScreenState();
}

class _AllStoriesScreenState extends State<AllStoriesScreen> {
  final _supabase = Supabase.instance.client;
  List<StoryUser> _stories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      setState(() => _isLoading = true);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load stories from contacts
      final contacts = await _supabase
          .from('ngm_contacts')
          .select('contact_user_id')
          .eq('user_id', userId);

      final contactIds = contacts.map((c) => c['contact_user_id'] as String).toList();

      if (contactIds.isEmpty) {
        setState(() {
          _stories = [];
          _isLoading = false;
        });
        return;
      }

      final contactStories = await _supabase
          .from('ngm_stories')
          .select('*, ngm_users!inner(full_name, username, profile_picture_url)')
          .filter('user_id', 'in', '(${contactIds.join(',')})')
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      // Group by user
      final Map<String, List<dynamic>> storiesByUser = {};
      for (var story in contactStories) {
        final uid = story['user_id'];
        if (!storiesByUser.containsKey(uid)) {
          storiesByUser[uid] = [];
        }
        storiesByUser[uid]!.add(story);
      }

      final List<StoryUser> storyUsers = [];

      for (var entry in storiesByUser.entries) {
        final userStories = entry.value;
        final userData = userStories.first['ngm_users'];

        // Check viewed status
        final viewedCount = await _supabase
            .from('ngm_story_views')
            .select('story_id')
            .eq('viewer_id', userId)
            .filter('story_id', 'in', '(${userStories.map((s) => s['story_id']).join(',')})');

        final isViewed = viewedCount.length == userStories.length;

        storyUsers.add(StoryUser(
          userId: entry.key,
          userName: userData['full_name'] ?? userData['username'] ?? 'Unknown',
          userImage: userData['profile_picture_url'],
          storyCount: userStories.length,
          lastStoryTime: DateTime.parse(userStories.first['created_at']),
          isViewed: isViewed,
          stories: userStories,
        ));
      }

      // Sort: Unviewed first
      storyUsers.sort((a, b) {
        if (!a.isViewed && b.isViewed) return -1;
        if (a.isViewed && !b.isViewed) return 1;
        return b.lastStoryTime.compareTo(a.lastStoryTime);
      });

      setState(() {
        _stories = storyUsers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stories: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
        title: const Text('Stories', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F00)))
          : _stories.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _stories.length,
                  itemBuilder: (context, index) {
                    final story = _stories[index];
                    return _buildStoryItem(story);
                  },
                ),
    );
  }

  Widget _buildStoryItem(StoryUser story) {
    return ListTile(
      leading: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: !story.isViewed
              ? const LinearGradient(colors: [Color(0xFFFF6F00), Colors.orange])
              : null,
          border: Border.all(
            color: story.isViewed ? Colors.grey[400]! : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: CircleAvatar(
          backgroundColor: const Color(0xFFFF6F00),
          backgroundImage: story.userImage != null ? NetworkImage(story.userImage!) : null,
          child: story.userImage == null
              ? Text(
                  story.userName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
        ),
      ),
      title: Text(story.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        _formatTime(story.lastStoryTime),
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${story.storyCount}',
            style: const TextStyle(
              color: Color(0xFFFF6F00),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            story.storyCount == 1 ? 'story' : 'stories',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ViewStoriesScreen(storyUser: story)),
        ).then((_) => _loadStories());
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    
    return '${diff.inDays}d ago';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No stories yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            'Stories from your contacts will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}