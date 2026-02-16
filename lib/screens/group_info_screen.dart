import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/error_handler.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;

  const GroupInfoScreen({super.key, required this.chatId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _groupInfo;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    try {
      // Load group details
      final groupResponse = await _supabase
          .from('ngm_groups')
          .select()
          .eq('chat_id', widget.chatId)
          .single();

      // Load members
      final membersResponse = await _supabase
          .from('ngm_chat_participants')
          .select('''
            user_id,
            role,
            joined_at,
            can_send_messages,
            can_add_members,
            can_edit_info
          ''')
          .eq('chat_id', widget.chatId)
          .eq('is_active', true)
          .order('joined_at', ascending: true);

      // Get user details for each member
      final List<Map<String, dynamic>> membersList = [];
      
      for (var participant in membersResponse) {
        final userInfo = await _supabase
            .from('ngm_users')
            .select('user_id, full_name, username, profile_picture_url, is_online')
            .eq('user_id', participant['user_id'])
            .single();

        membersList.add({
          ...participant,
          'full_name': userInfo['full_name'],
          'username': userInfo['username'],
          'profile_picture_url': userInfo['profile_picture_url'],
          'is_online': userInfo['is_online'],
        });

        // Check if current user is admin
        if (participant['user_id'] == _currentUserId && 
            participant['role'] == 'admin') {
          _isAdmin = true;
        }
      }

      if (mounted) {
        setState(() {
          _groupInfo = groupResponse;
          _members = membersList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    }
  }

  Future<void> _exitGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Group'),
        content: const Text('Are you sure you want to exit this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _supabase
          .from('ngm_chat_participants')
          .update({
            'is_active': false,
            'left_at': DateTime.now().toIso8601String(),
          })
          .eq('chat_id', widget.chatId)
          .eq('user_id', _currentUserId!);

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Left the group');
        Navigator.pop(context);
        Navigator.pop(context); // Go back to chat list
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    }
  }

  Future<void> _removeMember(String userId) async {
    if (!_isAdmin) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _supabase
          .from('ngm_chat_participants')
          .update({
            'is_active': false,
            'left_at': DateTime.now().toIso8601String(),
          })
          .eq('chat_id', widget.chatId)
          .eq('user_id', userId);

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Member removed');
        await _loadGroupInfo();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    }
  }

  Future<void> _makeAdmin(String userId) async {
    if (!_isAdmin) return;

    try {
      await _supabase
          .from('ngm_chat_participants')
          .update({
            'role': 'admin',
            'can_send_messages': true,
            'can_add_members': true,
            'can_edit_info': true,
          })
          .eq('chat_id', widget.chatId)
          .eq('user_id', userId);

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Member promoted to admin');
        await _loadGroupInfo();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupInfo == null
              ? const Center(child: Text('Group not found'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Group header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: _groupInfo!['group_picture_url'] != null
                                  ? CachedNetworkImageProvider(
                                      _groupInfo!['group_picture_url'],
                                    )
                                  : null,
                              backgroundColor: const Color(0xFFFF6F00),
                              child: _groupInfo!['group_picture_url'] == null
                                  ? const Icon(
                                      Icons.group,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _groupInfo!['group_name'] ?? 'Group',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('${_members.length} members'),
                            if (_groupInfo!['group_description'] != null &&
                                _groupInfo!['group_description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                _groupInfo!['group_description'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(thickness: 8),

                      // Group settings
                      if (_isAdmin) ...[
                        ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('Group Settings'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to group settings
                          },
                        ),
                        const Divider(),
                      ],

                      // Invite link
                      if (_groupInfo!['invite_link'] != null)
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: const Text('Invite Link'),
                          subtitle: Text(
                            _groupInfo!['invite_link'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.copy),
                          onTap: () {
                            // TODO: Copy invite link
                            ErrorHandler.showSuccess(
                              context,
                              'Link copied to clipboard',
                            );
                          },
                        ),
                      const Divider(thickness: 8),

                      // Members section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Text(
                              '${_members.length} Members',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Members list
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final isCurrentUser = member['user_id'] == _currentUserId;
                          final isMemberAdmin = member['role'] == 'admin';

                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundImage: member['profile_picture_url'] != null
                                      ? CachedNetworkImageProvider(
                                          member['profile_picture_url'],
                                        )
                                      : null,
                                  backgroundColor: const Color(0xFFFF6F00),
                                  child: member['profile_picture_url'] == null
                                      ? Text(
                                          (member['full_name'] ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white),
                                        )
                                      : null,
                                ),
                                if (member['is_online'] == true)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    member['full_name'] ?? member['username'] ?? 'User',
                                  ),
                                ),
                                if (isMemberAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6F00),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Admin',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              member['username'] != null ? '@${member['username']}' : '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: _isAdmin && !isCurrentUser
                                ? PopupMenuButton(
                                    itemBuilder: (context) => [
                                      if (!isMemberAdmin)
                                        PopupMenuItem(
                                          child: const Text('Make Admin'),
                                          onTap: () => _makeAdmin(member['user_id']),
                                        ),
                                      PopupMenuItem(
                                        child: const Text(
                                          'Remove',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onTap: () => _removeMember(member['user_id']),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),

                      const Divider(thickness: 8),

                      // Exit group
                      ListTile(
                        leading: const Icon(Icons.exit_to_app, color: Colors.red),
                        title: const Text(
                          'Exit Group',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: _exitGroup,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}