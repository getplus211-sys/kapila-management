import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/local_storage_service.dart';
import '../utils/date_util.dart';
import '../widgets/message_bubble.dart';
import '../widgets/divider_widgets.dart';

class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({Key? key}) : super(key: key);

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  
  List<Message> _messages = [];
  bool _showScrollToBottom = false;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSavedMessages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedMessages() async {
    // TODO: Get saved messages from your storage
    // For now, empty list
    _messages = [];
    
    if (mounted) {
      setState(() {});
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
      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    }
  }

  void _searchInChat() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
      }
    });
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
              
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
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
              
              ListTile(
                leading: const Icon(Icons.forward),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Forward - coming soon')),
                  );
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Delete message
                },
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildMessagesList(),
      floatingActionButton: _showScrollToBottom
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              child: const Icon(Icons.arrow_downward),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _searchInChat,
        ),
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search saved messages...',
            border: InputBorder.none,
          ),
          onChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
        ),
      );
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Saved Messages'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _searchInChat,
        ),
      ],
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
              Icons.bookmark_border,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No saved messages yet\nSave important messages here!'
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: filteredMessages.length,
      itemBuilder: (context, index) {
        final message = filteredMessages[index];
        final previousMessage = index > 0 ? filteredMessages[index - 1] : null;
        
        // Show date divider if different day
        final showDateDivider = previousMessage == null ||
            DateUtil.shouldShowDateDivider(
              previousMessage.createdAt,
              message.createdAt,
            );

        final showAvatar = previousMessage == null ||
            previousMessage.senderId != message.senderId ||
            showDateDivider;

        return Column(
          key: ValueKey(message.messageId),
          children: [
            if (showDateDivider)
              DateDivider(
                dateText: DateUtil.getDateDivider(message.createdAt),
              ),
            
            MessageBubble(
              key: ValueKey('bubble_${message.messageId}'),
              message: message,
              sender: null,
              isMe: true,
              showAvatar: showAvatar,
              onLongPress: () => _showMessageOptions(message),
              replyToMessage: null,
            ),
          ],
        );
      },
    );
  }
}