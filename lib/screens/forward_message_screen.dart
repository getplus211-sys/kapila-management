import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';

class ForwardMessageScreen extends StatefulWidget {
  final List<Message> messages;

  const ForwardMessageScreen({super.key, required this.messages});

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final _supabase = Supabase.instance.client;
  final Set<String> _selectedChats = {};
  final _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allChats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  bool _isForwarding = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all chats where user is a participant
      final response = await _supabase
          .from('ngm_chat_participants')
          .select('chat_id')
          .eq('user_id', userId);

      final chatIds = (response as List).map((e) => e['chat_id'] as String).toList();

      if (chatIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _allChats = [];
          _filteredChats = [];
        });
        return;
      }

      // Get chat details - FIXED: changed .in_() to .inFilter()
      final chatsResponse = await _supabase
          .from('ngm_chats')
          .select()
          .inFilter('chat_id', chatIds)
          .order('last_message_at', ascending: false);

      final List<Map<String, dynamic>> chats = [];

      for (var chat in chatsResponse as List) {
        String chatName = '';
        String? avatarUrl;

        if (chat['chat_type'] == 'private') {
          // Get other user's info
          final participants = await _supabase
              .from('ngm_chat_participants')
              .select('user_id')
              .eq('chat_id', chat['chat_id'])
              .neq('user_id', userId);

          if (participants.isNotEmpty) {
            final otherUserId = participants[0]['user_id'];
            final userInfo = await _supabase
                .from('ngm_users')
                .select('full_name, username, profile_picture_url')
                .eq('user_id', otherUserId)
                .maybeSingle();

            if (userInfo != null) {
              chatName = userInfo['full_name'] ?? userInfo['username'] ?? 'Unknown';
              avatarUrl = userInfo['profile_picture_url'];
            }
          }
        } else {
          chatName = chat['name'] ?? 'Unnamed Chat';
          avatarUrl = chat['avatar_url'];
        }

        chats.add({
          'chat_id': chat['chat_id'],
          'name': chatName,
          'avatar_url': avatarUrl,
          'chat_type': chat['chat_type'],
        });
      }

      if (mounted) {
        setState(() {
          _allChats = chats;
          _filteredChats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading chats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterChats(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _allChats;
      } else {
        _filteredChats = _allChats
            .where((chat) => chat['name']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChats.contains(chatId)) {
        _selectedChats.remove(chatId);
      } else {
        _selectedChats.add(chatId);
      }
    });
  }

  Future<void> _forwardMessages() async {
    if (_selectedChats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one chat')),
      );
      return;
    }

    setState(() => _isForwarding = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      for (final chatId in _selectedChats) {
        for (final message in widget.messages) {
          final messageData = {
            'chat_id': chatId,
            'sender_id': userId,
            'message_type': message.messageType,
            'content': message.content,
            'is_forwarded': true,
            'created_at': DateTime.now().toIso8601String(),
          };

          // Add media_url if present
          if (message.mediaUrl != null) {
            messageData['media_url'] = message.mediaUrl;
          }

          await _supabase.from('ngm_messages').insert(messageData);

          // Update chat's last message time
          await _supabase
              .from('ngm_chats')
              .update({'last_message_at': DateTime.now().toIso8601String()})
              .eq('chat_id', chatId);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message${widget.messages.length > 1 ? 's' : ''} forwarded to ${_selectedChats.length} chat${_selectedChats.length > 1 ? 's' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error forwarding messages: $e');
      setState(() => _isForwarding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error forwarding messages: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
        title: const Text('Forward To'),
        actions: [
          if (_selectedChats.isNotEmpty)
            TextButton(
              onPressed: _isForwarding ? null : _forwardMessages,
              child: _isForwarding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Send (${_selectedChats.length})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6F00)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: _filterChats,
            ),
          ),

          // Selected messages preview
          if (widget.messages.length <= 3)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.forward, size: 18, color: Color(0xFFFF6F00)),
                      const SizedBox(width: 8),
                      Text(
                        'Forwarding ${widget.messages.length} message${widget.messages.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6F00),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...widget.messages.map((message) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.content ?? '[Media]',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forward, size: 18, color: Color(0xFFFF6F00)),
                  const SizedBox(width: 8),
                  Text(
                    'Forwarding ${widget.messages.length} messages',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6F00),
                    ),
                  ),
                ],
              ),
            ),

          // Chats list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6F00)),
                  )
                : _filteredChats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No chats available'
                                  : 'No chats found',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          final isSelected = _selectedChats.contains(chat['chat_id']);

                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFFF6F00),
                                  backgroundImage: chat['avatar_url'] != null
                                      ? NetworkImage(chat['avatar_url'])
                                      : null,
                                  child: chat['avatar_url'] == null
                                      ? Text(
                                          chat['name'][0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white),
                                        )
                                      : null,
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFFFF6F00),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              chat['name'],
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              chat['chat_type'] == 'private' ? 'Private Chat' : 'Group Chat',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Color(0xFFFF6F00))
                                : null,
                            onTap: () => _toggleChatSelection(chat['chat_id']),
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFFF6F00).withOpacity(0.1),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}