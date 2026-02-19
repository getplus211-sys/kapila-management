import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  SharedPreferences? _prefs;

  // Notifications
  bool _notificationsEnabled = true;
  bool _messageNotifications = true;
  bool _groupNotifications = true;
  bool _channelNotifications = true;
  
  // Sound & Vibration
  bool _sound = true;
  bool _vibrate = true;
  bool _inAppSounds = true;
  bool _inAppVibrate = true;
  
  // Message Preview
  bool _showPreview = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = _prefs?.getBool('notifications_enabled') ?? true;
      _messageNotifications = _prefs?.getBool('message_notifications') ?? true;
      _groupNotifications = _prefs?.getBool('group_notifications') ?? true;
      _channelNotifications = _prefs?.getBool('channel_notifications') ?? true;
      _sound = _prefs?.getBool('notification_sound') ?? true;
      _vibrate = _prefs?.getBool('notification_vibrate') ?? true;
      _inAppSounds = _prefs?.getBool('in_app_sounds') ?? true;
      _inAppVibrate = _prefs?.getBool('in_app_vibrate') ?? true;
      _showPreview = _prefs?.getBool('show_preview') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Sounds'),
      ),
      body: ListView(
        children: [
          _sectionTitle('Notifications'),

          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive notifications for new messages'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSetting('notifications_enabled', value);
            },
          ),

          const Divider(),

          _sectionTitle('Message Notifications'),

          SwitchListTile(
            secondary: const Icon(Icons.message_outlined),
            title: const Text('Private Messages'),
            value: _messageNotifications,
            onChanged: _notificationsEnabled ? (value) {
              setState(() => _messageNotifications = value);
              _saveSetting('message_notifications', value);
            } : null,
          ),

          SwitchListTile(
            secondary: const Icon(Icons.group_outlined),
            title: const Text('Group Messages'),
            value: _groupNotifications,
            onChanged: _notificationsEnabled ? (value) {
              setState(() => _groupNotifications = value);
              _saveSetting('group_notifications', value);
            } : null,
          ),

          SwitchListTile(
            secondary: const Icon(Icons.campaign_outlined),
            title: const Text('Channel Messages'),
            value: _channelNotifications,
            onChanged: _notificationsEnabled ? (value) {
              setState(() => _channelNotifications = value);
              _saveSetting('channel_notifications', value);
            } : null,
          ),

          const Divider(),

          _sectionTitle('Sound & Vibration'),

          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Notification Sound'),
            value: _sound,
            onChanged: _notificationsEnabled ? (value) {
              setState(() => _sound = value);
              _saveSetting('notification_sound', value);
            } : null,
          ),

          SwitchListTile(
            secondary: const Icon(Icons.vibration_outlined),
            title: const Text('Vibrate'),
            value: _vibrate,
            onChanged: _notificationsEnabled ? (value) {
              setState(() => _vibrate = value);
              _saveSetting('notification_vibrate', value);
            } : null,
          ),

          const Divider(),

          _sectionTitle('In-App Notifications'),

          SwitchListTile(
            secondary: const Icon(Icons.music_note_outlined),
            title: const Text('In-App Sounds'),
            subtitle: const Text('Play sound for messages while app is open'),
            value: _inAppSounds,
            onChanged: (value) {
              setState(() => _inAppSounds = value);
              _saveSetting('in_app_sounds', value);
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.smartphone_outlined),
            title: const Text('In-App Vibrate'),
            value: _inAppVibrate,
            onChanged: (value) {
              setState(() => _inAppVibrate = value);
              _saveSetting('in_app_vibrate', value);
            },
          ),

          const Divider(),

          _sectionTitle('Preview'),

          SwitchListTile(
            secondary: const Icon(Icons.preview_outlined),
            title: const Text('Show Message Preview'),
            subtitle: const Text('Display message content in notifications'),
            value: _showPreview,
            onChanged: _notificationsEnabled ? (value) {
              setState(() => _showPreview = value);
              _saveSetting('show_preview', value);
            } : null,
          ),

          const Divider(),

          _sectionTitle('Advanced'),

          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Notification Delay'),
            subtitle: const Text('Delay notifications when reading'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show delay picker
            },
          ),

          ListTile(
            leading: const Icon(Icons.do_not_disturb_outlined),
            title: const Text('Do Not Disturb'),
            subtitle: const Text('Schedule quiet hours'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show DND schedule
            },
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'About FCM Notifications',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We use Firebase Cloud Messaging (FCM) to deliver notifications. '
                      'Make sure notifications are enabled in your device settings.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
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
}