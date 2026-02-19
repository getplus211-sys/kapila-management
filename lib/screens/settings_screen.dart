import 'package:flutter/material.dart';
import 'privacy_security_screen.dart';
import 'chat_settings_screen.dart';
import 'notifications_settings_screen.dart';
import 'data_storage_screen.dart';
import 'devices_screen.dart';
import 'nandigram_faq_screen.dart';
import 'nandigram_privacy_policy_screen.dart';
import 'ask_feedback_screen.dart';

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
          _sectionTitle('App Settings'),

          _settingsTile(
            icon: Icons.chat,
            title: 'Chat Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatSettingsScreen(),
                ),
              );
            },
          ),
          
          _settingsTile(
            icon: Icons.notifications,
            title: 'Notifications & Sounds',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsSettingsScreen(),
                ),
              );
            },
          ),
          
          _settingsTile(
            icon: Icons.lock,
            title: 'Privacy & Security',
            onTap: () {
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DataStorageScreen(),
                ),
              );
            },
          ),
          
          _settingsTile(
            icon: Icons.devices,
            title: 'Devices',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DevicesScreen(),
                ),
              );
            },
          ),

          const Divider(),

          _sectionTitle('Help & Info'),

          _settingsTile(
            icon: Icons.help_outline,
            title: 'Nandigram FAQ',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NandigramFAQScreen(),
                ),
              );
            },
          ),
          
          _settingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NandigramPrivacyPolicyScreen(),
                ),
              );
            },
          ),
          
          _settingsTile(
            icon: Icons.feedback_outlined,
            title: 'Ask & Feedback',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AskFeedbackScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

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