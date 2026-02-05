import 'package:flutter/material.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data & Storage')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('Storage used'),
            subtitle: Text('1.4 GB'),
          ),
          SwitchListTile(
            title: Text('Save media to gallery'),
            value: true,
            onChanged: null,
          ),
          SwitchListTile(
            title: Text('Use less data'),
            value: false,
            onChanged: null,
          ),
        ],
      ),
    );
  }
}
