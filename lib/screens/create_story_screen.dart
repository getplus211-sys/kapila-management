import 'package:flutter/material.dart';

class CreateStoryScreen extends StatelessWidget {
  const CreateStoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Story")),
      body: const Center(child: Text("Create Story Screen")),
    );
  }
}
