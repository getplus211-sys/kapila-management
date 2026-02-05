import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chat_model.dart';
import '../widgets/chat_list_item.dart';
import 'chat_window_screen.dart';
import 'contacts_screen.dart';
import 'new_group_screen.dart';
import 'new_channel_screen.dart';
import 'saved_messages_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  
  List<ChatItem> _allChats = [];
  List<ChatItem> _filteredChats = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  late TabController _tabController;
  
  // Filter tabs - Added "Saved" at the end
  final List<String> _filters = ['All', 'Unread', 'Groups', 'Channels', 'Saved'];
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _loadChats();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      setState(() => _isLoading = true);
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('User not logged in');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('Loading chats for user: $userId');

      // Load all chat participants for current user
      final participantResponse = await _supabase
          .from('ngm_chat_participants')
          .select('*')
          .eq('user_id', userId)
          .eq('is_active', true);

      debugPrint('Found ${participantResponse.length} chat participants');

      final List<ChatItem> chats = [];
      
      // Add Saved Messages as first chat
      final savedChatItem = ChatItem(
        chatId: 'saved_messages',
        chatType: ChatType.private,
        name: 'Saved Messages',
        avatarUrl: null,
        lastMessage: 'Your saved messages',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        isPinned: true,
        isMuted: false,
      );
      chats.add(savedChatItem);
      
      for (var participant in participantResponse as List) {
        final chatId = participant['chat_id'];
        
        // Get chat details
        final chatResponse = await _supabase
            .from('ngm_chats')
            .select()
            .eq('chat_id', chatId)
            .maybeSingle();
        
        if (chatResponse == null) continue;
        
        final chatType = chatResponse['chat_type'];
        ChatItem? chatItem;
        
        if (chatType == 'private') {
          // Get other user info
          final otherUserId = chatResponse['user1_id'] == userId 
              ? chatResponse['user2_id'] 
              : chatResponse['user1_id'];
          
          final userInfo = await _supabase
              .from('ngm_users')
              .select()
              .eq('user_id', otherUserId)
              .maybeSingle();
          
          if (userInfo == null) continue;
          
          // Get last message
          final lastMessage = await _supabase
              .from('ngm_messages')
              .select()
              .eq('chat_id', chatId)
              .eq('is_deleted', false)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          
          chatItem = ChatItem(
            chatId: chatId,
            chatType: ChatType.private,
            name: userInfo['full_name'] ?? userInfo['username'] ?? 'Unknown',
            avatarUrl: userInfo['profile_picture_url'],
            lastMessage: lastMessage?['content'] ?? '',
            lastMessageTime: lastMessage != null 
                ? DateTime.parse(lastMessage['created_at']) 
                : DateTime.parse(chatResponse['created_at']),
            unreadCount: participant['unread_count'] ?? 0,
            isPinned: participant['is_pinned'] ?? false,
            isMuted: participant['is_muted'] ?? false,
            isOnline: userInfo['is_online'] ?? false,
            lastSeen: userInfo['last_seen'] != null 
                ? DateTime.parse(userInfo['last_seen']) 
                : null,
          );
        } 
        else if (chatType == 'group') {
          final groupInfo = await _supabase
              .from('ngm_groups')
              .select()
              .eq('chat_id', chatId)
              .maybeSingle();
          
          if (groupInfo == null) continue;
          
          final lastMessage = await _supabase
              .from('ngm_messages')
              .select()
              .eq('chat_id', chatId)
              .eq('is_deleted', false)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          
          chatItem = ChatItem(
            chatId: chatId,
            chatType: ChatType.group,
            name: groupInfo['group_name'],
            avatarUrl: groupInfo['group_picture_url'],
            lastMessage: lastMessage?['content'] ?? '',
            lastMessageTime: lastMessage != null 
                ? DateTime.parse(lastMessage['created_at']) 
                : DateTime.parse(chatResponse['created_at']),
            unreadCount: participant['unread_count'] ?? 0,
            isPinned: participant['is_pinned'] ?? false,
            isMuted: participant['is_muted'] ?? false,
          );
        } 
        else if (chatType == 'channel') {
          final channelInfo = await _supabase
              .from('ngm_channels')
              .select()
              .eq('chat_id', chatId)
              .maybeSingle();
          
          if (channelInfo == null) continue;
          
          final lastMessage = await _supabase
              .from('ngm_messages')
              .select()
              .eq('chat_id', chatId)
              .eq('is_deleted', false)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          
          chatItem = ChatItem(
            chatId: chatId,
            chatType: ChatType.channel,
            name: channelInfo['channel_name'],
            avatarUrl: channelInfo['channel_picture_url'],
            lastMessage: lastMessage?['content'] ?? '',
            lastMessageTime: lastMessage != null 
                ? DateTime.parse(lastMessage['created_at']) 
                : DateTime.parse(chatResponse['created_at']),
            unreadCount: participant['unread_count'] ?? 0,
            isPinned: participant['is_pinned'] ?? false,
            isMuted: participant['is_muted'] ?? false,
          );
        }
        
        if (chatItem != null) {
          chats.add(chatItem);
        }
      }

      debugPrint('Loaded ${chats.length} chats');

      setState(() {
        _allChats = chats;
        _filterChats();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading chats: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: $e')),
        );
      }
    }
  }

  void _setupRealtimeSubscription() {
    _supabase
        .channel('chats_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ngm_messages',
          callback: (payload) {
            debugPrint('Realtime update received');
            _loadChats();
          },
        )
        .subscribe();
  }

  void _filterChats() {
    List<ChatItem> filtered = _allChats;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((chat) => 
        chat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        chat.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply tab filter
    switch (_selectedFilterIndex) {
      case 1: // Unread
        filtered = filtered.where((chat) => chat.unreadCount > 0).toList();
        break;
      case 2: // Groups
        filtered = filtered.where((chat) => chat.chatType == ChatType.group).toList();
        break;
      case 3: // Channels
        filtered = filtered.where((chat) => chat.chatType == ChatType.channel).toList();
        break;
      case 4: // Saved
        filtered = filtered.where((chat) => chat.chatId == 'saved_messages').toList();
        break;
    }

    // Sort: Pinned first, then by last message time
    filtered.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });

    setState(() {
      _filteredChats = filtered;
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _filterChats();
      }
    });
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
              icon: Icons.camera_alt,
              title: 'Camera',
              subtitle: 'Take a photo',
              color: Colors.pink,
              onTap: () async {
                Navigator.pop(context);
                final image = await _imagePicker.pickImage(source: ImageSource.camera);
                if (image != null) {
                  // TODO: Handle image selection
                  debugPrint('Camera image selected: ${image.path}');
                }
              },
            ),
            _buildAttachmentOption(
              icon: Icons.photo_library,
              title: 'Gallery',
              subtitle: 'Choose from gallery',
              color: Colors.purple,
              onTap: () async {
                Navigator.pop(context);
                final image = await _imagePicker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  // TODO: Handle image selection
                  debugPrint('Gallery image selected: ${image.path}');
                }
              },
            ),
            _buildAttachmentOption(
              icon: Icons.videocam,
              title: 'Video',
              subtitle: 'Record or choose video',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
                if (video != null) {
                  // TODO: Handle video selection
                  debugPrint('Video selected: ${video.path}');
                }
              },
            ),
            _buildAttachmentOption(
              icon: Icons.insert_drive_file,
              title: 'Document',
              subtitle: 'Share files',
              color: Colors.blue,
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles();
                if (result != null) {
                  // TODO: Handle file selection
                  debugPrint('File selected: ${result.files.first.path}');
                }
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
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _filterChats();
                  });
                },
              )
            : const Text(
                'Nandigram',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _showAttachmentOptions,
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'contacts',
                child: Row(
                  children: [
                    Icon(Icons.contacts),
                    SizedBox(width: 12),
                    Text('Contacts'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'contacts':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactsScreen()),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  break;
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFFFF6F00),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontSize: 15),
              onTap: (index) {
                setState(() {
                  _selectedFilterIndex = index;
                  _filterChats();
                });
              },
              tabs: _filters.map((filter) => Tab(text: filter)).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredChats.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  child: ListView.builder(
                    itemCount: _filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = _filteredChats[index];
                      
                      // Special handling for Saved Messages
                      if (chat.chatId == 'saved_messages') {
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFF6F00),
                            child: Icon(Icons.bookmark, color: Colors.white),
                          ),
                          title: const Text(
                            'Saved Messages',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Your saved messages'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SavedMessagesScreen()),
                            );
                          },
                        );
                      }
                      
                      return ChatListItemWidget(
                        chat: chat,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatWindowScreen(
                                chatId: chat.chatId,
                                chatName: chat.name,
                                chatType: chat.chatType,
                              ),
                            ),
                          ).then((_) => _loadChats());
                        },
                        onLongPress: () => _showChatOptions(chat),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          );
        },
        backgroundColor: const Color(0xFFFF6F00),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No chats yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Start Chatting'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6F00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(ChatItem chat) {
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
              leading: Icon(chat.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(chat.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                _togglePin(chat);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(chat.isMuted ? Icons.notifications : Icons.notifications_off),
              title: Text(chat.isMuted ? 'Unmute' : 'Mute'),
              onTap: () {
                _toggleMute(chat);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive'),
              onTap: () {
                _archiveChat(chat);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(chat);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin(ChatItem chat) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase
          .from('ngm_chat_participants')
          .update({'is_pinned': !chat.isPinned})
          .eq('chat_id', chat.chatId)
          .eq('user_id', userId!);
      
      _loadChats();
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  Future<void> _toggleMute(ChatItem chat) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase
          .from('ngm_chat_participants')
          .update({'is_muted': !chat.isMuted})
          .eq('chat_id', chat.chatId)
          .eq('user_id', userId!);
      
      _loadChats();
    } catch (e) {
      debugPrint('Error toggling mute: $e');
    }
  }

  Future<void> _archiveChat(ChatItem chat) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase
          .from('ngm_chat_participants')
          .update({'is_archived': true})
          .eq('chat_id', chat.chatId)
          .eq('user_id', userId!);
      
      _loadChats();
    } catch (e) {
      debugPrint('Error archiving chat: $e');
    }
  }

  void _confirmDelete(ChatItem chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('Are you sure you want to delete this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat(ChatItem chat) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase
          .from('ngm_chat_participants')
          .update({'is_active': false, 'left_at': DateTime.now().toIso8601String()})
          .eq('chat_id', chat.chatId)
          .eq('user_id', userId!);
      
      _loadChats();
    } catch (e) {
      debugPrint('Error deleting chat: $e');
    }
  }
}