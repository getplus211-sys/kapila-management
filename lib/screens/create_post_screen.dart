import 'package:flutter/material.dart';

/// Create Post Screen
/// This is a placeholder screen - you should implement the actual post creation functionality
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  
  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
          ),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implement post creation
              if (_contentController.text.trim().isNotEmpty) {
                print('Creating post: ${_contentController.text}');
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Post',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: null,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image_outlined, color: Colors.grey.shade600),
                  onPressed: () {
                    // TODO: Implement image picker
                    print('Open image picker');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.video_library_outlined, color: Colors.grey.shade600),
                  onPressed: () {
                    // TODO: Implement video picker
                    print('Open video picker');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.location_on_outlined, color: Colors.grey.shade600),
                  onPressed: () {
                    // TODO: Implement location picker
                    print('Add location');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}