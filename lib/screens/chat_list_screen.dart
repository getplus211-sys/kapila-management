import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/chat_item.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';
import 'theme_provider.dart';
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

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
  final List<RealtimeChannel> _realtimeChannels = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.index = 1;
    _loadCachedChats();
    _loadChats();
    _loadStories();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _searchController.dispose();
    for (final ch in _realtimeChannels) { _supabase.removeChannel(ch); }
    _realtimeChannels.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadChats();
  }

  bool _isActuallyOnline(ChatItem chat) {
    if (!(chat.isOnline ?? false)) return false;
    if (chat.lastSeen == null) return false;
    return DateTime.now().difference(chat.lastSeen!).inMinutes < 3;
  }

  void _loadCachedChats() {
    final cached = _storage.getCachedChatList();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _allChats = cached.map((c) => ChatItem(
          chatId: c['chatId'],
          chatType: ChatType.values.firstWhere((e) => e.toString() == c['chatType']),
          name: c['name'], avatarUrl: c['avatarUrl'],
          lastMessage: c['lastMessage'],
          lastMessageTime: DateTime.parse(c['lastMessageTime']),
          unreadCount: c['unreadCount'] ?? 0,
          isPinned: _storage.isChatPinned(c['chatId']),
          isMuted: c['isMuted'] ?? false,
          isOnline: c['isOnline'] ?? false,
          lastSeen: c['lastSeen'] != null ? DateTime.parse(c['lastSeen']) : null,
        )).toList();
        final archivedIds = _storage.getArchivedChats();
        _allChats = _allChats.where((c) => !archivedIds.contains(c.chatId)).toList();
        _filterChats();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStories() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final myStories = await _supabase.from('ngm_stories').select('*')
          .eq('user_id', userId)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);
      final contacts = await _supabase.from('ngm_contacts').select('contact_user_id').eq('user_id', userId);
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
        if (!storiesByUser.containsKey(uid)) storiesByUser[uid] = [];
        storiesByUser[uid]!.add(story);
      }
      final List<StoryUser> storyUsers = [];
      if (myStories.isNotEmpty) {
        final myUser = await _supabase.from('ngm_users')
            .select('full_name, username, profile_picture_url').eq('user_id', userId).single();
        storyUsers.add(StoryUser(
          userId: userId, userName: 'My Story', userImage: myUser['profile_picture_url'],
          storyCount: myStories.length, lastStoryTime: DateTime.parse(myStories.first['created_at']),
          isViewed: false, stories: myStories,
        ));
      }
      for (var entry in storiesByUser.entries) {
        final userStories = entry.value;
        final userData = userStories.first['ngm_users'];
        final viewedCount = await _supabase.from('ngm_story_views').select('story_id')
            .eq('viewer_id', userId)
            .filter('story_id', 'in', '(${userStories.map((s) => s['story_id']).join(',')})');
        storyUsers.add(StoryUser(
          userId: entry.key,
          userName: userData['full_name'] ?? userData['username'] ?? 'Unknown',
          userImage: userData['profile_picture_url'],
          storyCount: userStories.length,
          lastStoryTime: DateTime.parse(userStories.first['created_at']),
          isViewed: viewedCount.length == userStories.length,
          stories: userStories,
        ));
      }
      setState(() { _stories = storyUsers; });
    } catch (e) { debugPrint('Error loading stories: $e'); }
  }

  Future<void> _loadChats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) { if (mounted) setState(() => _isLoading = false); return; }
      final participantResponse = await _supabase
          .from('ngm_chat_participants')
          .select('chat_id, unread_count, is_muted')
          .eq('user_id', userId).eq('is_active', true);

      final List<ChatItem> chats = [];
      chats.add(ChatItem(
        chatId: 'saved_messages', chatType: ChatType.private,
        name: 'Saved Messages', avatarUrl: null,
        lastMessage: 'Your saved messages', lastMessageTime: DateTime.now(),
        unreadCount: 0, isPinned: true, isMuted: false,
      ));

      for (var participant in participantResponse as List) {
        try {
          final chatId = participant['chat_id'];
          final chatResponse = await _supabase.from('ngm_chats').select('*').eq('chat_id', chatId).maybeSingle();
          if (chatResponse == null) continue;
          final chatType = chatResponse['chat_type'];
          final lastMessage = await _supabase.from('ngm_messages')
              .select('content, created_at').eq('chat_id', chatId).eq('is_deleted', false)
              .order('created_at', ascending: false).limit(1).maybeSingle();
          ChatItem? chatItem;
          if (chatType == 'private' || chatType == 'personal') {
            final otherUserId = chatResponse['user1_id'] == userId ? chatResponse['user2_id'] : chatResponse['user1_id'];
            final userInfo = await _supabase.from('ngm_users')
                .select('full_name, username, profile_picture_url, is_online, last_seen')
                .eq('user_id', otherUserId).maybeSingle();
            if (userInfo == null) continue;
            chatItem = ChatItem(
              chatId: chatId, chatType: ChatType.private,
              name: userInfo['full_name'] ?? userInfo['username'] ?? 'Unknown',
              avatarUrl: userInfo['profile_picture_url'],
              lastMessage: lastMessage?['content'] ?? 'No messages',
              lastMessageTime: lastMessage != null ? DateTime.parse(lastMessage['created_at']) : DateTime.parse(chatResponse['created_at']),
              unreadCount: participant['unread_count'] ?? 0,
              isPinned: _storage.isChatPinned(chatId),
              isMuted: participant['is_muted'] ?? false,
              isOnline: userInfo['is_online'] ?? false,
              lastSeen: userInfo['last_seen'] != null ? DateTime.parse(userInfo['last_seen']) : null,
            );
          } else if (chatType == 'group') {
            final groupInfo = await _supabase.from('ngm_groups').select('group_name, group_picture_url').eq('chat_id', chatId).maybeSingle();
            if (groupInfo == null) continue;
            chatItem = ChatItem(
              chatId: chatId, chatType: ChatType.group,
              name: groupInfo['group_name'] ?? 'Group', avatarUrl: groupInfo['group_picture_url'],
              lastMessage: lastMessage?['content'] ?? 'No messages',
              lastMessageTime: lastMessage != null ? DateTime.parse(lastMessage['created_at']) : DateTime.parse(chatResponse['created_at']),
              unreadCount: participant['unread_count'] ?? 0,
              isPinned: _storage.isChatPinned(chatId), isMuted: participant['is_muted'] ?? false,
            );
          } else if (chatType == 'channel') {
            final channelInfo = await _supabase.from('ngm_channels').select('channel_name, channel_picture_url').eq('chat_id', chatId).maybeSingle();
            if (channelInfo == null) continue;
            chatItem = ChatItem(
              chatId: chatId, chatType: ChatType.channel,
              name: channelInfo['channel_name'] ?? 'Channel', avatarUrl: channelInfo['channel_picture_url'],
              lastMessage: lastMessage?['content'] ?? 'No messages',
              lastMessageTime: lastMessage != null ? DateTime.parse(lastMessage['created_at']) : DateTime.parse(chatResponse['created_at']),
              unreadCount: participant['unread_count'] ?? 0,
              isPinned: _storage.isChatPinned(chatId), isMuted: participant['is_muted'] ?? false,
            );
          }
          if (chatItem != null) chats.add(chatItem);
        } catch (e) { debugPrint('Error: $e'); }
      }

      final archivedIds = _storage.getArchivedChats();
      final activeChats = chats.where((c) => !archivedIds.contains(c.chatId)).toList();
      await _storage.saveChatList(activeChats.map((c) => {
        'chatId': c.chatId, 'chatType': c.chatType.toString(),
        'name': c.name, 'avatarUrl': c.avatarUrl,
        'lastMessage': c.lastMessage,
        'lastMessageTime': c.lastMessageTime.toIso8601String(),
        'unreadCount': c.unreadCount, 'isMuted': c.isMuted,
        'isOnline': c.isOnline ?? false,
        'lastSeen': c.lastSeen?.toIso8601String(),
      }).toList());

      if (mounted) setState(() { _allChats = activeChats; _filterChats(); _isLoading = false; });
    } catch (e) {
      debugPrint('FATAL ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final ch1 = _supabase.channel('chat_participants_updates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update, schema: 'public',
          table: 'ngm_chat_participants',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            final chatId = payload.newRecord['chat_id'];
            final index = _allChats.indexWhere((c) => c.chatId == chatId);
            if (index != -1 && mounted) {
              setState(() { _allChats[index] = _allChats[index].copyWith(unreadCount: payload.newRecord['unread_count'] ?? 0); _filterChats(); });
            }
          },
        ).subscribe();
    _realtimeChannels.add(ch1);

    final ch2 = _supabase.channel('messages_insert_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert, schema: 'public', table: 'ngm_messages',
          callback: (payload) async {
            try {
              final chatId = payload.newRecord['chat_id'];
              final isUserInChat = await _supabase.from('ngm_chat_participants')
                  .select('chat_id').eq('chat_id', chatId).eq('user_id', userId).maybeSingle();
              if (isUserInChat != null) {
                final index = _allChats.indexWhere((c) => c.chatId == chatId);
                if (index != -1 && mounted) {
                  setState(() {
                    _allChats[index] = _allChats[index].copyWith(
                      lastMessage: payload.newRecord['content'] ?? 'Media',
                      lastMessageTime: DateTime.parse(payload.newRecord['created_at']),
                    );
                    _filterChats();
                  });
                }
              }
            } catch (e) { debugPrint('Error: $e'); }
          },
        ).subscribe();
    _realtimeChannels.add(ch2);

    final ch3 = _supabase.channel('new_chats_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert, schema: 'public',
          table: 'ngm_chat_participants',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) { _loadChats(); },
        ).subscribe();
    _realtimeChannels.add(ch3);

    final ch4 = _supabase.channel('users_online_status')
        .onPostgresChanges(
          event: PostgresChangeEvent.update, schema: 'public', table: 'ngm_users',
          callback: (payload) { _loadChats(); },
        ).subscribe();
    _realtimeChannels.add(ch4);
  }

  void _filterChats() {
    List<ChatItem> filtered = _allChats;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((c) =>
        c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        c.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    switch (_selectedFilterIndex) {
      case 0: filtered = _allChats; break;
      case 1: break;
      case 2: filtered = filtered.where((c) => c.unreadCount > 0).toList(); break;
      case 3: filtered = filtered.where((c) => c.chatType == ChatType.group).toList(); break;
      case 4: filtered = filtered.where((c) => c.chatType == ChatType.channel).toList(); break;
    }
    filtered.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });
    setState(() { _filteredChats = filtered; });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) { _searchController.clear(); _searchQuery = ''; _filterChats(); }
    });
  }

  void _toggleSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedChatIds.add(chatId);
        _isSelectionMode = true;
      }
    });
  }

  void _cancelSelection() => setState(() { _selectedChatIds.clear(); _isSelectionMode = false; });

  Future<void> _archiveSelectedChats() async {
    for (final chatId in _selectedChatIds) { await _storage.archiveChat(chatId); }
    final count = _selectedChatIds.length;
    final archived = List<String>.from(_selectedChatIds);
    _cancelSelection();
    _loadChats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count chat${count > 1 ? 's' : ''} archived'),
        action: SnackBarAction(label: 'Undo', onPressed: () async {
          for (final chatId in archived) { await _storage.unarchiveChat(chatId); }
          _loadChats();
        }),
      ));
    }
  }

  void _showMediaSendOptions(ThemeProvider t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16),
            child: Text('Select Contact to Send',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.text1))),
          _buildMediaOption(icon: Icons.camera_alt, title: 'Camera', subtitle: 'Take a photo or video', color: Colors.pink, t: t,
            onTap: () async { Navigator.pop(context); final img = await _imagePicker.pickImage(source: ImageSource.camera); if (img != null) _showContactSelectorForMedia(File(img.path), 'image', t); }),
          _buildMediaOption(icon: Icons.photo_library, title: 'Gallery', subtitle: 'Choose photo', color: Colors.purple, t: t,
            onTap: () async { Navigator.pop(context); final img = await _imagePicker.pickImage(source: ImageSource.gallery); if (img != null) _showContactSelectorForMedia(File(img.path), 'image', t); }),
          _buildMediaOption(icon: Icons.videocam, title: 'Video', subtitle: 'Choose video', color: Colors.red, t: t,
            onTap: () async { Navigator.pop(context); final vid = await _imagePicker.pickVideo(source: ImageSource.gallery); if (vid != null) _showContactSelectorForMedia(File(vid.path), 'video', t); }),
          _buildMediaOption(icon: Icons.insert_drive_file, title: 'Document', subtitle: 'Share files', color: Colors.blue, t: t,
            onTap: () async { Navigator.pop(context); final r = await FilePicker.platform.pickFiles(); if (r != null && r.files.first.path != null) _showContactSelectorForMedia(File(r.files.first.path!), 'file', t); }),
        ]),
      ),
    );
  }

  void _showContactSelectorForMedia(File mediaFile, String mediaType, ThemeProvider t) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollCtrl) => ContactSelectorForMedia(
          mediaFile: mediaFile, mediaType: mediaType, scrollController: scrollCtrl),
      ),
    );
  }

  Widget _buildMediaOption({required IconData icon, required String title, required String subtitle, required Color color, required ThemeProvider t, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: t.text2)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: t.bg,
      extendBody: true,
      appBar: _isSelectionMode ? _buildSelectionAppBar(t) : _buildNormalAppBar(t),
      body: Column(children: [
        if (_selectedFilterIndex == 0) _buildStoriesGrid(t),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: t.brand))
              : _filteredChats.isEmpty && _selectedFilterIndex != 0
                  ? _buildEmptyState(t)
                  : _selectedFilterIndex == 0
                      ? const SizedBox.shrink()
                      : RefreshIndicator(
                          onRefresh: () async { await _loadChats(); await _loadStories(); },
                          color: t.brand, backgroundColor: t.surface,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 120),
                            itemCount: _filteredChats.length,
                            itemBuilder: (_, index) {
                              final chat = _filteredChats[index];
                              if (chat.chatId == 'saved_messages') {
                                return ListTile(
                                  leading: Container(
                                    width: 46, height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [t.brand, const Color(0xFF6B3FC6)]),
                                    ),
                                    child: const Icon(Icons.bookmark, color: Colors.white),
                                  ),
                                  title: Text('Saved Messages', style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
                                  subtitle: Text('Your saved messages', style: TextStyle(color: t.text2, fontSize: 12)),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedMessagesScreen())),
                                );
                              }
                              return _buildChatItem(chat, t);
                            },
                          ),
                        ),
        ),
      ]),
      floatingActionButton: _isSelectionMode ? null : _buildFloatingButtons(t),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(ThemeProvider t) {
    return AppBar(
      elevation: 0,
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      title: _isSearching
          ? TextField(
              controller: _searchController, autofocus: true,
              style: TextStyle(color: t.text1),
              decoration: InputDecoration(hintText: 'Search chats...', hintStyle: TextStyle(color: t.text2), border: InputBorder.none),
              onChanged: (v) => setState(() { _searchQuery = v; _filterChats(); }),
            )
          : Text('Chats', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: t.text1)),
      actions: [
        IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search, color: t.text1), onPressed: _toggleSearch),
        IconButton(icon: Icon(Icons.camera_alt_outlined, color: t.text1), onPressed: () => _showMediaSendOptions(t)),
        PopupMenuButton(
          icon: Icon(Icons.more_vert, color: t.text1),
          color: t.surface2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.border)),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'contacts', child: Row(children: [Icon(Icons.contacts, color: t.accent), const SizedBox(width: 12), Text('Contacts', style: TextStyle(color: t.text1))])),
            PopupMenuItem(value: 'archived', child: Row(children: [Icon(Icons.archive_outlined, color: t.accent), const SizedBox(width: 12), Text('Archived Chats', style: TextStyle(color: t.text1))])),
            PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, color: t.accent), const SizedBox(width: 12), Text('Settings', style: TextStyle(color: t.text1))])),
          ],
          onSelected: (value) {
            switch (value) {
              case 'contacts': Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())).then((_) => _loadChats()); break;
              case 'archived': _showArchivedChats(); break;
              case 'settings': Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); break;
            }
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          color: t.surface,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(25), border: Border.all(color: t.border)),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: t.text1,
              unselectedLabelColor: t.text2,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(color: t.brand.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              onTap: (i) => setState(() { _selectedFilterIndex = i; _filterChats(); }),
              tabs: _filters.map((f) => Tab(text: f)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(ThemeProvider t) {
    return AppBar(
      elevation: 0, backgroundColor: t.surface, surfaceTintColor: Colors.transparent,
      leading: IconButton(icon: Icon(Icons.close, color: t.text1), onPressed: _cancelSelection),
      title: Text('${_selectedChatIds.length} selected', style: TextStyle(color: t.text1)),
      actions: [
        IconButton(icon: Icon(Icons.push_pin, color: t.text1), onPressed: () async {
          for (final chatId in _selectedChatIds) {
            if (_storage.isChatPinned(chatId)) { await _storage.unpinChat(chatId); } else { await _storage.pinChat(chatId); }
          }
          _cancelSelection(); _loadChats();
        }),
        IconButton(icon: Icon(Icons.archive, color: t.text1), onPressed: _archiveSelectedChats),
      ],
    );
  }

  Widget _buildStoriesGrid(ThemeProvider t) {
    if (_stories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Center(child: Column(children: [
          Icon(Icons.auto_stories_outlined, size: 80, color: t.text2.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No stories yet', style: TextStyle(fontSize: 18, color: t.text2)),
          const SizedBox(height: 8),
          Text('Create your first story or view stories from contacts',
            style: TextStyle(fontSize: 14, color: t.text2.withOpacity(0.7)), textAlign: TextAlign.center),
        ])),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8),
        itemCount: _stories.length,
        itemBuilder: (_, index) {
          final story = _stories[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewStoriesScreen(storyUser: story))).then((_) => _loadStories()),
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: !story.isViewed ? LinearGradient(colors: [t.brand, t.accent]) : null,
                  border: Border.all(color: story.isViewed ? t.border : Colors.transparent, width: 3),
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  backgroundColor: t.brand,
                  backgroundImage: story.userImage != null ? NetworkImage(story.userImage!) : null,
                  child: story.userImage == null
                      ? Text(story.userName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24))
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(story.userName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.text1)),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildChatItem(ChatItem chat, ThemeProvider t) {
    final isSelected = _selectedChatIds.contains(chat.chatId);
    final isOnline = _isActuallyOnline(chat);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? t.brand.withOpacity(0.15) : t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSelected ? t.brand : t.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: _isSelectionMode
            ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(chat.chatId), activeColor: t.brand, checkColor: Colors.white)
            : Stack(children: [
                CircleAvatar(
                  backgroundColor: t.brand,
                  backgroundImage: chat.avatarUrl != null ? NetworkImage(chat.avatarUrl!) : null,
                  child: chat.avatarUrl == null
                      ? Text(chat.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                      : null,
                ),
                if (chat.chatType == ChatType.private && isOnline)
                  Positioned(right: 0, bottom: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: t.surface, width: 2)),
                    ),
                  ),
              ]),
        title: Row(children: [
          Expanded(child: Text(chat.name, style: TextStyle(fontWeight: FontWeight.w600, color: t.text1, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (chat.isPinned) Icon(Icons.push_pin, size: 14, color: t.accent),
        ]),
        subtitle: Row(children: [
          Expanded(child: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: chat.unreadCount > 0 ? t.text1 : t.text2,
              fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ))),
          const SizedBox(width: 4),
          if (chat.chatType == ChatType.private && isOnline)
            const Text('● online', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
        ]),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_formatTime(chat.lastMessageTime), style: TextStyle(
              fontSize: 11,
              color: chat.unreadCount > 0 ? t.accent : t.text2,
              fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
            )),
            if (chat.unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(10)),
                child: Text('${chat.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        onTap: () async {
          if (_isSelectionMode) { _toggleSelection(chat.chatId); return; }
          final userId = _supabase.auth.currentUser?.id;
          if (userId == null) return;
          final chatData = await _supabase.from('ngm_chats').select('user1_id, user2_id, chat_type').eq('chat_id', chat.chatId).maybeSingle();
          String? otherUserId;
          if (chatData != null && (chatData['chat_type'] == 'private' || chatData['chat_type'] == 'personal')) {
            otherUserId = chatData['user1_id'] == userId ? chatData['user2_id'] : chatData['user1_id'];
          } else {
            otherUserId = chat.chatId;
          }
          if (otherUserId != null && mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatWindowScreen(chatId: chat.chatId, otherUserId: otherUserId!))).then((_) => _loadChats());
          }
        },
        onLongPress: () { if (!_isSelectionMode) _toggleSelection(chat.chatId); },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }

  void _showArchivedChats() {}

  Widget _buildFloatingButtons(ThemeProvider t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(
          heroTag: 'story_btn',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoryScreen())).then((_) => _loadStories()),
          backgroundColor: t.surface2,
          child: Icon(Icons.add_a_photo, color: t.accent),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'chat_btn',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())).then((_) => _loadChats()),
          backgroundColor: t.brand,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ]),
    );
  }

  Widget _buildEmptyState(ThemeProvider t) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.chat_bubble_outline, size: 80, color: t.text2.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text('No chats yet', style: TextStyle(fontSize: 18, color: t.text2, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Text('Start a new conversation', style: TextStyle(fontSize: 14, color: t.text2.withOpacity(0.7))),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())).then((_) => _loadChats()),
        icon: const Icon(Icons.add),
        label: const Text('Start Chatting'),
        style: ElevatedButton.styleFrom(backgroundColor: t.brand, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
      ),
    ]));
  }
}

