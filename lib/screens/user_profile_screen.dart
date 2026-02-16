import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/error_handler.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkBlockStatus();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _supabase
          .from('ngm_users')
          .select()
          .eq('user_id', widget.userId)
          .single();

      if (mounted) {
        setState(() {
          _userInfo = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(
          context,
          ErrorHandler.handleError(e),
        );
      }
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('ngm_blocked_users')
          .select()
          .eq('user_id', userId)
          .eq('blocked_user_id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() => _isBlocked = response != null);
      }
    } catch (e) {
      debugPrint('Error checking block status: $e');
    }
  }

  Future<void> _blockUser() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      if (_isBlocked) {
        // Unblock
        await _supabase
            .from('ngm_blocked_users')
            .delete()
            .eq('user_id', userId)
            .eq('blocked_user_id', widget.userId);
      } else {
        // Block
        await _supabase.from('ngm_blocked_users').insert({
          'user_id': userId,
          'blocked_user_id': widget.userId,
          'reason': 'Blocked by user',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      setState(() => _isBlocked = !_isBlocked);
      
      if (mounted) {
        ErrorHandler.showSuccess(
          context,
          _isBlocked ? 'User blocked' : 'User unblocked',
        );
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
        title: const Text('Profile'),
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text(_isBlocked ? 'Unblock User' : 'Block User'),
                onTap: _blockUser,
              ),
              const PopupMenuItem(
                child: Text('Report User'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userInfo == null
              ? const Center(child: Text('User not found'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _userInfo!['profile_picture_url'] != null
                            ? CachedNetworkImageProvider(
                                _userInfo!['profile_picture_url'],
                              )
                            : null,
                        backgroundColor: const Color(0xFFFF6F00),
                        child: _userInfo!['profile_picture_url'] == null
                            ? Text(
                                (_userInfo!['full_name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userInfo!['full_name'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_userInfo!['username'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '@${_userInfo!['username']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _userInfo!['is_online'] == true
                              ? Colors.green
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userInfo!['is_online'] == true ? 'Online' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (_userInfo!['bio'] != null &&
                          _userInfo!['bio'].toString().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _userInfo!['bio'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: Text(_userInfo!['email'] ?? 'Not provided'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: const Text('Mobile'),
                        subtitle: Text(_userInfo!['mobile'] ?? 'Not provided'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.cake),
                        title: const Text('Date of Birth'),
                        subtitle: Text(
                          _userInfo!['date_of_birth'] != null
                              ? _userInfo!['date_of_birth'].toString()
                              : 'Not provided',
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${_userInfo!['posts_count'] ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text('Posts'),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${_userInfo!['followers_count'] ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text('Followers'),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${_userInfo!['following_count'] ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text('Following'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}