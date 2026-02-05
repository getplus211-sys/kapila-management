import 'package:flutter/material.dart';

class NewChannelScreen extends StatelessWidget {
  const NewChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Channel")),
      body: const Center(child: Text("New Channel Screen")),
    );
  }
}