// ═══════════════════════════════════════════
// SUPPORT CLASSES
// ═══════════════════════════════════════════
class StoryUser {
  final String userId;
  final String userName;
  final String? userImage;
  final int storyCount;
  final DateTime lastStoryTime;
  final bool isViewed;
  final List<dynamic> stories;
  StoryUser({required this.userId, required this.userName, this.userImage,
    required this.storyCount, required this.lastStoryTime,
    required this.isViewed, required this.stories});
}

class ContactSelectorForMedia extends StatefulWidget {
  final File mediaFile;
  final String mediaType;
  final ScrollController scrollController;
  const ContactSelectorForMedia({super.key, required this.mediaFile, required this.mediaType, required this.scrollController});
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
  void initState() { super.initState(); _loadContactsAndChats(); }
  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _loadContactsAndChats() async {
    try {
      final cachedContacts = _storage.getCachedContacts();
      final cachedChats = _storage.getCachedChatList();
      if (cachedContacts != null) {
        setState(() {
          _contacts = cachedContacts.where((c) => c['isRegistered'] == true).map((c) => ContactItem(
            contactName: c['contactName'] ?? 'Unknown', phoneNumber: c['phoneNumber'] ?? '',
            isRegistered: true, userId: c['userId'], fullName: c['fullName'],
            username: c['username'], profilePictureUrl: c['profilePictureUrl'],
            isOnline: c['isOnline'] ?? false, bio: c['bio'],
          )).toList();
        });
      }
      if (cachedChats != null) {
        setState(() {
          _recentChats = cachedChats.take(5).map((c) => ChatItem(
            chatId: c['chatId'],
            chatType: ChatType.values.firstWhere((e) => e.toString() == c['chatType']),
            name: c['name'], avatarUrl: c['avatarUrl'],
            lastMessage: c['lastMessage'],
            lastMessageTime: DateTime.parse(c['lastMessageTime']),
            unreadCount: c['unreadCount'] ?? 0, isPinned: false, isMuted: c['isMuted'] ?? false,
          )).toList();
          _isLoading = false;
        });
      }
    } catch (e) { debugPrint('Error: $e'); setState(() => _isLoading = false); }
  }

