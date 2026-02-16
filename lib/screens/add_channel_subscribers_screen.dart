import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_storage_service.dart';

class AddChannelSubscribersScreen extends StatefulWidget {
  final String chatId;
  final String channelName;

  const AddChannelSubscribersScreen({
    super.key,
    required this.chatId,
    required this.channelName,
  });

  @override
  State<AddChannelSubscribersScreen> createState() => _AddChannelSubscribersScreenState();
}

class _AddChannelSubscribersScreenState extends State<AddChannelSubscribersScreen> {
  final _supabase = Supabase.instance.client;
  final _storage = LocalStorageService();
  final _searchController = TextEditingController();
  
  List<ContactItem> _allContacts = [];
  List<ContactItem> _filteredContacts = [];
  List<String> _existingSubscriberIds = [];
  Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isAdding = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final subscribers = await _supabase
          .from('ngm_chat_participants')
          .select('user_id')
          .eq('chat_id', widget.chatId)
          .eq('is_active', true);

      _existingSubscriberIds = subscribers.map((s) => s['user_id'] as String).toList();

      final cached = _storage.getCachedContacts();
      if (cached != null) {
        final contacts = cached
            .where((c) => c['isRegistered'] == true && !_existingSubscriberIds.contains(c['userId']))
            .map((c) => ContactItem(
                  userId: c['userId'],
                  name: c['contactName'] ?? 'Unknown',
                  username: c['username'],
                  profilePictureUrl: c['profilePictureUrl'],
                ))
            .toList();

        setState(() {
          _allContacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
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
          return c.name.toLowerCase().contains(q) ||
              (c.username ?? '').toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _addSubscribers() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      final participants = _selectedUserIds.map((userId) => {
        'chat_id': widget.chatId,
        'user_id': userId,
        'role': 'subscriber',
        'is_active': true,
        'can_send_messages': false,
        'can_add_members': false,
        'can_edit_info': false,
      }).toList();

      await _supabase.from('ngm_chat_participants').insert(participants);

      // Update subscriber count
      final newCount = _existingSubscriberIds.length + _selectedUserIds.length;
      await _supabase
          .from('ngm_channels')
          .update({'subscriber_count': newCount})
          .eq('chat_id', widget.chatId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedUserIds.length} subscriber(s) added')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error adding subscribers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isAdding = false);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Subscribers', style: TextStyle(fontWeight: FontWeight.w600)),
            if (_selectedUserIds.isNotEmpty)
              Text(
                '${_selectedUserIds.length} selected',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: _isAdding ? null : _addSubscribers,
              child: _isAdding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('ADD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFF6F00),
                  child: Icon(Icons.campaign, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channelName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const Text(
                        'Select contacts to add as subscribers',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F00)))
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'All contacts are already subscribers'
                                  : 'No contacts found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final isSelected = _selectedUserIds.contains(contact.userId);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(contact.userId!),
                            activeColor: const Color(0xFFFF6F00),
                            secondary: CircleAvatar(
                              backgroundColor: const Color(0xFFFF6F00),
                              backgroundImage: contact.profilePictureUrl != null
                                  ? NetworkImage(contact.profilePictureUrl!)
                                  : null,
                              child: contact.profilePictureUrl == null
                                  ? Text(
                                      contact.name[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    )
                                  : null,
                            ),
                            title: Text(
                              contact.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '@${contact.username ?? ''}',
                              style: const TextStyle(fontSize: 13, color: Color(0xFFFF6F00)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class ContactItem {
  final String? userId;
  final String name;
  final String? username;
  final String? profilePictureUrl;

  ContactItem({
    this.userId,
    required this.name,
    this.username,
    this.profilePictureUrl,
  });
}