import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _captionController = TextEditingController();
  
  File? _selectedMedia;
  bool _isVideo = false;
  bool _isPosting = false;
  String _storyType = 'text'; // 'text', 'photo', 'video'
  Color _textBgColor = const Color(0xFFFF6F00);
  final List<Color> _bgColors = [
    const Color(0xFFFF6F00),
    Colors.blue,
    Colors.purple,
    Colors.green,
    Colors.red,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedMedia = File(image.path);
        _isVideo = false;
        _storyType = 'photo';
      });
    }
  }

  Future<void> _takePhoto() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedMedia = File(image.path);
        _isVideo = false;
        _storyType = 'photo';
      });
    }
  }

  Future<void> _pickVideo() async {
    final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedMedia = File(video.path);
        _isVideo = true;
        _storyType = 'video';
      });
    }
  }

  Future<void> _postStory() async {
    if (_storyType == 'text' && _captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    if (_storyType != 'text' && _selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select media')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      String? mediaUrl;

      if (_storyType != 'text' && _selectedMedia != null) {
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}${_isVideo ? '.mp4' : '.jpg'}';
        
        await _supabase.storage.from('stories').upload(
          fileName,
          _selectedMedia!,
          fileOptions: const FileOptions(upsert: true),
        );

        mediaUrl = _supabase.storage.from('stories').getPublicUrl(fileName);
      }

      await _supabase.from('ngm_stories').insert({
        'user_id': userId,
        'media_url': mediaUrl ?? '',
        'media_type': _storyType,
        'caption': _captionController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story posted successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error posting story: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _storyType == 'text' ? _textBgColor : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Create Story'),
        actions: [
          if (_storyType == 'text' || _selectedMedia != null)
            TextButton(
              onPressed: _isPosting ? null : _postStory,
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'POST',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Content Area
          if (_storyType == 'text')
            _buildTextStoryView()
          else if (_selectedMedia != null)
            _buildMediaStoryView()
          else
            _buildInitialView(),

          // Bottom Options Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo, size: 80, color: Colors.white54),
          const SizedBox(height: 24),
          const Text(
            'Share a moment',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an option below',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTextStoryView() {
    return Stack(
      children: [
        // Background Color Selector
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: _bgColors.map((color) {
              return GestureDetector(
                onTap: () => setState(() => _textBgColor = color),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _textBgColor == color ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Text Input
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _captionController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'Type something...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 28),
                border: InputBorder.none,
              ),
              textAlign: TextAlign.center,
              maxLines: null,
              autofocus: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaStoryView() {
    return Stack(
      children: [
        // Media Preview
        Center(
          child: _isVideo
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.videocam, size: 100, color: Colors.white54),
                      ),
                    ),
                    const Icon(Icons.play_circle_outline, size: 80, color: Colors.white),
                  ],
                )
              : Image.file(_selectedMedia!, fit: BoxFit.contain),
        ),

        // Caption Input
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
            child: TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
            ),
          ),
        ),

        // Change Media Button
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            onPressed: () => setState(() {
              _selectedMedia = null;
              _storyType = 'text';
            }),
            icon: const Icon(Icons.close, color: Colors.white, size: 32),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomButton(
            Icons.text_fields,
            'Text',
            () {
              setState(() {
                _storyType = 'text';
                _selectedMedia = null;
              });
            },
            isActive: _storyType == 'text',
          ),
          _buildBottomButton(
            Icons.camera_alt,
            'Camera',
            _takePhoto,
            isActive: false,
          ),
          _buildBottomButton(
            Icons.photo_library,
            'Photo',
            _pickImage,
            isActive: _storyType == 'photo',
          ),
          _buildBottomButton(
            Icons.videocam,
            'Video',
            _pickVideo,
            isActive: _storyType == 'video',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF6F00) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}