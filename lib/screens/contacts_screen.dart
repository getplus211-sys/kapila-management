import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_model.dart';
import '../services/local_storage_service.dart';
import 'theme_provider.dart';
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
          userId: c['userId'], fullName: c['fullName'],
          username: c['username'], profilePictureUrl: c['profilePictureUrl'],
          isOnline: c['isOnline'] ?? false, bio: c['bio'],
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
      setState(() { _hasPermission = false; _isLoading = false; });
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text('Please enable contacts permission from Settings.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(onPressed: () { Navigator.pop(context); openAppSettings(); }, child: const Text('Open Settings')),
            ],
          ),
        );
      }
    } else {
      setState(() { _hasPermission = false; _isLoading = false; });
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
          if (clean.isNotEmpty) phoneNumbers.add(clean);
        }
      }
      final registeredUsers = phoneNumbers.isEmpty ? [] : await _supabase
          .from('ngm_users')
          .select('user_id, full_name, username, mobile, profile_picture_url, is_online, bio')
          .filter('mobile', 'in', '(${phoneNumbers.join(',')})');
      final Map<String, Map<String, dynamic>> regMap = {};
      for (final u in registeredUsers) { regMap[u['mobile']] = u; }
      final List<ContactItem> contacts = [];
      for (final c in deviceContacts) {
        for (final p in c.phones) {
          final clean = p.number.replaceAll(RegExp(r'[^\d+]'), '');
          if (clean.isEmpty) continue;
          final user = regMap[clean];
          contacts.add(ContactItem(
            contactName: c.displayName.isNotEmpty ? c.displayName : 'Unknown',
            phoneNumber: clean, isRegistered: user != null,
            userId: user?['user_id'], fullName: user?['full_name'],
            username: user?['username'], profilePictureUrl: user?['profile_picture_url'],
            isOnline: user?['is_online'] ?? false, bio: user?['bio'],
          ));
        }
      }
      contacts.sort((a, b) {
        if (a.isRegistered && !b.isRegistered) return -1;
        if (!a.isRegistered && b.isRegistered) return 1;
        return a.contactName.compareTo(b.contactName);
      });
      await _storage.saveContacts(contacts.map((c) => {
        'contactName': c.contactName, 'phoneNumber': c.phoneNumber,
        'isRegistered': c.isRegistered, 'userId': c.userId,
        'fullName': c.fullName, 'username': c.username,
        'profilePictureUrl': c.profilePictureUrl,
        'isOnline': c.isOnline, 'bio': c.bio,
      }).toList());
      setState(() { _allContacts = contacts; _filteredContacts = contacts; _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        final q = query.toLowerCase();
        _filteredContacts = _allContacts.where((c) =>
          c.contactName.toLowerCase().contains(q) ||
          c.phoneNumber.contains(q) ||
          (c.username ?? '').toLowerCase().contains(q)
        ).toList();
      }
    });
  }

  Future<void> _startChat(ContactItem contact) async {
    if (!contact.isRegistered || contact.userId == null) return;
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return;
    if (me == contact.userId) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot chat with yourself')));
      return;
    }
    try {
      final existingChat = await _supabase
          .from('ngm_chats').select('chat_id, chat_type, user1_id, user2_id')
          .or('and(user1_id.eq.$me,user2_id.eq.${contact.userId}),and(user1_id.eq.${contact.userId},user2_id.eq.$me)')
          .eq('chat_type', 'private').maybeSingle();
      String chatId;
      if (existingChat != null) {
        chatId = existingChat['chat_id'];
      } else {
        final chat = await _supabase.from('ngm_chats').insert({
          'chat_type': 'private', 'user1_id': me, 'user2_id': contact.userId,
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();
        chatId = chat['chat_id'];
        await _supabase.from('ngm_chat_participants').insert([
          {'chat_id': chatId, 'user_id': me,              'is_active': true, 'is_pinned': false, 'is_muted': false, 'is_archived': false, 'unread_count': 0},
          {'chat_id': chatId, 'user_id': contact.userId!, 'is_active': true, 'is_pinned': false, 'is_muted': false, 'is_archived': false, 'unread_count': 0},
        ]);
        await Future.delayed(const Duration(milliseconds: 800));
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatWindowScreen(chatId: chatId, otherUserId: contact.userId!))).then((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      debugPrint('Error starting chat: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _sendInvite(ContactItem contact) async {
    final uri = Uri.parse('sms:${contact.phoneNumber}?body=${Uri.encodeComponent('Join me on Nandigram!')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: t.surface,
        foregroundColor: t.text1,
        surfaceTintColor: Colors.transparent,
        title: Text('Contacts', style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
        iconTheme: IconThemeData(color: t.text1),
        actions: [
          if (_hasPermission)
            IconButton(icon: Icon(Icons.refresh, color: t.text1), onPressed: _loadContacts),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: t.brand))
          : !_hasPermission
              ? _buildPermissionPrompt(t)
              : Column(children: [
                  // ── Top actions ──
                  Container(
                    color: t.surface,
                    child: Column(children: [
                      ListTile(
                        leading: CircleAvatar(backgroundColor: t.brand, child: const Icon(Icons.group_add, color: Colors.white)),
                        title: Text('New Group', style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewGroupScreen())),
                      ),
                      ListTile(
                        leading: CircleAvatar(backgroundColor: t.brand, child: const Icon(Icons.campaign, color: Colors.white)),
                        title: Text('New Channel', style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChannelScreen())),
                      ),
                      Divider(height: 1, color: t.border),
                    ]),
                  ),

                  // ── Search ──
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterContacts,
                      style: TextStyle(color: t.text1),
                      decoration: InputDecoration(
                        hintText: 'Search contacts',
                        hintStyle: TextStyle(color: t.text2),
                        prefixIcon: Icon(Icons.search, color: t.brand),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        filled: true, fillColor: t.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),

                  // ── List ──
                  Expanded(
                    child: _filteredContacts.isEmpty
                        ? Center(child: Text('No contacts found', style: TextStyle(color: t.text2)))
                        : ListView.builder(
                            itemCount: _filteredContacts.length,
                            itemBuilder: (_, i) {
                              final c = _filteredContacts[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: c.isRegistered ? t.brand : t.text2,
                                  backgroundImage: c.profilePictureUrl != null ? NetworkImage(c.profilePictureUrl!) : null,
                                  child: c.profilePictureUrl == null
                                      ? Text(c.contactName[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                      : null,
                                ),
                                title: Text(c.contactName,
                                    style: TextStyle(fontWeight: FontWeight.w600, color: t.text1)),
                                subtitle: Text(
                                  c.isRegistered ? '@${c.username ?? ''}' : c.phoneNumber,
                                  style: TextStyle(color: c.isRegistered ? t.brand : t.text2, fontSize: 13),
                                ),
                                trailing: c.isRegistered
                                    ? IconButton(
                                        icon: Icon(Icons.chat_bubble, color: t.brand),
                                        onPressed: () => _startChat(c))
                                    : TextButton(
                                        onPressed: () => _sendInvite(c),
                                        child: Text('Invite', style: TextStyle(color: t.brand))),
                              );
                            },
                          ),
                  ),
                ]),
    );
  }

  Widget _buildPermissionPrompt(ThemeProvider t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.contacts_outlined, size: 80, color: t.text2),
          const SizedBox(height: 16),
          Text('Contacts Permission Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: t.text1),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Allow access to your contacts to find friends on Nandigram',
              style: TextStyle(fontSize: 14, color: t.text2), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _requestPermissionAndLoadContacts,
            style: ElevatedButton.styleFrom(
              backgroundColor: t.brand, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
            child: const Text('Grant Permission'),
          ),
        ]),
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
    required this.contactName, required this.phoneNumber,
    required this.isRegistered, this.userId, this.fullName,
    this.username, this.profilePictureUrl, this.isOnline = false, this.bio,
  });
}