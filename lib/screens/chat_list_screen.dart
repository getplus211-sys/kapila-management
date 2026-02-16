import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/chat_item.dart';
import '../models/chat_model.dart';
import '../services/local_storage_service.dart';
import 'chat_window_screen.dart';
import 'contacts_screen.dart';
import 'saved_messages_screen.dart';
import 'settings_screen.dart';
import 'create_story_screen.dart';
import 'all_stories_screen.dart';
import 'view_stories_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _storage = LocalStorageService();
  
  List<ChatItem> _allChats = [];
  List<ChatItem> _filteredChats = [];
  List<StoryUser> _stories = [];
  List<String> _selectedChatIds = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSelectionMode = false;
  String _searchQuery = '';
  late TabController _tabController;
  
  final List<String> _filters = ['Stories', 'All', 'Unread', 'Groups', 'Channels'];
  int _selectedFilterIndex = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.index = 1;
    _loadCachedChats();
    _loadChats();
    _loadStories();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadCachedChats() {
    final cached = _storage.getCachedChatList();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _allChats = cached.map((c) => ChatItem(
          chatId: c['chatId'],
          chatType: ChatType.values.firstWhere((e) => e.toString() == c['chatType']),
          name: c['name'],
          avatarUrl: c['avatarUrl'],
          lastMessage: c['lastMessage'],
          lastMessageTime: DateTime.parse(c['lastMessageTime']),
          unreadCount: c['unreadCount'] ?? 0,
          isPinned: _storage.isChatPinned(c['chatId']),
          isMuted: c['isMuted'] ?? false,
          isOnline: c['isOnline'] ?? false,
          lastSeen: c['lastSeen'] != null ? DateTime.parse(c['lastSeen']) : null,
        )).toList();
        
        final archivedIds = _storage.getArchivedChats();
        _allChats = _allChats.where((chat) => !archivedIds.contains(chat.chatId)).toList();
        
        _filterChats();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStories() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final myStories = await _supabase
          .from('ngm_stories')
          .select('*')
          .eq('user_id', userId)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final contacts = await _supabase
          .from('ngm_contacts')
          .select('contact_user_id')
          .eq('user_id', userId);

      final contactIds = contacts.map((c) => c['contact_user_id'] as String).toList();

      final contactStories = contactIds.isEmpty ? [] : await _supabase
          .from('ngm_stories')
          .select('*, ngm_users!inner(full_name, username, profile_picture_url)')
          .filter('user_id', 'in', '(${contactIds.join(',')})')
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final Map<String, List<dynamic>> storiesByUser = {};
      
      for (var story in contactStories) {
        final uid = story['user_id'];
        if (!storiesByUser.containsKey(uid)) {
          storiesByUser[uid] = [];
        }
        storiesByUser[uid]!.add(story);
      }

      final List<StoryUser> storyUsers = [];

      if (myStories.isNotEmpty) {
        final myUser = await _supabase
            .from('ngm_users')
            .select('full_name, username, profile_picture_url')
            .eq('user_id', userId)
            .single();

        storyUsers.add(StoryUser(
          userId: userId,
          userName: 'My Story',
          userImage: myUser['profile_picture_url'],
          storyCount: myStories.length,
          lastStoryTime: DateTime.parse(myStories.first['created_at']),
          isViewed: false,
          stories: myStories,
        ));
      }

      for (var entry in storiesByUser.entries) {
        final userStories = entry.value;
        final userData = userStories.first['ngm_users'];
        
        final viewedCount = await _supabase
            .from('ngm_story_views')
            .select('story_id')
            .eq('viewer_id', userId)
            .filter('story_id', 'in', '(${userStories.map((s) => s['story_id']).join(',')})');

        final isViewed = viewedCount.length == userStories.length;

        storyUsers.add(StoryUser(
          userId: entry.key,
          userName: userData['full_name'] ?? userData['username'] ?? 'Unknown',
          userImage: userData['profile_picture_url'],
          storyCount: userStories.length,
          lastStoryTime: DateTime.parse(userStories.first['created_at']),
          isViewed: isViewed,
          stories: userStories,
        ));
      }

      setState(() {
        _stories = storyUsers;
      });
    } catch (e) {
      debugPrint('Error loading stories: $e');
    }
  }

  // ✅ FIXED: Complete _loadChats with proper debugging
  Future<void> _loadChats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      debugPrint('\n═══════════════════════════════════════');
      debugPrint('🔍 START: _loadChats()');
      debugPrint('═══════════════════════════════════════');
      debugPrint('📌 Current User ID: $userId');
      
      if (userId == null) {
        debugPrint('❌ ERROR: userId is NULL');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      debugPrint('\n📍 STEP 1: Loading chat participants...');
      
      final participantResponse = await _supabase
          .from('ngm_chat_participants')
          .select('chat_id, unread_count, is_muted')
          .eq('user_id', userId)
          .eq('is_active', true);

      debugPrint('✅ Found ${participantResponse.length} participants');

      final List<ChatItem> chats = [];
      
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
      debugPrint('✅ Added Saved Messages');

      debugPrint('\n📍 STEP 2: Loading chat details...');
      
      int successCount = 0;
      int errorCount = 0;
      
      for (var participant in participantResponse as List) {
        try {
          final chatId = participant['chat_id'];
          debugPrint('\n  📌 Chat ID: $chatId');
          
          final chatResponse = await _supabase
              .from('ngm_chats')
              .select('*')
              .eq('chat_id', chatId)
              .maybeSingle();
          
          if (chatResponse == null) {
            debugPrint('    ❌ Chat not found in ngm_chats');
            errorCount++;
            continue;
          }

          debugPrint('    ✅ Chat type: ${chatResponse['chat_type']}');
          
          final chatType = chatResponse['chat_type'];
          
          // Get last message
          final lastMessage = await _supabase
              .from('ngm_messages')
              .select('content, created_at')
              .eq('chat_id', chatId)
              .eq('is_deleted', false)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          
          ChatItem? chatItem;
          
          if (chatType == 'private' || chatType == 'personal') {
            final otherUserId = chatResponse['user1_id'] == userId 
                ? chatResponse['user2_id'] 
                : chatResponse['user1_id'];
            
            final userInfo = await _supabase
                .from('ngm_users')
                .select('full_name, username, profile_picture_url, is_online, last_seen')
                .eq('user_id', otherUserId)
                .maybeSingle();
            
            if (userInfo == null) {
              debugPrint('    ❌ User not found');
              errorCount++;
              continue;
            }

            debugPrint('    ✅ User: ${userInfo['full_name']}');
            
            chatItem = ChatItem(
              chatId: chatId,
              chatType: ChatType.private,
              name: userInfo['full_name'] ?? userInfo['username'] ?? 'Unknown',
              avatarUrl: userInfo['profile_picture_url'],
              lastMessage: lastMessage?['content'] ?? 'No messages',
              lastMessageTime: lastMessage != null 
                  ? DateTime.parse(lastMessage['created_at']) 
                  : DateTime.parse(chatResponse['created_at']),
              unreadCount: participant['unread_count'] ?? 0,
              isPinned: _storage.isChatPinned(chatId),
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
                .select('group_name, group_picture_url')
                .eq('chat_id', chatId)
                .maybeSingle();
            
            if (groupInfo == null) {
              debugPrint('    ❌ Group not found');
              errorCount++;
              continue;
            }

            debugPrint('    ✅ Group: ${groupInfo['group_name']}');
            
            chatItem = ChatItem(
              chatId: chatId,
              chatType: ChatType.group,
              name: groupInfo['group_name'] ?? 'Group',
              avatarUrl: groupInfo['group_picture_url'],
              lastMessage: lastMessage?['content'] ?? 'No messages',
              lastMessageTime: lastMessage != null 
                  ? DateTime.parse(lastMessage['created_at']) 
                  : DateTime.parse(chatResponse['created_at']),
              unreadCount: participant['unread_count'] ?? 0,
              isPinned: _storage.isChatPinned(chatId),
              isMuted: participant['is_muted'] ?? false,
            );
          } 
          else if (chatType == 'channel') {
            final channelInfo = await _supabase
                .from('ngm_channels')
                .select('channel_name, channel_picture_url')
                .eq('chat_id', chatId)
                .maybeSingle();
            
            if (channelInfo == null) {
              debugPrint('    ❌ Channel not found');
              errorCount++;
              continue;
            }

            debugPrint('    ✅ Channel: ${channelInfo['channel_name']}');
            
            chatItem = ChatItem(
              chatId: chatId,
              chatType: ChatType.channel,
              name: channelInfo['channel_name'] ?? 'Channel',
              avatarUrl: channelInfo['channel_picture_url'],
              lastMessage: lastMessage?['content'] ?? 'No messages',
              lastMessageTime: lastMessage != null 
                  ? DateTime.parse(lastMessage['created_at']) 
                  : DateTime.parse(chatResponse['created_at']),
              unreadCount: participant['unread_count'] ?? 0,
              isPinned: _storage.isChatPinned(chatId),
              isMuted: participant['is_muted'] ?? false,
            );
          }
          
          if (chatItem != null) {
            chats.add(chatItem);
            successCount++;
            debugPrint('    ✅ Added to list');
          }
        } catch (e) {
          debugPrint('    ❌ Error: $e');
          errorCount++;
        }
      }

      debugPrint('\n📊 Load Summary:');
      debugPrint('  ✅ Success: $successCount');
      debugPrint('  ❌ Failed: $errorCount');

      final archivedIds = _storage.getArchivedChats();
      final activeChats = chats.where((chat) => !archivedIds.contains(chat.chatId)).toList();

      await _storage.saveChatList(activeChats.map((c) => {
        'chatId': c.chatId,
        'chatType': c.chatType.toString(),
        'name': c.name,
        'avatarUrl': c.avatarUrl,
        'lastMessage': c.lastMessage,
        'lastMessageTime': c.lastMessageTime.toIso8601String(),
        'unreadCount': c.unreadCount,
        'isMuted': c.isMuted,
        'isOnline': c.isOnline ?? false,
        'lastSeen': c.lastSeen?.toIso8601String(),
      }).toList());

      if (mounted) {
        setState(() {
          _allChats = activeChats;
          _filterChats();
          _isLoading = false;
        });
      }
      
      debugPrint('\n✅ COMPLETE: Total chats = ${activeChats.length}');
      debugPrint('═══════════════════════════════════════\n');
    } catch (e) {
      debugPrint('\n❌ FATAL ERROR: $e');
      debugPrint('═══════════════════════════════════════\n');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ FIXED: Better realtime subscription for instant updates
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    debugPrint('\n🔔 Setting up realtime subscriptions...');

    // ✅ Subscribe to chat participant changes (new chats, archival, etc.)
    _supabase
        .channel('chat_participants_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ngm_chat_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('🔔 [1] Chat participant changed - RELOADING');
            _loadChats();
          },
        )
        .subscribe();

    // ✅ Subscribe to ALL message inserts globally (THIS IS KEY!)
    _supabase
        .channel('all_messages_global_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ngm_messages',
          callback: (payload) async {
            try {
              final chatId = payload.newRecord['chat_id'];
              final senderId = payload.newRecord['sender_id'];

              debugPrint('🔔 [2] New message in chat: $chatId from sender: $senderId');

              // Check if current user is in this chat
              final isUserInChat = await _supabase
                  .from('ngm_chat_participants')
                  .select('chat_id')
                  .eq('chat_id', chatId)
                  .eq('user_id', userId)
                  .maybeSingle();

              if (isUserInChat != null) {
                debugPrint('✅ Message is for MY chat - RELOADING chat list');
                _loadChats();
              } else {
                debugPrint('⚠️ Message is NOT for my chat - ignoring');
              }
            } catch (e) {
              debugPrint('Error in message subscription: $e');
            }
          },
        )
        .subscribe();

    // ✅ Subscribe to chat table updates (last message time)
    _supabase
        .channel('chats_updates_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ngm_chats',
          callback: (payload) {
            final chatId = payload.newRecord['chat_id'];
            debugPrint('🔔 [3] Chat updated: $chatId - RELOADING');
            _loadChats();
          },
        )
        .subscribe();

    // ✅ Subscribe to message updates (edits, deletes)
    _supabase
        .channel('messages_updates_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ngm_messages',
          callback: (payload) {
            debugPrint('🔔 [4] Message updated - RELOADING');
            _loadChats();
          },
        )
        .subscribe();

    debugPrint('✅ All realtime subscriptions active\n');
  }

  void _filterChats() {
    List<ChatItem> filtered = _allChats;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((chat) => 
        chat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        chat.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    switch (_selectedFilterIndex) {
      case 0:
        filtered = _allChats;
        break;
      case 1:
        break;
      case 2:
        filtered = filtered.where((chat) => chat.unreadCount > 0).toList();
        break;
      case 3:
        filtered = filtered.where((chat) => chat.chatType == ChatType.group).toList();
        break;
      case 4:
        filtered = filtered.where((chat) => chat.chatType == ChatType.channel).toList();
        break;
    }

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

  void _toggleSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChatIds.add(chatId);
        _isSelectionMode = true;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedChatIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _archiveSelectedChats() async {
    for (final chatId in _selectedChatIds) {
      await _storage.archiveChat(chatId);
    }
    
    final count = _selectedChatIds.length;
    final archived = List<String>.from(_selectedChatIds);
    
    _cancelSelection();
    _loadChats();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count chat${count > 1 ? 's' : ''} archived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final chatId in archived) {
                await _storage.unarchiveChat(chatId);
              }
              _loadChats();
            },
          ),
        ),
      );
    }
  }

  void _showMediaSendOptions() {
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Contact to Send',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildMediaOption(
              icon: Icons.camera_alt,
              title: 'Camera',
              subtitle: 'Take a photo or video',
              color: Colors.pink,
              onTap: () async {
                Navigator.pop(context);
                final image = await _imagePicker.pickImage(source: ImageSource.camera);
                if (image != null) {
                  _showContactSelectorForMedia(File(image.path), 'image');
                }
              },
            ),
            _buildMediaOption(
              icon: Icons.photo_library,
              title: 'Gallery',
              subtitle: 'Choose photo from gallery',
              color: Colors.purple,
              onTap: () async {
                Navigator.pop(context);
                final image = await _imagePicker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  _showContactSelectorForMedia(File(image.path), 'image');
                }
              },
            ),
            _buildMediaOption(
              icon: Icons.videocam,
              title: 'Video',
              subtitle: 'Choose video',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
                if (video != null) {
                  _showContactSelectorForMedia(File(video.path), 'video');
                }
              },
            ),
            _buildMediaOption(
              icon: Icons.insert_drive_file,
              title: 'Document',
              subtitle: 'Share files',
              color: Colors.blue,
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.first.path != null) {
                  _showContactSelectorForMedia(File(result.files.first.path!), 'file');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showContactSelectorForMedia(File mediaFile, String mediaType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ContactSelectorForMedia(
            mediaFile: mediaFile,
            mediaType: mediaType,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  Widget _buildMediaOption({
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
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          if (_selectedFilterIndex == 0) _buildStoriesGrid(),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F00)))
                : _filteredChats.isEmpty && _selectedFilterIndex != 0
                    ? _buildEmptyState()
                    : _selectedFilterIndex == 0
                        ? const SizedBox.shrink()
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _loadChats();
                              await _loadStories();
                            },
                            child: ListView.builder(
                              itemCount: _filteredChats.length,
                              itemBuilder: (context, index) {
                                final chat = _filteredChats[index];
                                
                                if (chat.chatId == 'saved_messages') {
                                  return ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFFF6F00),
                                      child: Icon(Icons.bookmark, color: Colors.white),
                                    ),
                                    title: const Text('Saved Messages', style: TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: const Text('Your saved messages'),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SavedMessagesScreen()),
                                      );
                                    },
                                  );
                                }
                                
                                return _buildChatItem(chat);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : _buildFloatingButtons(),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
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
          : const Text('Nandigram', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: _toggleSearch,
        ),
        IconButton(
          icon: const Icon(Icons.camera_alt),
          onPressed: _showMediaSendOptions,
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'contacts',
              child: Row(
                children: [Icon(Icons.contacts), SizedBox(width: 12), Text('Contacts')],
              ),
            ),
            const PopupMenuItem(
              value: 'archived',
              child: Row(
                children: [Icon(Icons.archive), SizedBox(width: 12), Text('Archived Chats')],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [Icon(Icons.settings), SizedBox(width: 12), Text('Settings')],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'contacts':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactsScreen()),
                ).then((_) {
                  // ✅ Force refresh when returning from contacts
                  debugPrint('🔄 Returned from ContactsScreen (menu) - force refreshing...');
                  _loadChats();
                  _loadStories();
                });
                break;
              case 'archived':
                _showArchivedChats();
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
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      elevation: 0.5,
      backgroundColor: const Color(0xFFFF6F00),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _cancelSelection,
      ),
      title: Text('${_selectedChatIds.length} selected'),
      actions: [
        IconButton(
          icon: const Icon(Icons.push_pin),
          onPressed: () async {
            for (final chatId in _selectedChatIds) {
              if (_storage.isChatPinned(chatId)) {
                await _storage.unpinChat(chatId);
              } else {
                await _storage.pinChat(chatId);
              }
            }
            _cancelSelection();
            _loadChats();
          },
        ),
        IconButton(
          icon: const Icon(Icons.archive),
          onPressed: _archiveSelectedChats,
        ),
      ],
    );
  }

  Widget _buildStoriesGrid() {
    if (_stories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.auto_stories_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('No stories yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text(
                'Create your first story or view stories from contacts',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ViewStoriesScreen(storyUser: story)),
              ).then((_) => _loadStories());
            },
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: !story.isViewed
                        ? const LinearGradient(colors: [Color(0xFFFF6F00), Colors.orange])
                        : null,
                    border: Border.all(
                      color: story.isViewed ? Colors.grey[400]! : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFFF6F00),
                    backgroundImage: story.userImage != null ? NetworkImage(story.userImage!) : null,
                    child: story.userImage == null
                        ? Text(
                            story.userName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  story.userName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatItem(ChatItem chat) {
    final isSelected = _selectedChatIds.contains(chat.chatId);
    
    return ListTile(
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(chat.chatId),
              activeColor: const Color(0xFFFF6F00),
            )
          : CircleAvatar(
              backgroundColor: const Color(0xFFFF6F00),
              backgroundImage: chat.avatarUrl != null ? NetworkImage(chat.avatarUrl!) : null,
              child: chat.avatarUrl == null
                  ? Text(chat.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                  : null,
            ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.isPinned)
            const Icon(Icons.push_pin, size: 16, color: Colors.grey),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: chat.unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (chat.chatType == ChatType.private && (chat.isOnline ?? false))
            const Text('online', style: TextStyle(color: Color(0xFFFF6F00), fontSize: 11)),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: chat.unreadCount > 0 ? const Color(0xFFFF6F00) : Colors.grey,
            ),
          ),
          if (chat.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6F00),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${chat.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(chat.chatId);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatWindowScreen(
                chatId: chat.chatId,
                otherUserId: chat.chatId, 
              ),
            ),
          ).then((_) => _loadChats());
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelection(chat.chatId);
        }
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    
    return '${time.day}/${time.month}';
  }

  void _showArchivedChats() {
    final archivedIds = _storage.getArchivedChats();
    
    if (archivedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No archived chats')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final archivedChats = _allChats.where((c) => archivedIds.contains(c.chatId)).toList();
          
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Archived Chats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () async {
                        for (final chatId in archivedIds) {
                          await _storage.unarchiveChat(chatId);
                        }
                        Navigator.pop(context);
                        _loadChats();
                      },
                      icon: const Icon(Icons.unarchive, size: 18),
                      label: const Text('Unarchive All'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6F00)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: archivedChats.length,
                    itemBuilder: (context, index) {
                      final chat = archivedChats[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFF6F00),
                          backgroundImage: chat.avatarUrl != null ? NetworkImage(chat.avatarUrl!) : null,
                          child: chat.avatarUrl == null
                              ? Text(chat.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        title: Text(chat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.unarchive, color: Color(0xFFFF6F00)),
                          onPressed: () async {
                            await _storage.unarchiveChat(chat.chatId);
                            Navigator.pop(context);
                            _loadChats();
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatWindowScreen(
                                chatId: chat.chatId,
                                otherUserId: chat.chatId, 
                              ),
                            ),
                          ).then((_) => _loadChats());
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ FIXED: Force refresh on FAB press
  Widget _buildFloatingButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'story_btn',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
            ).then((_) => _loadStories());
          },
          backgroundColor: Colors.white,
          child: const Icon(Icons.add_a_photo, color: Color(0xFFFF6F00)),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'chat_btn',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            ).then((_) {
              // ✅ Force refresh when returning from contacts
              debugPrint('🔄 Returned from ContactsScreen (FAB) - force refreshing...');
              _loadChats();
              _loadStories();
            });
          },
          backgroundColor: const Color(0xFFFF6F00),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No chats yet', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Start a new conversation', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              ).then((_) {
                // ✅ Force refresh when returning from contacts
                debugPrint('🔄 Returned from ContactsScreen (empty state) - force refreshing...');
                _loadChats();
                _loadStories();
              });
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
}

