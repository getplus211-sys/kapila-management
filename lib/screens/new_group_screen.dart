import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import 'chat_window_screen.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _supabase = Supabase.instance.client;
  final _groupNameController = TextEditingController();
  final _groupDescriptionController = TextEditingController();
  
  List<Contact> _contacts = [];
  List<Contact> _selectedContacts = [];
  bool _isLoading = true;
  bool _isCreating = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() => _isLoading = true);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('ngm_contacts')
          .select('''
            *,
            contact:ngm_users!contact_user_id(*)
          ''')
          .eq('user_id', userId)
          .order('contact_name', ascending: true);

      final List<Contact> contacts = [];
      for (var item in response as List) {
        final contact = item['contact'];
        contacts.add(Contact(
          userId: contact['user_id'],
          name: item['contact_name'] ?? contact['full_name'] ?? contact['username'] ?? 'Unknown',
          username: contact['username'],
          profilePictureUrl: contact['profile_picture_url'],
          isOnline: contact['is_online'] ?? false,
        ));
      }

      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ગ્રુપનું નામ આપો')),
      );
      return;
    }

    if (_selectedContacts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ઓછામાં ઓછા 2 સભ્યો પસંદ કરો')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Create chat
      final chat = await _supabase.from('ngm_chats').insert({
        'chat_type': 'group',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      final chatId = chat['chat_id'];

      // Create group
      await _supabase.from('ngm_groups').insert({
        'chat_id': chatId,
        'group_name': _groupNameController.text.trim(),
        'group_description': _groupDescriptionController.text.trim(),
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Add creator as admin
      await _supabase.from('ngm_chat_participants').insert({
        'chat_id': chatId,
        'user_id': userId,
        'role': 'admin',
        'can_send_messages': true,
        'can_add_members': true,
        'can_edit_info': true,
      });

      // Add selected members
      for (var contact in _selectedContacts) {
        await _supabase.from('ngm_chat_participants').insert({
          'chat_id': chatId,
          'user_id': contact.userId,
          'role': 'member',
          'can_send_messages': true,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatWindowScreen(
              chatId: chatId,
              chatName: _groupNameController.text.trim(),
              chatType: ChatType.group,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating group: $e');
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ગ્રુપ બનાવવામાં ભૂલ થઈ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('નવું ગ્રુપ'),
        actions: [
          if (_currentStep == 1)
            TextButton(
              onPressed: _isCreating ? null : _createGroup,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'બનાવો',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentStep,
              children: [
                _buildSelectMembersStep(),
                _buildGroupInfoStep(),
              ],
            ),
    );
  }

  Widget _buildSelectMembersStep() {
  return Scaffold(
    body: Column(
      children: [
        // Selected contacts preview
        if (_selectedContacts.isNotEmpty)
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedContacts.length,
              itemBuilder: (context, index) {
                final contact = _selectedContacts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: contact.profilePictureUrl != null
                                ? NetworkImage(contact.profilePictureUrl!)
                                : null,
                            child: contact.profilePictureUrl == null
                                ? Text(contact.name[0].toUpperCase())
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedContacts.remove(contact);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          contact.name,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Contacts list
        Expanded(
          child: ListView.builder(
            itemCount: _contacts.length,
            itemBuilder: (context, index) {
              final contact = _contacts[index];
              final isSelected = _selectedContacts.contains(contact);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedContacts.add(contact);
                    } else {
                      _selectedContacts.remove(contact);
                    }
                  });
                },
                secondary: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: contact.profilePictureUrl != null
                      ? NetworkImage(contact.profilePictureUrl!)
                      : null,
                  child: contact.profilePictureUrl == null
                      ? Text(contact.name[0].toUpperCase())
                      : null,
                ),
                title: Text(contact.name),
                subtitle:
                    contact.username != null ? Text('@${contact.username}') : null,
              );
            },
          ),
        ),
      ],
    ),

    // ✅ NOW CORRECT PLACE
    bottomNavigationBar: _selectedContacts.isNotEmpty
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep = 1),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('આગળ (${_selectedContacts.length} સભ્યો)'),
            ),
          )
        : null,
  );
}

  Widget _buildGroupInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group picture placeholder
          Center(
            child: GestureDetector(
              onTap: () {
                // TODO: Implement image picker
              },
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                child: const Icon(Icons.camera_alt, size: 40, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Group name
          TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(
              labelText: 'ગ્રુપનું નામ',
              prefixIcon: Icon(Icons.group),
              border: OutlineInputBorder(),
            ),
            maxLength: 50,
          ),
          const SizedBox(height: 16),

          // Group description
          TextField(
            controller: _groupDescriptionController,
            decoration: const InputDecoration(
              labelText: 'ગ્રુપની માહિતી (વૈકલ્પિક)',
              prefixIcon: Icon(Icons.info_outline),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            maxLength: 200,
          ),
          const SizedBox(height: 24),

          // Selected members preview
          const Text(
            'સભ્યો',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedContacts.length,
            itemBuilder: (context, index) {
              final contact = _selectedContacts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: contact.profilePictureUrl != null
                      ? NetworkImage(contact.profilePictureUrl!)
                      : null,
                  child: contact.profilePictureUrl == null
                      ? Text(contact.name[0].toUpperCase())
                      : null,
                ),
                title: Text(contact.name),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedContacts.remove(contact);
                      if (_selectedContacts.isEmpty) {
                        _currentStep = 0;
                      }
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}