import 'package:flutter/material.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.phone_android),
            title: Text('Android'),
            subtitle: Text('This device • Active now'),
          ),
          ListTile(
            leading: Icon(Icons.laptop),
            title: Text('Windows'),
            subtitle: Text('Last active 2 days ago'),
          ),
        ],
      ),
    );
  }
}