class StoryUser {
  final String userId;
  final String userName;
  final String? userImage;
  final int storyCount;
  final DateTime lastStoryTime;
  final bool isViewed;
  final List<dynamic> stories;

  StoryUser({
    required this.userId,
    required this.userName,
    this.userImage,
    required this.storyCount,
    required this.lastStoryTime,
    required this.isViewed,
    required this.stories,
  });
}

class ContactSelectorForMedia extends StatefulWidget {
  final File mediaFile;
  final String mediaType;
  final ScrollController scrollController;

  const ContactSelectorForMedia({
    super.key,
    required this.mediaFile,
    required this.mediaType,
    required this.scrollController,
  });

  @override
  State<ContactSelectorForMedia> createState() => _ContactSelectorForMediaState();
}

class _ContactSelectorForMediaState extends State<ContactSelectorForMedia> {
  final _supabase = Supabase.instance.client;
  final _storage = LocalStorageService();
  List<ContactItem> _contacts = [];
  List<ChatItem> _recentChats = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContactsAndChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContactsAndChats() async {
    try {
      final cachedContacts = _storage.getCachedContacts();
      final cachedChats = _storage.getCachedChatList();

      if (cachedContacts != null) {
        setState(() {
          _contacts = cachedContacts
              .where((c) => c['isRegistered'] == true)
              .map((c) => ContactItem(
                    contactName: c['contactName'] ?? 'Unknown',
                    phoneNumber: c['phoneNumber'] ?? '',
                    isRegistered: true,
                    userId: c['userId'],
                    fullName: c['fullName'],
                    username: c['username'],
                    profilePictureUrl: c['profilePictureUrl'],
                    isOnline: c['isOnline'] ?? false,
                    bio: c['bio'],
                  ))
              .toList();
        });
      }

      if (cachedChats != null) {
        setState(() {
          _recentChats = cachedChats
              .take(5)
              .map((c) => ChatItem(
                    chatId: c['chatId'],
                    chatType: ChatType.values.firstWhere((e) => e.toString() == c['chatType']),
                    name: c['name'],
                    avatarUrl: c['avatarUrl'],
                    lastMessage: c['lastMessage'],
                    lastMessageTime: DateTime.parse(c['lastMessageTime']),
                    unreadCount: c['unreadCount'] ?? 0,
                    isPinned: false,
                    isMuted: c['isMuted'] ?? false,
                  ))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMediaToChat(String chatId, String chatName) async {
    try {
      Navigator.pop(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6F00)),
        ),
      );

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_${widget.mediaType}';
      String bucket = 'chat-media';

      await _supabase.storage.from(bucket).upload(
            fileName,
            widget.mediaFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final mediaUrl = _supabase.storage.from(bucket).getPublicUrl(fileName);

      await _supabase.from('ngm_messages').insert({
        'chat_id': chatId,
        'sender_id': userId,
        'message_type': widget.mediaType,
        'content': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to $chatName')),
      );
    } catch (e) {
      debugPrint('Error sending media: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ✅ FIXED: Better chat creation for media send with self-chat prevention
  Future<void> _sendMediaToContact(ContactItem contact) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || contact.userId == null) return;

      // ✅ Prevent self-chat
      if (userId == contact.userId) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot send to yourself')),
          );
        }
        return;
      }

      // ✅ Check for existing chat with chat_type filter
      final existing = await _supabase
          .from('ngm_chats')
          .select('chat_id')
          .or('and(user1_id.eq.$userId,user2_id.eq.${contact.userId}),and(user1_id.eq.${contact.userId},user2_id.eq.$userId)')
          .eq('chat_type', 'private')  // ✅ Only private chats
          .maybeSingle();

      String chatId;

      if (existing != null) {
        chatId = existing['chat_id'];
      } else {
        final chat = await _supabase.from('ngm_chats').insert({
          'chat_type': 'private',
          'user1_id': userId,
          'user2_id': contact.userId,
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();

        chatId = chat['chat_id'];

        await _supabase.from('ngm_chat_participants').insert([
          {
            'chat_id': chatId,
            'user_id': userId,
            'is_active': true,
            'is_pinned': false,
            'is_muted': false,
            'is_archived': false,
            'unread_count': 0,
          },
          {
            'chat_id': chatId,
            'user_id': contact.userId,
            'is_active': true,
            'is_pinned': false,
            'is_muted': false,
            'is_archived': false,
            'unread_count': 0,
          },
        ]);
        
        // ✅ Wait for sync
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await _sendMediaToChat(chatId, contact.contactName);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<dynamic> _getFilteredItems() {
    if (_searchQuery.isEmpty) {
      return [..._recentChats, ..._contacts];
    }

    final query = _searchQuery.toLowerCase();
    final filteredChats = _recentChats.where((chat) => chat.name.toLowerCase().contains(query)).toList();
    final filteredContacts = _contacts.where((contact) => contact.contactName.toLowerCase().contains(query)).toList();

    return [...filteredChats, ...filteredContacts];
  }

  @override
  Widget build(BuildContext context) {
    final items = _getFilteredItems();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Send to...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search contacts or chats',
              prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6F00)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: widget.mediaType == 'image'
                  ? Image.file(widget.mediaFile, fit: BoxFit.cover)
                  : widget.mediaType == 'video'
                      ? const Icon(Icons.videocam, size: 50, color: Colors.grey)
                      : const Icon(Icons.insert_drive_file, size: 50, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F00)))
                : items.isEmpty
                    ? const Center(child: Text('No contacts or chats found'))
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];

                          if (item is ChatItem) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFF6F00),
                                backgroundImage: item.avatarUrl != null ? NetworkImage(item.avatarUrl!) : null,
                                child: item.avatarUrl == null
                                    ? Text(item.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                    : null,
                              ),
                              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Recent chat', style: TextStyle(fontSize: 12)),
                              onTap: () => _sendMediaToChat(item.chatId, item.name),
                            );
                          } else if (item is ContactItem) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFF6F00),
                                backgroundImage: item.profilePictureUrl != null ? NetworkImage(item.profilePictureUrl!) : null,
                                child: item.profilePictureUrl == null
                                    ? Text(item.contactName[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                    : null,
                              ),
                              title: Text(item.contactName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('@${item.username ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFFFF6F00))),
                              onTap: () => _sendMediaToContact(item),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class ContactItem {
  final String contactName;
  final String phoneNumber;
  final bool isRegistered;
  final String? userId;
  final String? fullName;
  final String? username;
  final String? profilePictureUrl;
  final bool isOnline;
  final String? bio;

  ContactItem({
    required this.contactName,
    required this.phoneNumber,
    required this.isRegistered,
    this.userId,
    this.fullName,
    this.username,
    this.profilePictureUrl,
    this.isOnline = false,
    this.bio,
  });
}