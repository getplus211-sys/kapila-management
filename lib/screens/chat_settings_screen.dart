import 'package:flutter/material.dart';

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Settings')),
      body: ListView(
        children: const [
          SwitchListTile(
            title: Text('Read receipts'),
            subtitle: Text('Show when messages are read'),
            value: true,
            onChanged: null,
          ),
          SwitchListTile(
            title: Text('Typing indicator'),
            value: true,
            onChanged: null,
          ),
          ListTile(
            title: Text('Chat backup'),
            subtitle: Text('Daily • Wi-Fi only'),
          ),
        ],
      ),
    );
  }
}
