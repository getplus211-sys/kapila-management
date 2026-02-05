import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_model.dart';
import '../widgets/message_bubble.dart';
import 'dart:async';
import 'dart:io';
import 'user_profile_screen.dart';
import 'schedule_message_screen.dart';
import 'forward_message_screen.dart';

class ChatWindowScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String otherUserId; // For private chats
  final ChatType chatType;

  const ChatWindowScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatType,
    this.otherUserId = '',
  });

  @override
  State<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends State<ChatWindowScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final List<Message> _messages = [];
  final _imagePicker = ImagePicker();
  final Set<String> _selectedMessages = {};

  bool _isLoading = true;
  bool _isTyping = false;
  bool _isSending = false;
  bool _isSearching = false;
  bool _showEmojiPicker = false;
  bool _isUserOnline = false;
  bool _isSelectionMode = false;
  DateTime? _userLastSeen;
  Message? _replyToMessage;
  Message? _editingMessage;
  Timer? _typingTimer;
  Timer? _onlineStatusTimer;
  String _searchQuery = '';
  RealtimeChannel? _messageSubscription;
  int _scheduledMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeSubscription();
    _markMessagesAsRead();
    _loadScheduledMessagesCount();
    if (widget.chatType == ChatType.private && widget.otherUserId.isNotEmpty) {
      _startOnlineStatusCheck();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _typingTimer?.cancel();
    _onlineStatusTimer?.cancel();
    _messageSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadScheduledMessagesCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('ngm_scheduled_messages')
          .select('message_id')
          .eq('chat_id', widget.chatId)
          .eq('sender_id', userId)
          .eq('is_sent', false);

      if (mounted) {
        setState(() {
          _scheduledMessagesCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading scheduled messages count: $e');
    }
  }

  // Online Status Check
  void _startOnlineStatusCheck() {
    _checkOnlineStatus();
    _onlineStatusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkOnlineStatus();
    });
  }

  Future<void> _checkOnlineStatus() async {
    try {
      final userData = await _supabase
          .from('ngm_users')
          .select('is_online, last_seen')
          .eq('user_id', widget.otherUserId)
          .single();

      setState(() {
        _isUserOnline = userData['is_online'] ?? false;
        _userLastSeen = userData['last_seen'] != null
            ? DateTime.parse(userData['last_seen'])
            : null;
      });
    } catch (e) {
      debugPrint('Error checking online status: $e');
    }
  }

  String _getOnlineStatus() {
    if (_isUserOnline) return 'online';
    if (_userLastSeen != null) {
      final diff = DateTime.now().difference(_userLastSeen!);
      if (diff.inMinutes < 1) return 'last seen just now';
      if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
      if (diff.inDays < 7) return 'last seen ${diff.inDays}d ago';
      return 'last seen recently';
    }
    return 'offline';
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _supabase
          .from('ngm_messages')
          .select()
          .eq('chat_id', widget.chatId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);

      final List<Message> messages = [];
      for (var item in response as List) {
        final senderInfo = await _supabase
            .from('ngm_users')
            .select('full_name, username, profile_picture_url')
            .eq('user_id', item['sender_id'])
            .maybeSingle();

        messages.add(Message(
          messageId: item['message_id'],
          chatId: item['chat_id'],
          senderId: item['sender_id'],
          senderName:
              senderInfo?['full_name'] ?? senderInfo?['username'] ?? 'Unknown',
          senderAvatar: senderInfo?['profile_picture_url'],
          messageType: item['message_type'],
          content: item['content'],
          mediaUrl: item['media_url'],
          replyToMessageId: item['reply_to_message_id'],
          isForwarded: item['is_forwarded'] ?? false,
          isEdited: item['is_edited'] ?? false,
          isDeleted: item['is_deleted'] ?? false,
          createdAt: DateTime.parse(item['created_at']),
          editedAt: item['edited_at'] != null
              ? DateTime.parse(item['edited_at'])
              : null,
          isDelivered: item['is_delivered'] ?? false,
          isRead: item['is_read_by_all'] ?? false,
        ));
      }

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    _messageSubscription = _supabase
        .channel('messages_${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ngm_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.insert) {
              await _handleNewMessage(payload.newRecord);
            } else if (payload.eventType == PostgresChangeEvent.update) {
              _handleMessageUpdate(payload.newRecord);
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              _handleMessageDelete(payload.oldRecord['message_id']);
            }
          },
        )
        .subscribe();
  }

  Future<void> _handleNewMessage(Map<String, dynamic> record) async {
    try {
      final senderInfo = await _supabase
          .from('ngm_users')
          .select('full_name, username, profile_picture_url')
          .eq('user_id', record['sender_id'])
          .maybeSingle();

      final newMessage = Message(
        messageId: record['message_id'],
        chatId: record['chat_id'],
        senderId: record['sender_id'],
        senderName:
            senderInfo?['full_name'] ?? senderInfo?['username'] ?? 'Unknown',
        senderAvatar: senderInfo?['profile_picture_url'],
        messageType: record['message_type'],
        content: record['content'],
        mediaUrl: record['media_url'],
        replyToMessageId: record['reply_to_message_id'],
        isForwarded: record['is_forwarded'] ?? false,
        isEdited: record['is_edited'] ?? false,
        isDeleted: record['is_deleted'] ?? false,
        createdAt: DateTime.parse(record['created_at']),
        isDelivered: record['is_delivered'] ?? false,
        isRead: record['is_read_by_all'] ?? false,
      );

      if (mounted) {
        setState(() => _messages.add(newMessage));
        _scrollToBottom();
        _markMessagesAsRead();
      }
    } catch (e) {
      debugPrint('Error handling new message: $e');
    }
  }

  void _handleMessageUpdate(Map<String, dynamic> record) {
    if (mounted) {
      setState(() {
        final index =
            _messages.indexWhere((m) => m.messageId == record['message_id']);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            content: record['content'],
            isEdited: record['is_edited'] ?? false,
            editedAt: record['edited_at'] != null
                ? DateTime.parse(record['edited_at'])
                : null,
            isDeleted: record['is_deleted'] ?? false,
          );
        }
      });
    }
  }

  void _handleMessageDelete(String messageId) {
    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.messageId == messageId);
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('ngm_chat_participants')
          .update({
            'unread_count': 0,
            'last_read_message_id':
                _messages.isNotEmpty ? _messages.last.messageId : null,
          })
          .eq('chat_id', widget.chatId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
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

  Future<void> _sendMessage({String? mediaUrl, String? mediaType}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Check if editing
      if (_editingMessage != null) {
        await _updateMessage(text);
        return;
      }

      final messageData = {
        'chat_id': widget.chatId,
        'sender_id': userId,
        'message_type': mediaUrl != null ? (mediaType ?? 'image') : 'text',
        'content': text.isEmpty ? null : text,
        'reply_to_message_id': _replyToMessage?.messageId,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Only add media_url if it's not null
      if (mediaUrl != null) {
        messageData['media_url'] = mediaUrl;
      }

      await _supabase.from('ngm_messages').insert(messageData);

      await _supabase
          .from('ngm_chats')
          .update({'last_message_at': DateTime.now().toIso8601String()}).eq(
              'chat_id', widget.chatId);

      _messageController.clear();
      setState(() {
        _replyToMessage = null;
        _isSending = false;
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<void> _updateMessage(String newContent) async {
    try {
      await _supabase.from('ngm_messages').update({
        'content': newContent,
        'is_edited': true,
        'edited_at': DateTime.now().toIso8601String(),
      }).eq('message_id', _editingMessage!.messageId);

      _messageController.clear();
      setState(() {
        _editingMessage = null;
        _isSending = false;
      });
    } catch (e) {
      debugPrint('Error updating message: $e');
      setState(() => _isSending = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAttachmentOption(
              icon: Icons.photo_library,
              title: 'Gallery',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            _buildAttachmentOption(
              icon: Icons.camera_alt,
              title: 'Camera',
              color: Colors.pink,
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            _buildAttachmentOption(
              icon: Icons.videocam,
              title: 'Video',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            _buildAttachmentOption(
              icon: Icons.insert_drive_file,
              title: 'Document',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _uploadAndSendMedia(File(image.path), 'image');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo =
          await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        await _uploadAndSendMedia(File(photo.path), 'image');
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video =
          await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        await _uploadAndSendMedia(File(video.path), 'video');
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        await _uploadAndSendMedia(File(result.files.single.path!), 'document');
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _uploadAndSendMedia(File file, String type) async {
    try {
      setState(() => _isSending = true);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = 'chat-media/$userId/$fileName';

      await _supabase.storage.from('nandigram-storage').upload(filePath, file);

      final mediaUrl =
          _supabase.storage.from('nandigram-storage').getPublicUrl(filePath);

      await _sendMessage(mediaUrl: mediaUrl, mediaType: type);
    } catch (e) {
      debugPrint('Error uploading media: $e');
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    }
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _onTyping() {
    if (!_isTyping) {
      setState(() => _isTyping = true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      setState(() => _isTyping = false);
    });
  }

  void _onEmojiSelected(Emoji emoji) {
    _messageController.text += emoji.emoji;
    _onTyping();
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${widget.chatName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) return;

        await _supabase.from('ngm_blocked_users').insert({
          'user_id': userId,
          'blocked_user_id': widget.otherUserId,
          'reason': 'User blocked from chat',
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User blocked successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error blocking user: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error blocking user: $e')),
          );
        }
      }
    }
  }

  Future<void> _reportUser() async {
    final reasons = [
      'Spam',
      'Harassment',
      'Inappropriate content',
      'Fake account',
      'Other',
    ];

    String? selectedReason;
    final TextEditingController detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a reason:'),
                ...reasons.map((reason) => RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (value) =>
                          setDialogState(() => selectedReason = value),
                    )),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedReason != null) {
      try {
        final userId = _supabase.auth.currentUser?.id;
        await _supabase.from('ngm_user_reports').insert({
          'reporter_user_id': userId,
          'reported_user_id': widget.otherUserId,
          'report_reason': selectedReason,
          'report_details': detailsController.text,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'User reported. Thank you for helping keep Nandigram safe.')),
          );
        }
      } catch (e) {
        debugPrint('Error reporting user: $e');
      }
    }
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
        if (_selectedMessages.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessages.add(messageId);
      }
    });
  }

  void _startSelectionMode(String messageId) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessages.add(messageId);
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessages.clear();
    });
  }

  void _deleteSelectedMessages() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages'),
        content: Text('Delete ${_selectedMessages.length} message(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        for (final messageId in _selectedMessages) {
          await _supabase
              .from('ngm_messages')
              .delete()
              .eq('message_id', messageId);
        }

        setState(() {
          _messages.removeWhere((m) => _selectedMessages.contains(m.messageId));
          _selectedMessages.clear();
          _isSelectionMode = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Messages deleted')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting messages: $e');
      }
    }
  }

  void _forwardSelectedMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForwardMessageScreen(
          messages: _messages
              .where((m) => _selectedMessages.contains(m.messageId))
              .toList(),
        ),
      ),
    ).then((_) {
      _cancelSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6F00)))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];

                          if (_searchQuery.isNotEmpty) {
                            if (message.content == null ||
                                !message.content!
                                    .toLowerCase()
                                    .contains(_searchQuery.toLowerCase())) {
                              return const SizedBox.shrink();
                            }
                          }

                          final isMe = message.senderId ==
                              _supabase.auth.currentUser?.id;
                          final showAvatar =
                              widget.chatType != ChatType.private &&
                                  (index == _messages.length - 1 ||
                                      _messages[index + 1].senderId !=
                                          message.senderId);

                          return MessageBubble(
                            message: message,
                            isMe: isMe,
                            showAvatar: showAvatar,
                            isSelected:
                                _selectedMessages.contains(message.messageId),
                            isSelectionMode: _isSelectionMode,
                            onLongPress: () =>
                                _startSelectionMode(message.messageId),
                            onTap: _isSelectionMode
                                ? () =>
                                    _toggleMessageSelection(message.messageId)
                                : null,
                            onReply: () =>
                                setState(() => _replyToMessage = message),
                            onEdit: () {
                              setState(() {
                                _editingMessage = message;
                                _messageController.text = message.content ?? '';
                              });
                            },
                            onDelete: () => _showDeleteOptions(message),
                            onForward: () => _forwardMessage(message),
                            onReact: (emoji) => _reactToMessage(message, emoji),
                            onJumpToReply: (replyId) => _jumpToMessage(replyId),
                          );
                        },
                      ),
          ),
          if (_replyToMessage != null) _buildReplyPreview(),
          if (_editingMessage != null) _buildEditPreview(),
          _buildMessageInput(),
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) => _onEmojiSelected(emoji),
                config: const Config(
                  checkPlatformCompatibility: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFFF6F00),
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            )
          : InkWell(
              onTap: () {
                if (widget.chatType == ChatType.private &&
                    widget.otherUserId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UserProfileScreen(userId: widget.otherUserId),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.chatName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFFF6F00),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chatName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.chatType == ChatType.private)
                          Text(
                            _getOnlineStatus(),
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelSearch,
          )
        else
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _startSearch,
          ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showChatOptions,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFFF6F00),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _cancelSelection,
      ),
      title: Text('${_selectedMessages.length} selected'),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: _deleteSelectedMessages,
        ),
        IconButton(
          icon: const Icon(Icons.forward),
          onPressed: _forwardSelectedMessages,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No messages yet',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Send your first message',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 40, color: const Color(0xFFFF6F00)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyToMessage!.senderName ?? 'Unknown',
                  style: const TextStyle(
                      color: Color(0xFFFF6F00),
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage!.content ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _replyToMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.blue[200]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Edit message',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.blue),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
              color: const Color(0xFFFF6F00),
            ),
            onPressed: _toggleEmojiPicker,
          ),
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => _onTyping(),
                onTap: () {
                  if (_showEmojiPicker) {
                    setState(() => _showEmojiPicker = false);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (_scheduledMessagesCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.schedule, color: Color(0xFFFF6F00)),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScheduleMessageScreen(
                          chatId: widget.chatId,
                          chatName: widget.chatName,
                        ),
                      ),
                    );
                    _loadScheduledMessagesCount();
                  },
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_scheduledMessagesCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isSending ? null : () => _sendMessage(),
            onLongPress: _isSending
                ? null
                : () async {
                    if (_messageController.text.trim().isNotEmpty) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScheduleMessageScreen(
                            chatId: widget.chatId,
                            chatName: widget.chatName,
                            initialMessage: _messageController.text.trim(),
                          ),
                        ),
                      );
                      _messageController.clear();
                      _loadScheduledMessagesCount();
                    }
                  },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey : const Color(0xFFFF6F00),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _editingMessage != null ? Icons.check : Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[300],
              child: Text(
                widget.chatName[0].toUpperCase(),
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.chatName,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.chatType == ChatType.private)
              Text(_getOnlineStatus(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Mute'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search'),
              onTap: () {
                Navigator.pop(context);
                _startSearch();
              },
            ),
            if (widget.chatType == ChatType.private) ...[
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block User',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser();
                },
              ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: const Text('Report User',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _reportUser();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: Text('${widget.chatName} Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showChatInfo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search in Chat'),
                onTap: () {
                  Navigator.pop(context);
                  _startSearch();
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off),
                title: const Text('Mute'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.wallpaper),
                title: const Text('Change Wallpaper'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Clear History',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context),
              ),
              if (widget.chatType == ChatType.private) ...[
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Block User',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _blockUser();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.red),
                  title: const Text('Report User',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _reportUser();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteOptions(Message message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete for Me'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message, forEveryone: false);
              },
            ),
            if (message.senderId == _supabase.auth.currentUser?.id)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete for Everyone',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message, forEveryone: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(Message message,
      {required bool forEveryone}) async {
    try {
      if (forEveryone) {
        // Delete for everyone - remove from database
        await _supabase
            .from('ngm_messages')
            .delete()
            .eq('message_id', message.messageId);
      } else {
        // Delete only for current user (local UI only)
        setState(() {
          _messages.removeWhere((m) => m.messageId == message.messageId);
        });
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  void _forwardMessage(Message message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForwardMessageScreen(messages: [message]),
      ),
    );
  }

  Future<void> _reactToMessage(Message message, String emoji) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Check if already reacted with this emoji
      final existingReaction = await _supabase
          .from('ngm_message_reactions')
          .select()
          .eq('message_id', message.messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existingReaction != null) {
        // Remove reaction
        await _supabase
            .from('ngm_message_reactions')
            .delete()
            .eq('reaction_id', existingReaction['reaction_id']);
      } else {
        // Add reaction
        await _supabase.from('ngm_message_reactions').insert({
          'message_id': message.messageId,
          'user_id': userId,
          'emoji': emoji,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error reacting to message: $e');
    }
  }

  void _jumpToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.messageId == messageId);
    if (index != -1) {
      _scrollController.animateTo(
        index * 80.0, // Approximate message height
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
}
