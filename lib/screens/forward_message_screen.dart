import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/chat_model.dart';
import '../utils/error_handler.dart';

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
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  bool _isForwarding = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_filterChats);
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

      final response = await _supabase
          .from('ngm_chat_participants')
          .select('''
            chat_id,
            ngm_chats!inner(
              chat_id,
              chat_type,
              last_message_at
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('ngm_chats.last_message_at', ascending: false);

      final List<Map<String, dynamic>> chatsList = [];

      for (var item in response) {
        final chatId = item['chat_id'];
        final chatType = item['ngm_chats']['chat_type'];
        
        String chatName = 'Unknown';
        String? chatAvatar;

        if (chatType == 'private') {
          // Get other user info
          final otherUserParticipant = await _supabase
              .from('ngm_chat_participants')
              .select('user_id')
              .eq('chat_id', chatId)
              .neq('user_id', userId)
              .maybeSingle();

          if (otherUserParticipant != null) {
            final otherUser = await _supabase
                .from('ngm_users')
                .select('full_name, username, profile_picture_url')
                .eq('user_id', otherUserParticipant['user_id'])
                .single();

            chatName = otherUser['full_name'] ?? otherUser['username'] ?? 'User';
            chatAvatar = otherUser['profile_picture_url'];
          }
        } else if (chatType == 'group') {
          final group = await _supabase
              .from('ngm_groups')
              .select('group_name, group_picture_url')
              .eq('chat_id', chatId)
              .single();

          chatName = group['group_name'];
          chatAvatar = group['group_picture_url'];
        } else if (chatType == 'channel') {
          final channel = await _supabase
              .from('ngm_channels')
              .select('channel_name, channel_picture_url')
              .eq('chat_id', chatId)
              .single();

          chatName = channel['channel_name'];
          chatAvatar = channel['channel_picture_url'];
        }

        chatsList.add({
          'chat_id': chatId,
          'chat_type': chatType,
          'chat_name': chatName,
          'chat_avatar': chatAvatar,
        });
      }

      if (mounted) {
        setState(() {
          _chats = chatsList;
          _filteredChats = chatsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    }
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChats = _chats.where((chat) {
        final name = (chat['chat_name'] as String).toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _forwardMessages() async {
    if (_selectedChats.isEmpty) return;

    setState(() => _isForwarding = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw AppError('User not authenticated');

      for (final chatId in _selectedChats) {
        for (final message in widget.messages) {
          await _supabase.from('ngm_messages').insert({
            'chat_id': chatId,
            'sender_id': userId,
            'message_type': message.messageType,
            'content': message.content,
            'media_url': message.mediaUrl,
            'is_forwarded': true,
            'forwarded_from_user_id': message.senderId,
            'created_at': DateTime.now().toIso8601String(),
            'is_delivered': true,
            'is_read_by_all': false,
          });

          // Update chat last_message_at
          await _supabase.from('ngm_chats').update({
            'last_message_at': DateTime.now().toIso8601String(),
          }).eq('chat_id', chatId);
        }
      }

      if (mounted) {
        ErrorHandler.showSuccess(
          context,
          'Forwarded to ${_selectedChats.length} chat(s)',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    } finally {
      if (mounted) setState(() => _isForwarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Forward ${widget.messages.length} message(s)'),
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedChats.isNotEmpty)
            IconButton(
              icon: _isForwarding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              onPressed: _isForwarding ? null : _forwardMessages,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          if (_selectedChats.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFF6F00).withOpacity(0.1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedChats.length} chat(s) selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6F00),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedChats.clear()),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChats.isEmpty
                    ? const Center(
                        child: Text('No chats found'),
                      )
                    : ListView.builder(
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          final chatId = chat['chat_id'] as String;
                          final isSelected = _selectedChats.contains(chatId);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: chat['chat_avatar'] != null
                                  ? CachedNetworkImageProvider(
                                      chat['chat_avatar'],
                                    )
                                  : null,
                              backgroundColor: const Color(0xFFFF6F00),
                              child: chat['chat_avatar'] == null
                                  ? Icon(
                                      chat['chat_type'] == 'private'
                                          ? Icons.person
                                          : chat['chat_type'] == 'group'
                                              ? Icons.group
                                              : Icons.campaign,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            title: Text(chat['chat_name'] ?? 'Unknown'),
                            subtitle: Text(
                              chat['chat_type'] == 'private'
                                  ? 'Private chat'
                                  : chat['chat_type'] == 'group'
                                      ? 'Group'
                                      : 'Channel',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedChats.add(chatId);
                                  } else {
                                    _selectedChats.remove(chatId);
                                  }
                                });
                              },
                              activeColor: const Color(0xFFFF6F00),
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedChats.remove(chatId);
                                } else {
                                  _selectedChats.add(chatId);
                                }
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}