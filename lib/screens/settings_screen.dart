import 'package:flutter/material.dart';
import 'privacy_security_screen.dart'; // Import the privacy screen

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // -------- Account / App Settings --------
          _sectionTitle('App Settings'),

          _settingsTile(
            icon: Icons.chat,
            title: 'Chat Settings',
            onTap: () {
              // TODO: Navigate to Chat Settings
            },
          ),
          _settingsTile(
            icon: Icons.notifications,
            title: 'Notifications & Sounds',
            onTap: () {
              // TODO: Navigate to Notifications Settings
            },
          ),
          _settingsTile(
            icon: Icons.lock,
            title: 'Privacy & Security',
            onTap: () {
              // Navigate to Privacy & Security Screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacySecurityScreen(),
                ),
              );
            },
          ),
          _settingsTile(
            icon: Icons.storage,
            title: 'Data & Storage',
            onTap: () {
              // TODO: Navigate to Data & Storage Settings
            },
          ),
          _settingsTile(
            icon: Icons.devices,
            title: 'Devices',
            onTap: () {
              // TODO: Navigate to Devices Screen
              // Or you can directly open Active Sessions from Privacy Screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacySecurityScreen(),
                ),
              );
            },
          ),

          const Divider(),

          // -------- Help & Info --------
          _sectionTitle('Help & Info'),

          _settingsTile(
            icon: Icons.help_outline,
            title: 'Nandigram FAQ',
            onTap: () {
              // TODO: Navigate to FAQ
            },
          ),
          _settingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              // TODO: Navigate to Privacy Policy
            },
          ),
          _settingsTile(
            icon: Icons.feedback_outlined,
            title: 'Ask & Feedback',
            onTap: () {
              // TODO: Navigate to Feedback
            },
          ),
        ],
      ),
    );
  }

  // ---------- Reusable Widgets ----------

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}