  Future<void> _sendMediaToChat(String chatId, String chatName) async {
    try {
      Navigator.pop(context);
      final t = context.read<ThemeProvider>();
      showDialog(context: context, barrierDismissible: false,
        builder: (_) => Center(child: CircularProgressIndicator(color: t.brand)));
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_${widget.mediaType}';
      await _supabase.storage.from('chat-media').upload(fileName, widget.mediaFile, fileOptions: const FileOptions(upsert: true));
      final mediaUrl = _supabase.storage.from('chat-media').getPublicUrl(fileName);
      await _supabase.from('ngm_messages').insert({
        'chat_id': chatId, 'sender_id': userId,
        'message_type': widget.mediaType, 'content': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to $chatName')));
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    }
  }

  Future<void> _sendMediaToContact(ContactItem contact) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || contact.userId == null) return;
      if (userId == contact.userId) {
        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot send to yourself'))); }
        return;
      }
      final existing = await _supabase.from('ngm_chats').select('chat_id')
          .or('and(user1_id.eq.$userId,user2_id.eq.${contact.userId}),and(user1_id.eq.${contact.userId},user2_id.eq.$userId)')
          .eq('chat_type', 'private').maybeSingle();
      String chatId;
      if (existing != null) {
        chatId = existing['chat_id'];
      } else {
        final chat = await _supabase.from('ngm_chats').insert({
          'chat_type': 'private', 'user1_id': userId, 'user2_id': contact.userId,
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();
        chatId = chat['chat_id'];
        await _supabase.from('ngm_chat_participants').insert([
          {'chat_id': chatId, 'user_id': userId, 'is_active': true, 'is_pinned': false, 'is_muted': false, 'is_archived': false, 'unread_count': 0},
          {'chat_id': chatId, 'user_id': contact.userId, 'is_active': true, 'is_pinned': false, 'is_muted': false, 'is_archived': false, 'unread_count': 0},
        ]);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await _sendMediaToChat(chatId, contact.contactName);
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    }
  }

  List<dynamic> _getFilteredItems() {
    if (_searchQuery.isEmpty) return [..._recentChats, ..._contacts];
    final q = _searchQuery.toLowerCase();
    return [
      ..._recentChats.where((c) => c.name.toLowerCase().contains(q)),
      ..._contacts.where((c) => c.contactName.toLowerCase().contains(q)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final items = _getFilteredItems();
    return Container(
      color: t.bg,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2))),
        Text('Send to...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: t.text1)),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(color: t.text1),
          decoration: InputDecoration(
            hintText: 'Search contacts or chats', hintStyle: TextStyle(color: t.text2),
            prefixIcon: Icon(Icons.search, color: t.brand),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
            filled: true, fillColor: t.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 100,
          decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(12)),
          child: Center(child: widget.mediaType == 'image'
              ? Image.file(widget.mediaFile, fit: BoxFit.cover)
              : widget.mediaType == 'video'
                  ? Icon(Icons.videocam, size: 50, color: t.text2)
                  : Icon(Icons.insert_drive_file, size: 50, color: t.text2)),
        ),
        const SizedBox(height: 16),
        Expanded(child: _isLoading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : items.isEmpty
                ? Center(child: Text('No contacts or chats found', style: TextStyle(color: t.text2)))
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      if (item is ChatItem) {
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: t.brand,
                            backgroundImage: item.avatarUrl != null ? NetworkImage(item.avatarUrl!) : null,
                            child: item.avatarUrl == null ? Text(item.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
                          title: Text(item.name, style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
                          subtitle: Text('Recent chat', style: TextStyle(fontSize: 12, color: t.text2)),
                          onTap: () => _sendMediaToChat(item.chatId, item.name),
                        );
                      } else if (item is ContactItem) {
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: t.brand,
                            backgroundImage: item.profilePictureUrl != null ? NetworkImage(item.profilePictureUrl!) : null,
                            child: item.profilePictureUrl == null ? Text(item.contactName[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
                          title: Text(item.contactName, style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
                          subtitle: Text('@${item.username ?? ''}', style: TextStyle(fontSize: 12, color: t.brand)),
                          onTap: () => _sendMediaToContact(item),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  )),
      ]),
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
  ContactItem({required this.contactName, required this.phoneNumber,
    required this.isRegistered, this.userId, this.fullName, this.username,
    this.profilePictureUrl, this.isOnline = false, this.bio});
}