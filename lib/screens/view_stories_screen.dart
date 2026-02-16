import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'chat_list_screen.dart';

class ViewStoriesScreen extends StatefulWidget {
  final StoryUser storyUser;

  const ViewStoriesScreen({super.key, required this.storyUser});

  @override
  State<ViewStoriesScreen> createState() => _ViewStoriesScreenState();
}

class _ViewStoriesScreenState extends State<ViewStoriesScreen> {
  final _supabase = Supabase.instance.client;
  final _replyController = TextEditingController();
  
  int _currentStoryIndex = 0;
  Timer? _timer;
  double _progress = 0.0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _markAsViewed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _progress = 0.0;
    _timer?.cancel();
    
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPaused) {
        setState(() {
          _progress += 0.01;
          if (_progress >= 1.0) {
            _nextStory();
          }
        });
      }
    });
  }

  void _pauseTimer() {
    setState(() => _isPaused = true);
  }

  void _resumeTimer() {
    setState(() => _isPaused = false);
  }

  Future<void> _markAsViewed() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final storyId = widget.storyUser.stories[_currentStoryIndex]['story_id'];

      // Check if already viewed
      final existing = await _supabase
          .from('ngm_story_views')
          .select()
          .eq('story_id', storyId)
          .eq('viewer_id', userId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('ngm_story_views').insert({
          'story_id': storyId,
          'viewer_id': userId,
        });

        // Update view count
        await _supabase.rpc('increment_story_views', params: {'story_id': storyId});
      }
    } catch (e) {
      debugPrint('Error marking story as viewed: $e');
    }
  }

  void _nextStory() {
    if (_currentStoryIndex < widget.storyUser.storyCount - 1) {
      setState(() {
        _currentStoryIndex++;
        _startTimer();
      });
      _markAsViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
        _startTimer();
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Create or get chat with story owner
      final existing = await _supabase
          .from('ngm_chats')
          .select('chat_id')
          .or('and(user1_id.eq.$userId,user2_id.eq.${widget.storyUser.userId}),and(user1_id.eq.${widget.storyUser.userId},user2_id.eq.$userId)')
          .limit(1);

      String chatId;

      if (existing.isNotEmpty) {
        chatId = existing.first['chat_id'];
      } else {
        final chat = await _supabase.from('ngm_chats').insert({
          'chat_type': 'private',
          'user1_id': userId,
          'user2_id': widget.storyUser.userId,
        }).select().single();

        chatId = chat['chat_id'];

        await _supabase.from('ngm_chat_participants').insert([
          {
            'chat_id': chatId,
            'user_id': userId,
            'is_active': true,
          },
          {
            'chat_id': chatId,
            'user_id': widget.storyUser.userId,
            'is_active': true,
          },
        ]);
      }

      // Send message
      await _supabase.from('ngm_messages').insert({
        'chat_id': chatId,
        'sender_id': userId,
        'message_type': 'text',
        'content': 'Replied to story: $text',
      });

      _replyController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent!')),
        );
      }
    } catch (e) {
      debugPrint('Error sending reply: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStory = widget.storyUser.stories[_currentStoryIndex];
    final mediaType = currentStory['media_type'];
    final mediaUrl = currentStory['media_url'];
    final caption = currentStory['caption'] ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _previousStory();
          } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
            _nextStory();
          }
        },
        onLongPressStart: (_) => _pauseTimer(),
        onLongPressEnd: (_) => _resumeTimer(),
        child: Stack(
          children: [
            // Story Content
            Center(
              child: _buildStoryContent(mediaType, mediaUrl, caption),
            ),

            // Progress Bars
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(
                  widget.storyUser.storyCount,
                  (index) => Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: LinearProgressIndicator(
                        value: index < _currentStoryIndex
                            ? 1.0
                            : (index == _currentStoryIndex ? _progress : 0.0),
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Header
            Positioned(
              top: 50,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFFF6F00),
                    backgroundImage: widget.storyUser.userImage != null
                        ? NetworkImage(widget.storyUser.userImage!)
                        : null,
                    child: widget.storyUser.userImage == null
                        ? Text(
                            widget.storyUser.userName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.storyUser.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatTime(DateTime.parse(currentStory['created_at'])),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showStoryOptions(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Reply Input
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Reply to ${widget.storyUser.userName}...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendReply,
                        ),
                      ),
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.white, size: 28),
                    onPressed: () {
                      // TODO: React to story
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(String mediaType, String? mediaUrl, String caption) {
    if (mediaType == 'text') {
      return Container(
        color: const Color(0xFFFF6F00),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              caption,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else if (mediaType == 'photo' && mediaUrl != null) {
      return Stack(
        children: [
          Image.network(
            mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.broken_image, size: 100, color: Colors.white54),
              );
            },
          ),
          if (caption.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Text(
                  caption,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    } else if (mediaType == 'video' && mediaUrl != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.videocam, size: 100, color: Colors.white54),
            ),
          ),
          const Icon(Icons.play_circle_outline, size: 80, color: Colors.white),
          if (caption.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Text(
                  caption,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.broken_image, size: 100, color: Colors.white54),
      ),
    );
  }

  void _showStoryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report Story', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Report story
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Share Story', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Share story
              },
            ),
          ],
        ),
      ),
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
}