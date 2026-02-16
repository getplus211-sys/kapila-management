import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_model.dart';
import '../services/local_storage_service.dart';
import 'chat_window_screen.dart';
import 'new_group_screen.dart';
import 'new_channel_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final _storage = LocalStorageService();

  List<ContactItem> _allContacts = [];
  List<ContactItem> _filteredContacts = [];

  bool _isLoading = false;
  bool _hasPermission = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCachedContacts();
    _checkPermissionAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCachedContacts() {
    final cached = _storage.getCachedContacts();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _allContacts = cached.map((c) => ContactItem(
          contactName: c['contactName'] ?? 'Unknown',
          phoneNumber: c['phoneNumber'] ?? '',
          isRegistered: c['isRegistered'] ?? false,
          userId: c['userId'],
          fullName: c['fullName'],
          username: c['username'],
          profilePictureUrl: c['profilePictureUrl'],
          isOnline: c['isOnline'] ?? false,
          bio: c['bio'],
        )).toList();
        _filteredContacts = _allContacts;
      });
    }
  }

  Future<void> _checkPermissionAndLoad() async {
    final status = await Permission.contacts.status;
    
    if (status.isGranted) {
      setState(() => _hasPermission = true);
      await _loadContacts();
    } else {
      setState(() => _hasPermission = false);
    }
  }

  Future<void> _requestPermissionAndLoadContacts() async {
    setState(() => _isLoading = true);

    final status = await Permission.contacts.request();
    
    if (status.isGranted) {
      setState(() => _hasPermission = true);
      await _loadContacts();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text('Please enable contacts permission from Settings to view your contacts.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      setState(() => _isLoading = true);

      final deviceContacts = await FlutterContacts.getContacts(withProperties: true);

      final List<String> phoneNumbers = [];

      for (final c in deviceContacts) {
        for (final p in c.phones) {
          final clean = p.number.replaceAll(RegExp(r'[^\d+]'), '');
          if (clean.isNotEmpty) {
            phoneNumbers.add(clean);
          }
        }
      }

      final registeredUsers = phoneNumbers.isEmpty
          ? []
          : await _supabase
              .from('ngm_users')
              .select('user_id, full_name, username, mobile, profile_picture_url, is_online, bio')
              .filter('mobile', 'in', '(${phoneNumbers.join(',')})');

      final Map<String, Map<String, dynamic>> regMap = {};
      for (final u in registeredUsers) {
        regMap[u['mobile']] = u;
      }

      final List<ContactItem> contacts = [];

      for (final c in deviceContacts) {
        for (final p in c.phones) {
          final clean = p.number.replaceAll(RegExp(r'[^\d+]'), '');
          if (clean.isEmpty) continue;

          final user = regMap[clean];

          contacts.add(
            ContactItem(
              contactName: c.displayName.isNotEmpty ? c.displayName : 'Unknown',
              phoneNumber: clean,
              isRegistered: user != null,
              userId: user?['user_id'],
              fullName: user?['full_name'],
              username: user?['username'],
              profilePictureUrl: user?['profile_picture_url'],
              isOnline: user?['is_online'] ?? false,
              bio: user?['bio'],
            ),
          );
        }
      }

      contacts.sort((a, b) {
        if (a.isRegistered && !b.isRegistered) return -1;
        if (!a.isRegistered && b.isRegistered) return 1;
        return a.contactName.compareTo(b.contactName);
      });

      await _storage.saveContacts(contacts.map((c) => {
        'contactName': c.contactName,
        'phoneNumber': c.phoneNumber,
        'isRegistered': c.isRegistered,
        'userId': c.userId,
        'fullName': c.fullName,
        'username': c.username,
        'profilePictureUrl': c.profilePictureUrl,
        'isOnline': c.isOnline,
        'bio': c.bio,
      }).toList());

      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
     
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        final q = query.toLowerCase();
        _filteredContacts = _allContacts.where((c) {
          return c.contactName.toLowerCase().contains(q) ||
              c.phoneNumber.contains(q) ||
              (c.username ?? '').toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  // ✅ FIXED: Better chat creation with self-chat prevention and proper sync
  Future<void> _startChat(ContactItem contact) async {
    if (!contact.isRegistered || contact.userId == null) return;

    final me = _supabase.auth.currentUser?.id;
    if (me == null) return;

    // ✅ Prevent self-chat
    if (me == contact.userId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot chat with yourself')),
        );
      }
      return;
    }

    try {
      debugPrint('\n═══════════════════════════════════════');
      debugPrint('🔍 START: _startChat()');
      debugPrint('═══════════════════════════════════════');
      debugPrint('👤 My ID: $me');
      debugPrint('👥 Contact ID: ${contact.userId}');
      
      // ✅ CRITICAL: Check for existing chat properly with chat_type filter
      debugPrint('\n📍 Checking for existing chat...');
      
      final existingChat = await _supabase
          .from('ngm_chats')
          .select('chat_id, chat_type, user1_id, user2_id')
          .or('and(user1_id.eq.$me,user2_id.eq.${contact.userId}),and(user1_id.eq.${contact.userId},user2_id.eq.$me)')
          .eq('chat_type', 'private')
          .maybeSingle();

      String chatId;

      if (existingChat != null) {
        // ✅ Chat already exists - USE IT!
        chatId = existingChat['chat_id'];
        debugPrint('✅ Existing chat found: $chatId');
        debugPrint('   User1: ${existingChat['user1_id']}');
        debugPrint('   User2: ${existingChat['user2_id']}');
      } else {
        // ✅ Chat doesn't exist - CREATE NEW
        debugPrint('⚠️ No existing chat found - creating new...');
        
        final chat = await _supabase
            .from('ngm_chats')
            .insert({
              'chat_type': 'private',
              'user1_id': me,
              'user2_id': contact.userId,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        chatId = chat['chat_id'];
        debugPrint('✅ New chat created: $chatId');

        // ✅ Add participants
        await _supabase.from('ngm_chat_participants').insert([
          {
            'chat_id': chatId,
            'user_id': me,
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
        
        debugPrint('✅ Participants added');
        
        // ✅ IMPORTANT: Wait for database sync and realtime propagation
        await Future.delayed(const Duration(milliseconds: 800));
        debugPrint('✅ Sync delay completed');
      }

      debugPrint('\n📱 Opening chat window...');
      debugPrint('Chat ID: $chatId');
      debugPrint('═══════════════════════════════════════\n');

      if (!mounted) return;

      // ✅ Navigate to chat and close contact screen when returning
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatWindowScreen(
            chatId: chatId,
            otherUserId: contact.userId!,
          ),
        ),
      ).then((_) {
        // ✅ When coming back from chat, close contact screen
        // This will trigger ChatListScreen to refresh via its .then() callback
        if (mounted) {
          debugPrint('🔄 Returning from chat - closing contact screen...');
          Navigator.pop(context); // Close ContactsScreen
        }
      });
    } catch (e) {
      debugPrint('❌ Error starting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sendInvite(ContactItem contact) async {
    final uri = Uri.parse(
        'sms:${contact.phoneNumber}?body=${Uri.encodeComponent('Join me on Nandigram!')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
        title: const Text('Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (_hasPermission)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadContacts,
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F00)))
          : !_hasPermission
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.contacts_outlined, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Contacts Permission Required',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Allow access to your contacts to find friends on Nandigram',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _requestPermissionAndLoadContacts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6F00),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text('Grant Permission'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      color: Colors.grey[50],
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFF6F00),
                              child: Icon(Icons.group_add, color: Colors.white),
                            ),
                            title: const Text('New Group', style: TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NewGroupScreen()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFF6F00),
                              child: Icon(Icons.campaign, color: Colors.white),
                            ),
                            title: const Text('New Channel', style: TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NewChannelScreen()),
                              );
                            },
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterContacts,
                        decoration: InputDecoration(
                          hintText: 'Search contacts',
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
                    ),

                    Expanded(
                      child: _filteredContacts.isEmpty
                          ? const Center(child: Text('No contacts found'))
                          : ListView.builder(
                              itemCount: _filteredContacts.length,
                              itemBuilder: (_, i) {
                                final c = _filteredContacts[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: c.isRegistered ? const Color(0xFFFF6F00) : Colors.grey,
                                    backgroundImage: c.profilePictureUrl != null 
                                        ? NetworkImage(c.profilePictureUrl!) 
                                        : null,
                                    child: c.profilePictureUrl == null
                                        ? Text(
                                            c.contactName[0].toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    c.contactName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    c.isRegistered ? '@${c.username ?? ''}' : c.phoneNumber,
                                    style: TextStyle(
                                      color: c.isRegistered ? const Color(0xFFFF6F00) : Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: c.isRegistered
                                      ? IconButton(
                                          icon: const Icon(Icons.chat_bubble, color: Color(0xFFFF6F00)),
                                          onPressed: () => _startChat(c),
                                        )
                                      : TextButton(
                                          onPressed: () => _sendInvite(c),
                                          child: const Text('Invite', style: TextStyle(color: Color(0xFFFF6F00))),
                                        ),
                                );
                              },
                            ),
                    )
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