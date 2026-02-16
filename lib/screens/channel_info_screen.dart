import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/error_handler.dart';

class ChannelInfoScreen extends StatefulWidget {
  final String chatId;

  const ChannelInfoScreen({super.key, required this.chatId});

  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _channelInfo;
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  bool _isSubscribed = false;
  bool _isAdmin = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _loadChannelInfo();
  }

  Future<void> _loadChannelInfo() async {
    try {
      // Load channel details
      final channelResponse = await _supabase
          .from('ngm_channels')
          .select()
          .eq('chat_id', widget.chatId)
          .single();

      // Check subscription status
      final subscriptionResponse = await _supabase
          .from('ngm_chat_participants')
          .select('role')
          .eq('chat_id', widget.chatId)
          .eq('user_id', _currentUserId!)
          .eq('is_active', true)
          .maybeSingle();

      if (subscriptionResponse != null) {
        _isSubscribed = true;
        _isAdmin = subscriptionResponse['role'] == 'admin';
      }

      // Load admins
      final adminsResponse = await _supabase
          .from('ngm_chat_participants')
          .select('user_id')
          .eq('chat_id', widget.chatId)
          .eq('role', 'admin')
          .eq('is_active', true);

      final List<Map<String, dynamic>> adminsList = [];
      
      for (var admin in adminsResponse) {
        final userInfo = await _supabase
            .from('ngm_users')
            .select('user_id, full_name, username, profile_picture_url')
            .eq('user_id', admin['user_id'])
            .single();

        adminsList.add(userInfo);
      }

      if (mounted) {
        setState(() {
          _channelInfo = channelResponse;
          _admins = adminsList;
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

  Future<void> _toggleSubscription() async {
    try {
      if (_isSubscribed) {
        // Unsubscribe
        await _supabase
            .from('ngm_chat_participants')
            .update({
              'is_active': false,
              'left_at': DateTime.now().toIso8601String(),
            })
            .eq('chat_id', widget.chatId)
            .eq('user_id', _currentUserId!);

        // Update subscriber count
        await _supabase.rpc('decrement_subscriber_count', params: {
          'channel_chat_id': widget.chatId,
        });

        if (mounted) {
          ErrorHandler.showSuccess(context, 'Unsubscribed from channel');
          Navigator.pop(context);
        }
      } else {
        // Subscribe
        await _supabase.from('ngm_chat_participants').insert({
          'chat_id': widget.chatId,
          'user_id': _currentUserId,
          'role': 'member',
          'joined_at': DateTime.now().toIso8601String(),
          'is_active': true,
          'can_send_messages': false,
        });

        // Update subscriber count
        await _supabase.rpc('increment_subscriber_count', params: {
          'channel_chat_id': widget.chatId,
        });

        if (mounted) {
          setState(() => _isSubscribed = true);
          ErrorHandler.showSuccess(context, 'Subscribed to channel');
        }
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
        title: const Text('Channel Info'),
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _channelInfo == null
              ? const Center(child: Text('Channel not found'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Channel header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: _channelInfo!['channel_picture_url'] != null
                                  ? CachedNetworkImageProvider(
                                      _channelInfo!['channel_picture_url'],
                                    )
                                  : null,
                              backgroundColor: const Color(0xFFFF6F00),
                              child: _channelInfo!['channel_picture_url'] == null
                                  ? const Icon(
                                      Icons.campaign,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _channelInfo!['channel_name'] ?? 'Channel',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${_channelInfo!['subscriber_count'] ?? 0} subscribers',
                            ),
                            if (_channelInfo!['channel_description'] != null &&
                                _channelInfo!['channel_description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                _channelInfo!['channel_description'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _toggleSubscription,
                                icon: Icon(
                                  _isSubscribed ? Icons.notifications_off : Icons.notifications,
                                ),
                                label: Text(
                                  _isSubscribed ? 'Unsubscribe' : 'Subscribe',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isSubscribed
                                      ? Colors.grey
                                      : const Color(0xFFFF6F00),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(thickness: 8),

                      // Invite link
                      if (_channelInfo!['invite_link'] != null && _isSubscribed)
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: const Text('Invite Link'),
                          subtitle: Text(
                            _channelInfo!['invite_link'],
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

                      // Public/Private indicator
                      ListTile(
                        leading: Icon(
                          _channelInfo!['is_public'] == true
                              ? Icons.public
                              : Icons.lock,
                        ),
                        title: Text(
                          _channelInfo!['is_public'] == true
                              ? 'Public Channel'
                              : 'Private Channel',
                        ),
                        subtitle: Text(
                          _channelInfo!['is_public'] == true
                              ? 'Anyone can find and join this channel'
                              : 'Only people with invite link can join',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),

                      const Divider(thickness: 8),

                      // Admins section
                      if (_admins.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Text(
                                'Admins (${_admins.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _admins.length,
                          itemBuilder: (context, index) {
                            final admin = _admins[index];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: admin['profile_picture_url'] != null
                                    ? CachedNetworkImageProvider(
                                        admin['profile_picture_url'],
                                      )
                                    : null,
                                backgroundColor: const Color(0xFFFF6F00),
                                child: admin['profile_picture_url'] == null
                                    ? Text(
                                        (admin['full_name'] ?? 'A')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      )
                                    : null,
                              ),
                              title: Text(
                                admin['full_name'] ?? admin['username'] ?? 'Admin',
                              ),
                              subtitle: admin['username'] != null
                                  ? Text('@${admin['username']}')
                                  : null,
                              trailing: Container(
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
                            );
                          },
                        ),
                        const Divider(thickness: 8),
                      ],

                      // Channel settings (for admins)
                      if (_isAdmin)
                        ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('Channel Settings'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to channel settings
                          },
                        ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}