import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkIfBlocked();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _supabase
          .from('ngm_users')
          .select('*')
          .eq('user_id', widget.userId)
          .single();

      if (mounted) {
        setState(() {
          _userProfile = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfBlocked() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await _supabase
          .from('ngm_blocked_users')
          .select()
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isBlocked = response != null;
        });
      }
    } catch (e) {
      debugPrint('Error checking block status: $e');
    }
  }

  String _getOnlineStatus() {
    if (_userProfile == null) return 'offline';
    
    final isOnline = _userProfile!['is_online'] ?? false;
    if (isOnline) return 'online';
    
    final lastSeen = _userProfile!['last_seen'];
    if (lastSeen != null) {
      final lastSeenDate = DateTime.parse(lastSeen);
      final diff = DateTime.now().difference(lastSeenDate);
      
      if (diff.inMinutes < 1) return 'last seen just now';
      if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
      if (diff.inDays < 7) return 'last seen ${diff.inDays}d ago';
      return 'last seen recently';
    }
    return 'offline';
  }

  Future<void> _toggleBlock() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      if (_isBlocked) {
        // Unblock user
        await _supabase
            .from('ngm_blocked_users')
            .delete()
            .eq('user_id', currentUserId)
            .eq('blocked_user_id', widget.userId);

        setState(() => _isBlocked = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User unblocked')),
          );
        }
      } else {
        // Block user
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block User'),
            content: Text('Are you sure you want to block ${_userProfile!['full_name'] ?? _userProfile!['username']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Block'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _supabase.from('ngm_blocked_users').insert({
            'user_id': currentUserId,
            'blocked_user_id': widget.userId,
            'reason': 'User blocked from profile',
            'created_at': DateTime.now().toIso8601String(),
          });

          setState(() => _isBlocked = true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User blocked successfully')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error toggling block: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _reportUser() async {
    final reasons = [
      'Spam',
      'Harassment',
      'Inappropriate content',
      'Fake account',
      'Other',
    ];

    String? selectedReason;
    final TextEditingController detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a reason:'),
                ...reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) => setDialogState(() => selectedReason = value),
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedReason != null) {
      try {
        final userId = _supabase.auth.currentUser?.id;
        await _supabase.from('ngm_user_reports').insert({
          'reporter_user_id': userId,
          'reported_user_id': widget.userId,
          'report_reason': selectedReason,
          'report_details': detailsController.text,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User reported. Thank you for helping keep Nandigram safe.')),
          );
        }
      } catch (e) {
        debugPrint('Error reporting user: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F00)))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: const Color(0xFFFF6F00),
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage: _userProfile!['profile_picture_url'] != null
                                ? NetworkImage(_userProfile!['profile_picture_url'])
                                : null,
                            child: _userProfile!['profile_picture_url'] == null
                                ? Text(
                                    (_userProfile!['full_name'] ?? _userProfile!['username'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 40, color: Color(0xFFFF6F00), fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        _userProfile!['full_name'] ?? _userProfile!['username'] ?? 'Unknown User',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '@${_userProfile!['username'] ?? 'unknown'}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _userProfile!['is_online'] == true ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getOnlineStatus(),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      if (_userProfile!['bio'] != null && _userProfile!['bio'].toString().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _userProfile!['bio'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.phone, color: Color(0xFFFF6F00)),
                        title: const Text('Phone'),
                        subtitle: Text(_userProfile!['phone_number'] ?? 'Not available'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.email, color: Color(0xFFFF6F00)),
                        title: const Text('Email'),
                        subtitle: Text(_userProfile!['email'] ?? 'Not available'),
                      ),
                      if (_userProfile!['location'] != null)
                        ListTile(
                          leading: const Icon(Icons.location_on, color: Color(0xFFFF6F00)),
                          title: const Text('Location'),
                          subtitle: Text(_userProfile!['location']),
                        ),
                      const Divider(),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _toggleBlock,
                                icon: Icon(_isBlocked ? Icons.check_circle : Icons.block),
                                label: Text(_isBlocked ? 'Unblock User' : 'Block User'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isBlocked ? Colors.green : Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _reportUser,
                                icon: const Icon(Icons.report, color: Colors.red),
                                label: const Text('Report User', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}