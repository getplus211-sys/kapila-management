import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_item.dart';
import '../models/message_model.dart';
import '../services/local_storage_service.dart';

const _kBg      = Color(0xFF0B0E1A);
const _kSurface = Color(0xFF141828);
const _kSurf2   = Color(0xFF1C2035);
const _kBrand   = Color(0xFF7B4FD6);
const _kAccent  = Color(0xFF9B6FF0);
const _kText1   = Color(0xFFEEEEF5);
const _kText2   = Color(0xFF8890AA);
const _kBorder  = Color(0xFF252A40);

class ForwardMessageScreen extends StatefulWidget {
  final Message message;

  const ForwardMessageScreen({super.key, required this.message});

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final _supabase = Supabase.instance.client;
  final _storage = LocalStorageService();
  final _searchController = TextEditingController();

  List<ChatItem> _chats = [];
  List<ChatItem> _filteredChats = [];
  List<String> _selectedChatIds = [];
  bool _isLoading = true;
  String _searchQuery = '';

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
      final cached = _storage.getCachedChatList();
      if (cached != null) {
        setState(() {
          _chats = cached
              .where((c) => c['chatId'] != 'saved_messages')
              .map((c) => ChatItem(
                    chatId: c['chatId'],
                    chatType: ChatType.values.firstWhere((e) => e.toString() == c['chatType']),
                    name: c['name'],
                    avatarUrl: c['avatarUrl'],
                    lastMessage: c['lastMessage'] ?? '',
                    lastMessageTime: DateTime.parse(c['lastMessageTime']),
                    unreadCount: 0,
                    isPinned: false,
                    isMuted: false,
                  ))
              .toList();
          _filteredChats = _chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading chats: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterChats(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats
            .where((chat) => chat.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _toggleSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        if (_selectedChatIds.length < 5) {
          _selectedChatIds.add(chatId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 chats')),
          );
        }
      }
    });
  }

  Future<void> _forwardMessage() async {
    if (_selectedChatIds.isEmpty) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      Navigator.pop(context);

      for (final chatId in _selectedChatIds) {
        await _supabase.from('ngm_messages').insert({
          'chat_id': chatId,
          'sender_id': userId,
          'message_type': widget.message.messageType,
          'content': widget.message.content,
          'media_url': widget.message.mediaUrl,
          'is_forwarded': true,
          'forwarded_from_user_id': widget.message.senderId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Forwarded to ${_selectedChatIds.length} chat(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error forwarding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: _kText1,
        title: Text(_selectedChatIds.isEmpty
            ? 'Forward to...'
            : '${_selectedChatIds.length} selected'),
        actions: [
          if (_selectedChatIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _forwardMessage,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterChats,
              style: const TextStyle(color: _kText1),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: const TextStyle(color: _kText2),
                prefixIcon: const Icon(Icons.search, color: _kText2),
                filled: true,
                fillColor: _kSurf2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSurf2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Icon(_getMessageIcon(), color: _kBrand, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message.content ?? 'Media',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kText1, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kBrand))
                : _filteredChats.isEmpty
                    ? const Center(
                        child: Text('No chats found', style: TextStyle(color: _kText2)))
                    : ListView.builder(
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          final isSelected = _selectedChatIds.contains(chat.chatId);
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _kBrand,
                                  backgroundImage: chat.avatarUrl != null
                                      ? NetworkImage(chat.avatarUrl!)
                                      : null,
                                  child: chat.avatarUrl == null
                                      ? Text(chat.name[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white))
                                      : null,
                                ),
                                if (isSelected)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _kBrand.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check,
                                          color: Colors.white, size: 20),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(chat.name,
                                style: const TextStyle(
                                    color: _kText1, fontWeight: FontWeight.w600)),
                            subtitle: Text(chat.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _kText2, fontSize: 12)),
                            onTap: () => _toggleSelection(chat.chatId),
                            tileColor: isSelected ? _kBrand.withOpacity(0.1) : null,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getMessageIcon() {
    switch (widget.message.messageType) {
      case 'image': return Icons.image;
      case 'video': return Icons.videocam;
      case 'file': return Icons.insert_drive_file;
      default: return Icons.text_fields;
    }
  }
}