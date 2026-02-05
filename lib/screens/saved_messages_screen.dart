import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../widgets/message_bubble.dart';

class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _savedChatId;

  @override
  void initState() {
    super.initState();
    _loadSavedMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedMessages() async {
    try {
      setState(() => _isLoading = true);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get or create saved messages chat
      var savedChat = await _supabase
          .from('ngm_chats')
          .select('chat_id')
          .eq('chat_type', 'private')
          .eq('user1_id', userId)
          .eq('user2_id', userId)
          .maybeSingle();

      if (savedChat == null) {
        // Create saved messages chat
        savedChat = await _supabase.from('ngm_chats').insert({
          'chat_type': 'private',
          'user1_id': userId,
          'user2_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();

        // Add participant
        await _supabase.from('ngm_chat_participants').insert({
          'chat_id': savedChat['chat_id'],
          'user_id': userId,
          'role': 'member',
        });
      }

      _savedChatId = savedChat['chat_id'];

      // Load messages
      final response = await _supabase
          .from('ngm_messages')
          .select()
          .eq('chat_id', _savedChatId!)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);

      final List<Message> messages = [];
      for (var item in response as List) {
        messages.add(Message(
          messageId: item['message_id'],
          chatId: item['chat_id'],
          senderId: item['sender_id'],
          messageType: item['message_type'],
          content: item['content'],
          createdAt: DateTime.parse(item['created_at']),
          isDelivered: true,
          isRead: true,
        ));
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading saved messages: $e');
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _saveMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _savedChatId == null) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('ngm_messages').insert({
        'chat_id': _savedChatId,
        'sender_id': userId,
        'message_type': 'text',
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      });

      _messageController.clear();
      _loadSavedMessages();
    } catch (e) {
      debugPrint('Error saving message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('મેસેજ સેવ કરવામાં ભૂલ થઈ')),
        );
      }
    }
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      await _supabase
          .from('ngm_messages')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('message_id', message.messageId);

      _loadSavedMessages();
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.bookmark),
            SizedBox(width: 10),
            Text('સેવ કરેલા મેસેજ'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'અહીં તમે તમારા માટે મહત્વના નોંધ અને મેસેજ સેવ કરી શકો છો',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return MessageBubble(
                            message: message,
                            isMe: true,
                            showAvatar: false,
                            onReply: () {},
                            onEdit: () {},  // FIXED: Added missing onEdit
                            onDelete: () => _deleteMessage(message),
                            onForward: () {},
                            onReact: (emoji) {},  // FIXED: Added missing onReact
                            onJumpToReply: (replyId) {},  // FIXED: Added missing onJumpToReply
                          );
                        },
                      ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'નોંધ લખો...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.bookmark_add, color: Colors.white, size: 20),
                    onPressed: _saveMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'કોઈ સેવ કરેલ મેસેજ નથી',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'મહત્વના મેસેજ અને નોંધ અહીં સેવ કરો',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}