import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class NewChannelScreen extends StatefulWidget {
  const NewChannelScreen({super.key});

  @override
  State<NewChannelScreen> createState() => _NewChannelScreenState();
}

class _NewChannelScreenState extends State<NewChannelScreen> {
  final _supabase = Supabase.instance.client;
  final _channelNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  
  File? _selectedImage;
  bool _isPublic = true;
  bool _isCreating = false;

  @override
  void dispose() {
    _channelNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _createChannel() async {
    final channelName = _channelNameController.text.trim();
    if (channelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter channel name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        final fileName = 'channel_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await _supabase.storage.from('channel-pictures').upload(
          fileName,
          _selectedImage!,
          fileOptions: const FileOptions(upsert: true),
        );

        imageUrl = _supabase.storage.from('channel-pictures').getPublicUrl(fileName);
      }

      // Create chat
      final chat = await _supabase.from('ngm_chats').insert({
        'chat_type': 'channel',
      }).select().single();

      final chatId = chat['chat_id'];

      // Generate invite link
      final inviteLink = 'nandigram.app/c/${chatId.substring(0, 8)}';

      // Create channel
      await _supabase.from('ngm_channels').insert({
        'chat_id': chatId,
        'channel_name': channelName,
        'channel_description': _descriptionController.text.trim(),
        'channel_picture_url': imageUrl,
        'created_by': userId,
        'is_public': _isPublic,
        'invite_link': inviteLink,
        'subscriber_count': 1,
      });

      // Add creator as admin
      await _supabase.from('ngm_chat_participants').insert({
        'chat_id': chatId,
        'user_id': userId,
        'role': 'admin',
        'is_active': true,
        'can_send_messages': true,
        'can_add_members': true,
        'can_edit_info': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Channel created successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error creating channel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isCreating = false);
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
        title: const Text('New Channel', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createChannel,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Create', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel Image
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                  child: _selectedImage == null
                      ? const Icon(Icons.campaign, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate, color: Color(0xFFFF6F00)),
                label: const Text('Add Channel Photo', style: TextStyle(color: Color(0xFFFF6F00))),
              ),
            ),
            const SizedBox(height: 24),

            // Channel Name
            const Text('Channel Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _channelNameController,
              decoration: InputDecoration(
                hintText: 'Enter channel name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 16),

            // Description
            const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'What is this channel about?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 24),

            // Public/Private Toggle
            const Text('Channel Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                title: Text(_isPublic ? 'Public Channel' : 'Private Channel'),
                subtitle: Text(
                  _isPublic 
                      ? 'Anyone can find and subscribe to this channel'
                      : 'Only people with invite link can subscribe',
                  style: const TextStyle(fontSize: 12),
                ),
                activeColor: const Color(0xFFFF6F00),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(height: 24),

            // Info Cards
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Channels are for broadcasting messages to unlimited subscribers',
                      style: TextStyle(color: Colors.blue[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only admins can post in channels. Subscribers can view and react to posts.',
                      style: TextStyle(color: Colors.orange[700], fontSize: 13),
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