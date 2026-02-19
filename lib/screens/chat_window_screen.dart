import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/local_storage_service.dart';
import '../utils/date_util.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/divider_widgets.dart';
import 'theme_provider.dart';
import 'view_profile_screen.dart';

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

class _ChatWindowScreenState extends State<ChatWindowScreen>
    with WidgetsBindingObserver {

  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();

  final Map<String, Message> _messageMap = {};
  List<String> _messageIds = [];

  UserModel? _otherUser;
  ChatModel? _currentChat;
  Message? _replyToMessage;
  Message? _pinnedMessage;

  bool _showScrollToBottom = false;
  bool _isSearching = false;
  bool _isOtherUserTyping = false;
  String _searchQuery = '';
  int _searchResultCount = 0;
  int _currentSearchIndex = 0;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _presenceSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _typingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _scrollController.addListener(_onScroll);
    _chatService.updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _presenceSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingSubscription?.cancel();
    _chatService.stopTyping(widget.chatId);
    _chatService.updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatService.updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused) {
      _chatService.updateOnlineStatus(false);
      _chatService.stopTyping(widget.chatId);
    }
  }

  bool _isActuallyOnline(UserModel? user) {
    if (user == null) return false;
    if (!user.isOnline) return false;
    if (user.lastSeen == null) return false;
    return DateTime.now().difference(user.lastSeen!).inMinutes < 3;
  }

  Future<void> _initializeChat() async {
    _loadLocalMessages();
    _otherUser = await _chatService.getUserInfo(widget.otherUserId);
    if (mounted) setState(() {});
    _currentChat = await _chatService.getChatInfo(widget.chatId);
    await _fetchMessages();
    _subscribeToMessages();
    _subscribeToPresence();
    _subscribeToMessageStatus();
    _subscribeToTyping();
    await _markMessagesAsRead();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scrollController.hasClients) _scrollToBottom(animated: false);
        });
      }
    });
  }

  void _loadLocalMessages() {
    final messages = LocalStorageService().getMessagesByChat(widget.chatId);
    for (final msg in messages) { _messageMap[msg.messageId] = msg; }
    _messageIds = _messageMap.keys.toList()
      ..sort((a, b) => _messageMap[a]!.createdAt.compareTo(_messageMap[b]!.createdAt));
    _findPinnedMessage();
    if (mounted) setState(() {});
  }

  Future<void> _fetchMessages() async {
    final messages = await _chatService.fetchMessages(widget.chatId);
    for (final msg in messages) { _messageMap[msg.messageId] = msg; }
    _messageIds = _messageMap.keys.toList()
      ..sort((a, b) => _messageMap[a]!.createdAt.compareTo(_messageMap[b]!.createdAt));
    _findPinnedMessage();
    if (mounted) setState(() {});
  }

  void _subscribeToMessages() {
    _messageSubscription = _chatService.subscribeToMessages(widget.chatId).listen((newMessage) {
      final exists = _messageMap.containsKey(newMessage.messageId);
      if (!exists) {
        _messageMap[newMessage.messageId] = newMessage;
        _messageIds.add(newMessage.messageId);
        _messageIds.sort((a, b) => _messageMap[a]!.createdAt.compareTo(_messageMap[b]!.createdAt));
        LocalStorageService().saveMessage(newMessage);
        if (mounted) {
          setState(() {});
          if (_scrollController.hasClients) {
            final pos = _scrollController.position;
            if (pos.maxScrollExtent - pos.pixels < 100) {
              Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
            }
          }
        }
        if (newMessage.senderId != _chatService.currentUserId) {
          _chatService.markAsRead(newMessage.messageId);
        }
      } else {
        _messageMap[newMessage.messageId] = newMessage;
        if (mounted) setState(() {});
      }
      _findPinnedMessage();
    });
  }

  void _subscribeToPresence() {
    _presenceSubscription = _chatService.subscribeToUserPresence(widget.otherUserId).listen((updatedUser) {
      if (mounted) setState(() { _otherUser = updatedUser; });
    });
  }

  void _subscribeToMessageStatus() {
    _statusSubscription = _chatService.subscribeToMessageStatus(widget.chatId).listen((statusUpdate) {
      final message = _messageMap[statusUpdate['message_id']!];
      if (message != null) {
        _messageMap[statusUpdate['message_id']!] = message.copyWith(
          isReadByAll: statusUpdate['status'] == 'read',
          isDelivered: true,
        );
        if (mounted) setState(() {});
      }
    });
  }

  void _subscribeToTyping() {
    _typingSubscription = _chatService.subscribeToTyping(widget.chatId, widget.otherUserId).listen((isTyping) {
      if (mounted) setState(() => _isOtherUserTyping = isTyping);
    });
  }

  void _findPinnedMessage() {
    try {
      _pinnedMessage = _messageMap.values.firstWhere((msg) => msg.isPinned);
    } catch (e) { _pinnedMessage = null; }
  }

  Future<void> _markMessagesAsRead() async {
    for (final messageId in _messageIds) {
      final message = _messageMap[messageId]!;
      if (message.senderId != _chatService.currentUserId && !message.isReadByAll) {
        await _chatService.markAsRead(message.messageId);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final showButton = _scrollController.position.maxScrollExtent - _scrollController.position.pixels > 200;
      if (showButton != _showScrollToBottom) setState(() => _showScrollToBottom = showButton);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (animated) {
      _scrollController.animateTo(pos.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(pos.maxScrollExtent);
    }
  }

  Future<void> _sendMessage(String content, String type, {String? mediaPath}) async {
    await _chatService.sendMessage(
      chatId: widget.chatId, messageType: type,
      content: content.isNotEmpty ? content : null,
      mediaUrl: mediaPath,
      replyToMessageId: _replyToMessage?.messageId,
    );
    setState(() { _replyToMessage = null; });
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _searchInChat() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) { _searchQuery = ''; _searchResultCount = 0; _currentSearchIndex = 0; }
    });
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResultCount = 0; _currentSearchIndex = 0;
      } else {
        _searchResultCount = _messageIds.where((id) {
          return _messageMap[id]!.content?.toLowerCase().contains(query.toLowerCase()) ?? false;
        }).length;
        _currentSearchIndex = _searchResultCount > 0 ? 1 : 0;
      }
    });
  }

  void _openUserProfile() {
    if (_otherUser == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ViewProfileScreen(userId: _otherUser!.userId),
    ));
  }

  void _showMessageOptions(Message message, ThemeProvider t) {
    final isMe = message.senderId == _chatService.currentUserId;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        _buildOptionTile(icon: Icons.reply, label: 'Reply', t: t, onTap: () {
          Navigator.pop(context); setState(() => _replyToMessage = message);
        }),
        _buildOptionTile(icon: Icons.copy, label: 'Copy', t: t, onTap: () {
          Navigator.pop(context);
          if (message.content != null) {
            Clipboard.setData(ClipboardData(text: message.content!));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
          }
        }),
        _buildOptionTile(icon: Icons.forward, label: 'Forward', t: t, onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forward - coming soon')));
        }),
        if (isMe) _buildOptionTile(icon: Icons.edit, label: 'Edit', t: t, onTap: () {
          Navigator.pop(context); _showEditDialog(message, t);
        }),
        _buildOptionTile(
          icon: message.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
          label: message.isPinned ? 'Unpin' : 'Pin', t: t,
          onTap: () async {
            Navigator.pop(context);
            if (message.isPinned) { await _chatService.unpinMessage(message.messageId); }
            else { await _chatService.pinMessage(message.messageId, widget.chatId); }
            await _fetchMessages();
          },
        ),
        _buildOptionTile(icon: Icons.delete_outline, label: 'Delete for me', t: t, color: Colors.red, onTap: () async {
          Navigator.pop(context);
          await _chatService.deleteMessageForMe(message.messageId);
          setState(() { _messageMap.remove(message.messageId); _messageIds.remove(message.messageId); });
        }),
        if (isMe) _buildOptionTile(icon: Icons.delete, label: 'Delete for everyone', t: t, color: Colors.red, onTap: () {
          Navigator.pop(context); _showDeleteConfirmation(message, t);
        }),
        const SizedBox(height: 20),
      ]))),
    );
  }

  Widget _buildOptionTile({required IconData icon, required String label,
      required ThemeProvider t, required VoidCallback onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? t.text1),
      title: Text(label, style: TextStyle(color: color ?? t.text1)),
      onTap: onTap,
    );
  }

  void _showEditDialog(Message message, ThemeProvider t) {
    final ctrl = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Edit Message', style: TextStyle(color: t.text1)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: t.text1),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Message',
            labelStyle: TextStyle(color: t.text2),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: t.border)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: t.brand)),
          ),
          maxLines: 3, autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: t.text2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.brand, foregroundColor: Colors.white),
            onPressed: () async {
              final newContent = ctrl.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                await _chatService.editMessage(message.messageId, newContent);
                setState(() { _messageMap[message.messageId] = message.copyWith(content: newContent, isEdited: true); });
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Message message, ThemeProvider t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Delete Message?', style: TextStyle(color: t.text1)),
        content: Text('This message will be deleted for everyone.', style: TextStyle(color: t.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: t.text2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _chatService.deleteMessageForEveryone(message.messageId);
              setState(() { _messageMap.remove(message.messageId); _messageIds.remove(message.messageId); });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (_otherUser == null) return '';
    if (_isOtherUserTyping) return 'typing...';
    final isOnline = _isActuallyOnline(_otherUser);
    if (isOnline) return 'online';
    if (_otherUser!.lastSeen != null) return 'last seen ${DateUtil.formatLastSeen(_otherUser!.lastSeen!)}';
    return 'offline';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _buildAppBar(t),
      body: Column(children: [
        if (_pinnedMessage != null) _buildPinnedMessageBar(t),
        Expanded(child: _buildMessagesList(t)),
        if (_isOtherUserTyping) _buildTypingIndicator(t),
        ChatInputWidget(
          onSendMessage: _sendMessage,
          replyToMessage: _replyToMessage,
          onCancelReply: () => setState(() => _replyToMessage = null),
          onTypingStart: () => _chatService.startTyping(widget.chatId),
          onTypingStop: () => _chatService.stopTyping(widget.chatId),
        ),
      ]),
      floatingActionButton: _showScrollToBottom ? _buildScrollToBottomButton(t) : null,
    );
  }

  Widget _buildTypingIndicator(ThemeProvider t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(children: [
        const SizedBox(width: 8),
        _TypingDots(color: t.text2),
        const SizedBox(width: 8),
        Text('${_otherUser?.fullName ?? 'User'} is typing...',
            style: TextStyle(fontSize: 12, color: t.text2, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeProvider t) {
    final isOnline = _isActuallyOnline(_otherUser);

    if (_isSearching) {
      return AppBar(
        backgroundColor: t.surface,
        foregroundColor: t.text1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: t.text1), onPressed: _searchInChat),
        title: TextField(
          autofocus: true,
          style: TextStyle(color: t.text1),
          decoration: InputDecoration(
            hintText: 'Search...', hintStyle: TextStyle(color: t.text2),
            border: InputBorder.none,
            suffixText: _searchResultCount > 0 ? '$_currentSearchIndex of $_searchResultCount' : null,
            suffixStyle: TextStyle(fontSize: 12, color: t.text2),
          ),
          onChanged: _updateSearchQuery,
        ),
      );
    }

    return AppBar(
      backgroundColor: t.surface,
      foregroundColor: t.text1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(icon: Icon(Icons.arrow_back, color: t.text1), onPressed: () => Navigator.pop(context)),
      title: InkWell(
        onTap: _openUserProfile,
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 20, backgroundColor: t.brand,
              backgroundImage: _otherUser?.profilePictureUrl != null ? NetworkImage(_otherUser!.profilePictureUrl!) : null,
              child: _otherUser?.profilePictureUrl == null
                  ? Text(_otherUser?.fullName?.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                  : null,
            ),
            if (isOnline) Positioned(right: 0, bottom: 0,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: Colors.greenAccent, shape: BoxShape.circle,
                  border: Border.all(color: t.surface, width: 2),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _otherUser?.fullName ?? _otherUser?.username ?? 'Loading...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.text1),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _getStatusText(),
                style: TextStyle(fontSize: 12, color: (_isOtherUserTyping || isOnline) ? Colors.greenAccent : t.text2),
              ),
            ],
          )),
        ]),
      ),
      actions: [
        IconButton(icon: Icon(Icons.search, color: t.text1), onPressed: _searchInChat),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: t.text1),
          color: t.surface2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.border)),
          onSelected: (value) { if (value == 'view_profile') _openUserProfile(); },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'view_profile', child: Text('View Profile', style: TextStyle(color: t.text1))),
            PopupMenuItem(value: 'mute',         child: Text('Mute',         style: TextStyle(color: t.text1))),
            PopupMenuItem(value: 'clear_chat',   child: Text('Clear Chat',   style: TextStyle(color: t.text1))),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: t.border),
      ),
    );
  }

  Widget _buildPinnedMessageBar(ThemeProvider t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: t.surface2, border: Border(bottom: BorderSide(color: t.border))),
      child: Row(children: [
        Icon(Icons.push_pin, size: 18, color: t.accent),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pinned Message', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: t.accent)),
          Text(_pinnedMessage?.content ?? 'Media',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: t.text2)),
        ])),
        IconButton(
          icon: Icon(Icons.close, color: t.text2, size: 18),
          onPressed: () async {
            await _chatService.unpinMessage(_pinnedMessage!.messageId);
            setState(() { _pinnedMessage = null; });
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _buildMessagesList(ThemeProvider t) {
    final filteredIds = _searchQuery.isEmpty
        ? _messageIds
        : _messageIds.where((id) => _messageMap[id]!.content?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false).toList();

    if (filteredIds.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline, size: 64, color: t.text2.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text(
          _searchQuery.isEmpty ? 'No messages yet\nSay hi! 👋' : 'No messages found',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: t.text2),
        ),
      ]));
    }

    return Container(
      color: t.bg,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        itemCount: filteredIds.length,
        itemBuilder: (_, index) {
          final messageId    = filteredIds[index];
          final message      = _messageMap[messageId]!;
          final previousMsg  = index > 0 ? _messageMap[filteredIds[index - 1]] : null;
          final isMe         = message.senderId == _chatService.currentUserId;
          final showDateDiv  = DateUtil.shouldShowDateDivider(previousMsg?.createdAt, message.createdAt);
          final showAvatar   = previousMsg == null || previousMsg.senderId != message.senderId || showDateDiv;
          final replyToMsg   = message.replyToMessageId != null ? _messageMap[message.replyToMessageId] : null;

          return Column(
            key: ValueKey(messageId),
            children: [
              if (showDateDiv) DateDivider(dateText: DateUtil.getDateDivider(message.createdAt)),
              MessageBubble(
                key: ValueKey('bubble_$messageId'),
                message: message, sender: _otherUser,
                isMe: isMe, showAvatar: showAvatar,
                onLongPress: () => _showMessageOptions(message, t),
                replyToMessage: replyToMsg,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScrollToBottomButton(ThemeProvider t) {
    return FloatingActionButton.small(
      onPressed: _scrollToBottom,
      backgroundColor: t.brand,
      child: const Icon(Icons.arrow_downward, color: Colors.white),
    );
  }
}

// ════════════════════════════════
//  Animated Typing Dots
// ════════════════════════════════
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400)));
    _animations = _controllers.map((c) =>
      Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))
    ).toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => AnimatedBuilder(
        animation: _animations[i],
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _animations[i].value),
          child: Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        ),
      )),
    );
  }
}