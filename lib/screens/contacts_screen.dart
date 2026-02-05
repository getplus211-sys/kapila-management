import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_model.dart';
import 'chat_window_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<ContactItem> _allContacts = [];
  List<ContactItem> _filteredContacts = [];

  bool _isLoading = true;
  bool _hasPermission = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoadContacts() async {
    setState(() => _isLoading = true);

    final status = await Permission.contacts.request();
    if (status.isGranted) {
      _hasPermission = true;
      await _loadContacts();
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      final deviceContacts =
          await FlutterContacts.getContacts(withProperties: true);

      final List<String> phoneNumbers = [];

      for (final c in deviceContacts) {
        for (final p in c.phones) {
          final clean =
              p.number.replaceAll(RegExp(r'[^\d+]'), '');
          if (clean.isNotEmpty) {
            phoneNumbers.add(clean);
          }
        }
      }

      final registeredUsers = phoneNumbers.isEmpty
          ? []
          : await _supabase
              .from('ngm_users')
              .select(
                  'user_id, full_name, username, mobile, profile_picture_url, is_online, bio')
              .filter('mobile', 'in', '(${phoneNumbers.join(',')})');

      final Map<String, Map<String, dynamic>> regMap = {};
      for (final u in registeredUsers) {
        regMap[u['mobile']] = u;
      }

      final List<ContactItem> contacts = [];

      for (final c in deviceContacts) {
        for (final p in c.phones) {
          final clean =
              p.number.replaceAll(RegExp(r'[^\d+]'), '');
          if (clean.isEmpty) continue;

          final user = regMap[clean];

          contacts.add(
            ContactItem(
              contactName: c.displayName.isNotEmpty
                  ? c.displayName
                  : 'Unknown',
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

      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  Future<void> _startChat(ContactItem contact) async {
    if (!contact.isRegistered || contact.userId == null) return;

    final me = _supabase.auth.currentUser?.id;
    if (me == null) return;

    final existing = await _supabase
        .from('ngm_chats')
        .select('chat_id')
        .or(
            'and(user1_id.eq.$me,user2_id.eq.${contact.userId}),and(user1_id.eq.${contact.userId},user2_id.eq.$me)')
        .limit(1);

    String chatId;

    if (existing.isNotEmpty) {
      chatId = existing.first['chat_id'];
    } else {
      final chat = await _supabase
          .from('ngm_chats')
          .insert({
            'chat_type': 'private',
            'user1_id': me,
            'user2_id': contact.userId,
          })
          .select()
          .single();

      chatId = chat['chat_id'];
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatWindowScreen(
          chatId: chatId,
          chatName:
              contact.fullName ?? contact.username ?? contact.contactName,
          chatType: ChatType.private,
          otherUserId: contact.userId!,
        ),
      ),
    );
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
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? const Center(child: Text('Permission required'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterContacts,
                        decoration: const InputDecoration(
                          hintText: 'Search contacts',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (_, i) {
                          final c = _filteredContacts[i];
                          return ListTile(
                            title: Text(c.contactName),
                            subtitle: Text(c.isRegistered
                                ? '@${c.username ?? ''}'
                                : c.phoneNumber),
                            trailing: c.isRegistered
                                ? IconButton(
                                    icon: const Icon(Icons.chat),
                                    onPressed: () => _startChat(c),
                                  )
                                : TextButton(
                                    onPressed: () => _sendInvite(c),
                                    child: const Text('Invite'),
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
