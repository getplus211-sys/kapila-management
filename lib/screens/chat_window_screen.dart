import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/local_storage_service.dart';
import '../utils/date_util.dart';
import '../utils/media_util.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/divider_widgets.dart';

class ChatWindowScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatWindowScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
  }) : super(key: key);

  @override
  State<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends State<ChatWindowScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  
  List<Message> _messages = [];
  UserModel? _otherUser;
  ChatModel? _currentChat;
  Message? _replyToMessage;
  Message? _pinnedMessage;
  
  bool _showScrollToBottom = false;
  int _unreadCount = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isTyping = false;
  Timer? _typingTimer;
  Timer? _statusRefreshTimer;
  
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _scrollController.addListener(_onScroll);
    _chatService.updateOnlineStatus(true);
    
    // Refresh user status every 30 seconds
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshUserStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _typingTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _chatService.updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatService.updateOnlineStatus(true);
      _refreshUserStatus();
    } else if (state == AppLifecycleState.paused) {
      _chatService.updateOnlineStatus(false);
    }
  }

  Future<void> _initializeChat() async {
    // Load local messages first for instant display
    _loadLocalMessages();
    
    // Fetch other user info
    _otherUser = await _chatService.getUserInfo(widget.otherUserId);
    
    // Fetch chat info
    _currentChat = await _chatService.getChatInfo(widget.chatId);
    
    // Fetch messages from server
    await _fetchMessages();
    
    // Subscribe to real-time updates
    _subscribeToMessages();
    
    // Mark messages as read
    _markMessagesAsRead();
    
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshUserStatus() async {
    final updatedUser = await _chatService.getUserInfo(widget.otherUserId);
    if (mounted && updatedUser != null) {
      setState(() {
        _otherUser = updatedUser;
      });
    }
  }

  void _loadLocalMessages() {
    _messages = LocalStorageService().getMessagesByChat(widget.chatId);
    _findPinnedMessage();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchMessages() async {
    final messages = await _chatService.fetchMessages(widget.chatId);
    if (mounted) {
      setState(() {
        _messages = messages;
        _findPinnedMessage();
      });
    }
  }

// Line ~88 પર _subscribeToMessages method ને replace કરો:

void _subscribeToMessages() {
  print('🔔 Setting up real-time subscription...');
  
  _messageSubscription = _chatService
      .subscribeToMessages(widget.chatId)
      .listen(
        (newMessage) {
          print('🔔 Message received in UI: ${newMessage.content}');
          
          // Check if message already exists
          final exists = _messages.any((m) => m.messageId == newMessage.messageId);
          
          if (!exists && mounted) {
            setState(() {
              _messages.add(newMessage);
              _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              _findPinnedMessage();
            });
            
            // Save to local storage
            LocalStorageService().saveMessage(newMessage);
            
            // Auto-scroll to bottom
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_scrollController.hasClients) {
                _scrollToBottom();
              }
            });
            
            // Mark as read if from other user
            if (newMessage.senderId != _chatService.currentUserId) {
              _chatService.markAsRead(newMessage.messageId);
            }
          }
        },
        onError: (error) {
          print('❌ Real-time error: $error');
        },
      );
}

  void _findPinnedMessage() {
    try {
      _pinnedMessage = _messages.firstWhere((msg) => msg.isPinned);
    } catch (e) {
      _pinnedMessage = null;
    }
  }

  void _markMessagesAsRead() {
    for (final message in _messages) {
      if (message.senderId != _chatService.currentUserId && !message.isReadByAll) {
        _chatService.markAsRead(message.messageId);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final showButton = position.maxScrollExtent - position.pixels > 200;
      
      if (showButton != _showScrollToBottom) {
        setState(() => _showScrollToBottom = showButton);
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  Future<void> _sendMessage(String content, String type, {String? mediaPath}) async {
    String? mediaUrl;
    
    // Upload media if provided
    if (mediaPath != null) {
      // TODO: Implement media upload to storage
      mediaUrl = mediaPath; // For now, use local path
    }
    
    final message = await _chatService.sendMessage(
      chatId: widget.chatId,
      messageType: type,
      content: content.isNotEmpty ? content : null,
      mediaUrl: mediaUrl,
      replyToMessageId: _replyToMessage?.messageId,
    );
    
    if (message != null) {
      setState(() {
        _messages.add(message);
        _replyToMessage = null;
      });
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _scheduleMessage(DateTime scheduledTime, String content) async {
    final success = await _chatService.scheduleMessage(
      chatId: widget.chatId,
      content: content,
      scheduledFor: scheduledTime,
    );
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message scheduled successfully')),
      );
    }
  }

  void _onTypingChanged(bool isTyping) {
    _typingTimer?.cancel();
    
    if (isTyping) {
      _chatService.updateTypingStatus(widget.chatId, true);
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.updateTypingStatus(widget.chatId, false);
      });
    } else {
      _chatService.updateTypingStatus(widget.chatId, false);
    }
  }

  void _showMessageOptions(Message message) {
    final isMe = message.senderId == _chatService.currentUserId;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            _buildOptionTile(
              icon: Icons.reply,
              label: 'Reply',
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyToMessage = message);
              },
            ),
            
            _buildOptionTile(
              icon: Icons.copy,
              label: 'Copy',
              onTap: () {
                Navigator.pop(context);
                if (message.content != null) {
                  Clipboard.setData(ClipboardData(text: message.content!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
            ),
            
            _buildOptionTile(
              icon: Icons.forward,
              label: 'Forward',
              onTap: () {
                Navigator.pop(context);
                _showForwardDialog(message);
              },
            ),
            
            if (isMe)
              _buildOptionTile(
                icon: Icons.edit,
                label: 'Edit',
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(message);
                },
              ),
            
            _buildOptionTile(
              icon: message.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: message.isPinned ? 'Unpin' : 'Pin',
              onTap: () async {
                Navigator.pop(context);
                if (message.isPinned) {
                  await _chatService.unpinMessage(message.messageId);
                } else {
                  await _chatService.pinMessage(message.messageId, widget.chatId);
                }
                _loadLocalMessages();
              },
            ),
            
            if (message.mediaUrl != null)
              _buildOptionTile(
                icon: Icons.download,
                label: 'Save to Gallery',
                onTap: () async {
                  Navigator.pop(context);
                  final success = message.messageType == 'image'
                      ? await MediaUtil.saveImageToGallery(message.mediaUrl!)
                      : await MediaUtil.saveVideoToGallery(message.mediaUrl!);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'Saved to gallery'
                            : 'Failed to save'),
                      ),
                    );
                  }
                },
              ),
            
            _buildOptionTile(
              icon: Icons.delete_outline,
              label: 'Delete for me',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                await _chatService.deleteMessageForMe(message.messageId);
                _loadLocalMessages();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message deleted')),
                  );
                }
              },
            ),
            
            if (isMe)
              _buildOptionTile(
                icon: Icons.delete,
                label: 'Delete for everyone',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(message);
                },
              ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  void _showEditDialog(Message message) {
    final controller = TextEditingController(text: message.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Message',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                await _chatService.editMessage(message.messageId, newContent);
                _loadLocalMessages();
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text(
          'This message will be deleted for everyone in this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _chatService.deleteMessageForEveryone(message.messageId);
              _loadLocalMessages();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showForwardDialog(Message message) {
    // TODO: Implement forward screen with chat list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forward feature - coming soon')),
    );
  }

  void _searchInChat() {
    setState(() => _isSearching = !_isSearching);
    if (!_isSearching) {
      setState(() => _searchQuery = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_pinnedMessage != null) _buildPinnedMessageBar(),
          
          Expanded(
            child: _buildMessagesList(),
          ),
          
          ChatInputWidget(
            onSendMessage: _sendMessage,
            onScheduleMessage: _scheduleMessage,
            replyToMessage: _replyToMessage,
            onCancelReply: () => setState(() => _replyToMessage = null),
            onTypingChanged: _onTypingChanged,
          ),
        ],
      ),
      floatingActionButton: _showScrollToBottom
          ? _buildScrollToBottomButton()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _isSearching = false;
            _searchQuery = '';
          }),
        ),
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search in chat...',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      );
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: InkWell(
        onTap: () {
          // Navigate to user profile
          // TODO: Implement user profile navigation
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: _otherUser?.profilePictureUrl != null
                  ? NetworkImage(_otherUser!.profilePictureUrl!)
                  : null,
              child: _otherUser?.profilePictureUrl == null
                  ? Text(
                      _otherUser?.displayName.substring(0, 1).toUpperCase() ?? '?',
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUser?.displayName ?? 'Loading...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 12,
                      color: _otherUser?.isOnline ?? false 
                          ? Colors.green 
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _searchInChat,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'view_profile':
                // TODO: Navigate to profile
                break;
              case 'mute':
                // TODO: Mute chat
                break;
              case 'wallpaper':
                // TODO: Change wallpaper
                break;
              case 'clear_chat':
                // TODO: Clear chat
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_profile',
              child: Text('View Profile'),
            ),
            const PopupMenuItem(
              value: 'mute',
              child: Text('Mute Notifications'),
            ),
            const PopupMenuItem(
              value: 'wallpaper',
              child: Text('Change Wallpaper'),
            ),
            const PopupMenuItem(
              value: 'clear_chat',
              child: Text('Clear Chat'),
            ),
          ],
        ),
      ],
    );
  }

  String _getStatusText() {
    if (_otherUser == null) return '';
    
    if (_isTyping) return 'typing...';
    
    if (_otherUser!.isOnline) {
      return 'online';
    } else if (_otherUser!.lastSeen != null) {
      return 'last seen ${DateUtil.formatLastSeen(_otherUser!.lastSeen!)}';
    }
    
    return 'offline';
  }

  Widget _buildPinnedMessageBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.push_pin,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pinned Message',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  _pinnedMessage?.content ?? 'Media',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () async {
              await _chatService.unpinMessage(_pinnedMessage!.messageId);
              _loadLocalMessages();
            },
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final filteredMessages = _searchQuery.isEmpty
        ? _messages
        : _messages.where((msg) {
            return msg.content?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
          }).toList();

    if (filteredMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No messages yet\nSay hi! 👋'
                  : 'No messages found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredMessages.length,
      itemBuilder: (context, index) {
        final message = filteredMessages[index];
        final previousMessage = index > 0 ? filteredMessages[index - 1] : null;
        final isMe = message.senderId == _chatService.currentUserId;
        
        // Show date divider
        final showDateDivider = DateUtil.shouldShowDateDivider(
          previousMessage?.createdAt,
          message.createdAt,
        );

        // Show unread divider
        final showUnreadDivider = index == filteredMessages.length - _unreadCount &&
            _unreadCount > 0;

        // Show avatar for first message in group
        final showAvatar = previousMessage == null ||
            previousMessage.senderId != message.senderId ||
            DateUtil.shouldShowDateDivider(
              previousMessage.createdAt,
              message.createdAt,
            );

        final replyToMsg = message.replyToMessageId != null
            ? _messages.firstWhere(
                (m) => m.messageId == message.replyToMessageId,
                orElse: () => message,
              )
            : null;

        return Column(
          children: [
            if (showDateDivider)
              DateDivider(
                dateText: DateUtil.getDateDivider(message.createdAt),
              ),
            
            if (showUnreadDivider)
              UnreadDivider(unreadCount: _unreadCount),
            
            MessageBubble(
              message: message,
              sender: _otherUser,
              isMe: isMe,
              showAvatar: showAvatar,
              onLongPress: () => _showMessageOptions(message),
              replyToMessage: replyToMsg,
            ),
          ],
        );
      },
    );
  }

  Widget _buildScrollToBottomButton() {
    return FloatingActionButton.small(
      onPressed: _scrollToBottom,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.arrow_downward),
          if (_unreadCount > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onError,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}