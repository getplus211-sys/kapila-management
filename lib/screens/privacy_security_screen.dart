import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Privacy & Security Settings Screen for Nandigram
/// Contains all privacy controls, security features, and session management
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Privacy Settings
  String _lastSeenVisible = 'everyone';
  String _profilePictureVisible = 'everyone';
  String _phoneVisible = 'contacts';
  String _bioVisible = 'everyone';
  String _onlineStatusVisible = 'everyone';
  String _whoCanMessage = 'everyone';
  String _whoCanAddToGroups = 'everyone';
  String _forwardedMessagesPrivacy = 'show_sender';
  bool _usernameSearchable = true;
  bool _showPhoneInProfile = true;
  int? _autoDeleteMessagesDays;
  
  // Security Settings
  bool _twoFactorEnabled = false;
  bool _appLockEnabled = false;
  String _lockType = 'pin';
  int _autoLockDuration = 300;
  bool _readReceiptsEnabled = true;
  bool _typingIndicatorEnabled = true;
  
  // Account Settings
  bool _autoDestructEnabled = false;
  int _inactivityDays = 180;
  
  // Active Sessions
  List<Map<String, dynamic>> _activeSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load user settings
      final settings = await _supabase
          .from('ngm_user_settings')
          .select()
          .eq('user_id', userId)
          .single();

      // Load 2FA status
      final twoFactorData = await _supabase
          .from('ngm_2fa_settings')
          .select('is_enabled')
          .eq('user_id', userId)
          .maybeSingle();

      // Load app lock status
      final appLockData = await _supabase
          .from('ngm_app_lock')
          .select('is_enabled, lock_type, auto_lock_duration')
          .eq('user_id', userId)
          .maybeSingle();

      // Load auto-destruct status
      final autoDestructData = await _supabase
          .from('ngm_account_autodestruct')
          .select('is_enabled, inactivity_days')
          .eq('user_id', userId)
          .maybeSingle();

      // Load active sessions
      final sessions = await _supabase
          .from('ngm_active_sessions')
          .select()
          .eq('user_id', userId)
          .order('last_active_at', ascending: false);

      setState(() {
        // Privacy settings
        _lastSeenVisible = settings['last_seen_visible'] ?? 'everyone';
        _profilePictureVisible = settings['profile_picture_visible'] ?? 'everyone';
        _phoneVisible = settings['phone_visible'] ?? 'contacts';
        _bioVisible = settings['bio_visible'] ?? 'everyone';
        _onlineStatusVisible = settings['online_status_visible'] ?? 'everyone';
        _whoCanMessage = settings['who_can_message'] ?? 'everyone';
        _whoCanAddToGroups = settings['who_can_add_to_groups'] ?? 'everyone';
        _forwardedMessagesPrivacy = settings['forwarded_messages_privacy'] ?? 'show_sender';
        _usernameSearchable = settings['username_searchable'] ?? true;
        _showPhoneInProfile = settings['show_phone_in_profile'] ?? true;
        _autoDeleteMessagesDays = settings['auto_delete_messages_days'];
        _readReceiptsEnabled = settings['read_receipts_enabled'] ?? true;
        _typingIndicatorEnabled = settings['typing_indicator_enabled'] ?? true;
        
        // Security settings
        _twoFactorEnabled = twoFactorData?['is_enabled'] ?? false;
        _appLockEnabled = appLockData?['is_enabled'] ?? false;
        _lockType = appLockData?['lock_type'] ?? 'pin';
        _autoLockDuration = appLockData?['auto_lock_duration'] ?? 300;
        
        // Account settings
        _autoDestructEnabled = autoDestructData?['is_enabled'] ?? false;
        _inactivityDays = autoDestructData?['inactivity_days'] ?? 180;
        
        // Sessions
        _activeSessions = List<Map<String, dynamic>>.from(sessions);
        
        _isLoading = false;
      });
    } catch (e) {
      _showError('Failed to load settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrivacySetting(String field, dynamic value) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('ngm_user_settings')
          .update({field: value})
          .eq('user_id', userId);
          
      _showSuccess('Privacy setting updated');
    } catch (e) {
      _showError('Failed to update setting: $e');
    }
  }

  Future<void> _toggleTwoFactor() async {
    if (!_twoFactorEnabled) {
      // Navigate to 2FA setup screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TwoFactorSetupScreen()),
      );
      if (result == true) {
        setState(() => _twoFactorEnabled = true);
      }
    } else {
      // Show confirmation dialog
      final confirm = await _showConfirmDialog(
        'Disable Two-Factor Authentication',
        'Are you sure you want to disable 2FA? This will make your account less secure.',
      );
      
      if (confirm) {
        try {
          final userId = _supabase.auth.currentUser?.id;
          await _supabase
              .from('ngm_2fa_settings')
              .update({'is_enabled': false})
              .eq('user_id', userId!);
          setState(() => _twoFactorEnabled = false);
          _showSuccess('Two-factor authentication disabled');
        } catch (e) {
          _showError('Failed to disable 2FA: $e');
        }
      }
    }
  }

  Future<void> _toggleAppLock() async {
    if (!_appLockEnabled) {
      // Navigate to app lock setup
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AppLockSetupScreen()),
      );
      if (result == true) {
        _loadSettings();
      }
    } else {
      // Disable app lock
      try {
        final userId = _supabase.auth.currentUser?.id;
        await _supabase
            .from('ngm_app_lock')
            .update({'is_enabled': false})
            .eq('user_id', userId!);
        setState(() => _appLockEnabled = false);
        _showSuccess('App lock disabled');
      } catch (e) {
        _showError('Failed to disable app lock: $e');
      }
    }
  }

  Future<void> _terminateSession(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase
          .from('ngm_active_sessions')
          .delete()
          .eq('session_id', sessionId)
          .eq('user_id', userId!);
      
      setState(() {
        _activeSessions.removeWhere((s) => s['session_id'] == sessionId);
      });
      _showSuccess('Session terminated');
    } catch (e) {
      _showError('Failed to terminate session: $e');
    }
  }

  Future<void> _terminateAllOtherSessions() async {
    final confirm = await _showConfirmDialog(
      'Terminate All Other Sessions',
      'This will log you out from all other devices. Continue?',
    );
    
    if (confirm) {
      try {
        final userId = _supabase.auth.currentUser?.id;
        final currentSession = _activeSessions.firstWhere(
          (s) => s['is_current'] == true,
          orElse: () => {},
        );
        
        await _supabase
            .from('ngm_active_sessions')
            .delete()
            .eq('user_id', userId!)
            .neq('session_id', currentSession['session_id']);
        
        _loadSettings();
        _showSuccess('All other sessions terminated');
      } catch (e) {
        _showError('Failed to terminate sessions: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy & Security')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // SECURITY SECTION
          _buildSectionHeader('Security', Icons.security),
          
          _buildSwitchTile(
            'Two-Step Verification',
            'Add an extra layer of security with password',
            Icons.verified_user,
            _twoFactorEnabled,
            (value) => _toggleTwoFactor(),
          ),
          
          _buildSwitchTile(
            'App Lock',
            'Lock app with PIN, password, or biometric',
            Icons.lock,
            _appLockEnabled,
            (value) => _toggleAppLock(),
          ),
          
          if (_appLockEnabled) ...[
            _buildSettingTile(
              'Lock Type',
              _lockType.toUpperCase(),
              Icons.lock_outline,
              onTap: () => _showLockTypeDialog(),
            ),
            _buildSettingTile(
              'Auto-Lock Duration',
              _formatDuration(_autoLockDuration),
              Icons.timer,
              onTap: () => _showAutoLockDialog(),
            ),
          ],

          const Divider(height: 32),

          // PRIVACY SECTION
          _buildSectionHeader('Privacy', Icons.privacy_tip),
          
          _buildPrivacyTile(
            'Last Seen & Online',
            _lastSeenVisible,
            Icons.access_time,
            (value) async {
              setState(() => _lastSeenVisible = value);
              await _updatePrivacySetting('last_seen_visible', value);
            },
          ),
          
          _buildPrivacyTile(
            'Profile Photo',
            _profilePictureVisible,
            Icons.photo,
            (value) async {
              setState(() => _profilePictureVisible = value);
              await _updatePrivacySetting('profile_picture_visible', value);
            },
          ),
          
          _buildPrivacyTile(
            'Phone Number',
            _phoneVisible,
            Icons.phone,
            (value) async {
              setState(() => _phoneVisible = value);
              await _updatePrivacySetting('phone_visible', value);
            },
          ),
          
          _buildPrivacyTile(
            'Bio',
            _bioVisible,
            Icons.info,
            (value) async {
              setState(() => _bioVisible = value);
              await _updatePrivacySetting('bio_visible', value);
            },
          ),
          
          _buildPrivacyTile(
            'Who Can Message Me',
            _whoCanMessage,
            Icons.message,
            (value) async {
              setState(() => _whoCanMessage = value);
              await _updatePrivacySetting('who_can_message', value);
            },
          ),
          
          _buildPrivacyTile(
            'Who Can Add Me to Groups',
            _whoCanAddToGroups,
            Icons.group_add,
            (value) async {
              setState(() => _whoCanAddToGroups = value);
              await _updatePrivacySetting('who_can_add_to_groups', value);
            },
          ),

          const Divider(height: 32),

          // MESSAGES SECTION
          _buildSectionHeader('Messages', Icons.chat),
          
          _buildSwitchTile(
            'Read Receipts',
            'Show when you have read messages',
            Icons.done_all,
            _readReceiptsEnabled,
            (value) async {
              setState(() => _readReceiptsEnabled = value);
              await _updatePrivacySetting('read_receipts_enabled', value);
            },
          ),
          
          _buildSwitchTile(
            'Typing Indicator',
            'Show when you are typing',
            Icons.keyboard,
            _typingIndicatorEnabled,
            (value) async {
              setState(() => _typingIndicatorEnabled = value);
              await _updatePrivacySetting('typing_indicator_enabled', value);
            },
          ),
          
          _buildSettingTile(
            'Forwarded Messages',
            _formatForwardPrivacy(_forwardedMessagesPrivacy),
            Icons.forward,
            onTap: () => _showForwardPrivacyDialog(),
          ),
          
          _buildSettingTile(
            'Auto-Delete Messages',
            _autoDeleteMessagesDays == null ? 'Off' : '$_autoDeleteMessagesDays days',
            Icons.auto_delete,
            onTap: () => _showAutoDeleteDialog(),
          ),

          const Divider(height: 32),

          // ADVANCED SECTION
          _buildSectionHeader('Advanced', Icons.tune),
          
          _buildSwitchTile(
            'Username Search',
            'Allow others to find you by username',
            Icons.search,
            _usernameSearchable,
            (value) async {
              setState(() => _usernameSearchable = value);
              await _updatePrivacySetting('username_searchable', value);
            },
          ),
          
          _buildSwitchTile(
            'Show Phone in Profile',
            'Display phone number in your profile',
            Icons.phone_android,
            _showPhoneInProfile,
            (value) async {
              setState(() => _showPhoneInProfile = value);
              await _updatePrivacySetting('show_phone_in_profile', value);
            },
          ),
          
          _buildSettingTile(
            'Privacy Exceptions',
            'Manage custom privacy rules',
            Icons.rule,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrivacyExceptionsScreen()),
            ),
          ),

          const Divider(height: 32),

          // ACTIVE SESSIONS SECTION
          _buildSectionHeader('Active Sessions', Icons.devices),
          
          ..._activeSessions.map((session) => _buildSessionTile(session)).toList(),
          
          if (_activeSessions.length > 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _terminateAllOtherSessions,
                icon: const Icon(Icons.logout),
                label: const Text('Terminate All Other Sessions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

          const Divider(height: 32),

          // ACCOUNT SECTION
          _buildSectionHeader('Account', Icons.account_circle),
          
          _buildSwitchTile(
            'Auto-Delete Account',
            'Delete account after $_inactivityDays days of inactivity',
            Icons.delete_forever,
            _autoDestructEnabled,
            (value) => _toggleAutoDestruct(value),
          ),
          
          if (_autoDestructEnabled)
            _buildSettingTile(
              'Inactivity Period',
              '$_inactivityDays days',
              Icons.calendar_today,
              onTap: () => _showInactivityDialog(),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      secondary: Icon(icon),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSettingTile(
    String title,
    String value,
    IconData icon,
    {VoidCallback? onTap}
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.grey)),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildPrivacyTile(
    String title,
    String currentValue,
    IconData icon,
    Function(String) onChanged,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatPrivacyValue(currentValue),
            style: const TextStyle(color: Colors.grey),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showPrivacyDialog(title, currentValue, onChanged),
    );
  }

  Widget _buildSessionTile(Map<String, dynamic> session) {
    final isCurrent = session['is_current'] ?? false;
    final deviceIcon = _getDeviceIcon(session['device_type']);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(deviceIcon, size: 32),
        title: Row(
          children: [
            Expanded(
              child: Text(
                session['device_name'] ?? 'Unknown Device',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Current',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${session['device_model']} • ${session['os_version']}'),
            Text('${session['location_city']}, ${session['location_country']}'),
            Text(
              isCurrent 
                ? 'Active now' 
                : 'Last active: ${_formatLastActive(session['last_active_at'])}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: isCurrent 
          ? null 
          : IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _terminateSession(session['session_id']),
            ),
      ),
    );
  }

  IconData _getDeviceIcon(String? deviceType) {
    switch (deviceType?.toLowerCase()) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
        return Icons.language;
      case 'desktop':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  String _formatPrivacyValue(String value) {
    switch (value) {
      case 'everyone':
        return 'Everyone';
      case 'contacts':
        return 'My Contacts';
      case 'nobody':
        return 'Nobody';
      default:
        return value;
    }
  }

  String _formatForwardPrivacy(String value) {
    switch (value) {
      case 'show_sender':
        return 'Show Sender';
      case 'hide_sender':
        return 'Hide Sender';
      case 'disabled':
        return 'Disabled';
      default:
        return value;
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    return '$hours hours';
  }

  String _formatLastActive(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    final dateTime = DateTime.parse(timestamp);
    final diff = DateTime.now().difference(dateTime);
    
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Future<void> _showPrivacyDialog(
    String title,
    String currentValue,
    Function(String) onChanged,
  ) async {
    final options = ['everyone', 'contacts', 'nobody'];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<String>(
              title: Text(_formatPrivacyValue(option)),
              value: option,
              groupValue: currentValue,
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showLockTypeDialog() async {
    final types = ['pin', 'password', 'biometric', 'pattern'];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: types.map((type) {
            return RadioListTile<String>(
              title: Text(type.toUpperCase()),
              value: type,
              groupValue: _lockType,
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _lockType = value);
                  Navigator.pop(context);
                  // Navigate to lock setup with new type
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppLockSetupScreen(lockType: value),
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showAutoLockDialog() async {
    final durations = [60, 300, 900, 1800]; // 1min, 5min, 15min, 30min
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Lock Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: durations.map((duration) {
            return RadioListTile<int>(
              title: Text(_formatDuration(duration)),
              value: duration,
              groupValue: _autoLockDuration,
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _autoLockDuration = value);
                  final userId = _supabase.auth.currentUser?.id;
                  await _supabase
                      .from('ngm_app_lock')
                      .update({'auto_lock_duration': value})
                      .eq('user_id', userId!);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showForwardPrivacyDialog() async {
    final options = ['show_sender', 'hide_sender', 'disabled'];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forwarded Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<String>(
              title: Text(_formatForwardPrivacy(option)),
              value: option,
              groupValue: _forwardedMessagesPrivacy,
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _forwardedMessagesPrivacy = value);
                  await _updatePrivacySetting('forwarded_messages_privacy', value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showAutoDeleteDialog() async {
    final options = [null, 7, 30, 90, 365];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Delete Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<int?>(
              title: Text(option == null ? 'Off' : '$option days'),
              value: option,
              groupValue: _autoDeleteMessagesDays,
              onChanged: (value) async {
                setState(() => _autoDeleteMessagesDays = value);
                await _updatePrivacySetting('auto_delete_messages_days', value);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showInactivityDialog() async {
    final options = [30, 90, 180, 365];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inactivity Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<int>(
              title: Text('$option days'),
              value: option,
              groupValue: _inactivityDays,
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _inactivityDays = value);
                  final userId = _supabase.auth.currentUser?.id;
                  await _supabase
                      .from('ngm_account_autodestruct')
                      .update({'inactivity_days': value})
                      .eq('user_id', userId!);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleAutoDestruct(bool value) async {
    if (value) {
      final confirm = await _showConfirmDialog(
        'Enable Auto-Delete Account',
        'Your account will be automatically deleted after $_inactivityDays days of inactivity. Continue?',
      );
      
      if (confirm) {
        try {
          final userId = _supabase.auth.currentUser?.id;
          await _supabase
              .from('ngm_account_autodestruct')
              .insert({
                'user_id': userId,
                'is_enabled': true,
                'inactivity_days': _inactivityDays,
              })
              .select()
              .single();
          setState(() => _autoDestructEnabled = true);
          _showSuccess('Auto-delete account enabled');
        } catch (e) {
          try {
            final userId = _supabase.auth.currentUser?.id;
            await _supabase
                .from('ngm_account_autodestruct')
                .update({'is_enabled': true, 'inactivity_days': _inactivityDays})
                .eq('user_id', userId!);
            setState(() => _autoDestructEnabled = true);
            _showSuccess('Auto-delete account enabled');
          } catch (e2) {
            _showError('Failed to enable auto-delete: $e2');
          }
        }
      }
    } else {
      try {
        final userId = _supabase.auth.currentUser?.id;
        await _supabase
            .from('ngm_account_autodestruct')
            .update({'is_enabled': false})
            .eq('user_id', userId!);
        setState(() => _autoDestructEnabled = false);
        _showSuccess('Auto-delete account disabled');
      } catch (e) {
        _showError('Failed to disable auto-delete: $e');
      }
    }
  }
}

/// Two-Factor Authentication Setup Screen
class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({Key? key}) : super(key: key);

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _supabase = Supabase.instance.client;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoveryEmailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _enable2FA() async {
    if (_passwordController.text.length < 8) {
      _showError('Password must be at least 8 characters');
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      // Generate backup codes
      final backupCodes = List.generate(10, (i) => 
        '${DateTime.now().millisecondsSinceEpoch}-${i.toString().padLeft(4, '0')}'
      );
      
      await _supabase.from('ngm_2fa_settings').insert({
        'user_id': userId,
        'is_enabled': true,
        'password_hash': _hashPassword(_passwordController.text),
        'recovery_email': _recoveryEmailController.text.isEmpty 
          ? null 
          : _recoveryEmailController.text,
        'backup_codes': backupCodes,
      });
      
      // Show backup codes
      await _showBackupCodes(backupCodes);
      
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed to enable 2FA: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _hashPassword(String password) {
    // In production, use proper hashing like bcrypt
    // This is just a placeholder
    return password.hashCode.toString();
  }

  Future<void> _showBackupCodes(List<String> codes) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Backup Codes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Save these codes in a safe place:'),
            const SizedBox(height: 16),
            ...codes.map((code) => SelectableText(code)).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I have saved these codes'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enable Two-Factor Auth')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a password for 2FA',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recoveryEmailController,
              decoration: const InputDecoration(
                labelText: 'Recovery Email (Optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _enable2FA,
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Enable 2FA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App Lock Setup Screen
class AppLockSetupScreen extends StatefulWidget {
  final String lockType;
  
  const AppLockSetupScreen({Key? key, this.lockType = 'pin'}) : super(key: key);

  @override
  State<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends State<AppLockSetupScreen> {
  final _supabase = Supabase.instance.client;
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _enableAppLock() async {
    if (_pinController.text.length < 4) {
      _showError('${widget.lockType.toUpperCase()} must be at least 4 characters');
      return;
    }
    
    if (_pinController.text != _confirmPinController.text) {
      _showError('Values do not match');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      await _supabase.from('ngm_app_lock').insert({
        'user_id': userId,
        'is_enabled': true,
        'lock_type': widget.lockType,
        'lock_value_hash': _pinController.text.hashCode.toString(),
        'auto_lock_duration': 300,
      });
      
      Navigator.pop(context, true);
    } catch (e) {
      try {
        final userId = _supabase.auth.currentUser?.id;
        await _supabase.from('ngm_app_lock').update({
          'is_enabled': true,
          'lock_type': widget.lockType,
          'lock_value_hash': _pinController.text.hashCode.toString(),
        }).eq('user_id', userId!);
        Navigator.pop(context, true);
      } catch (e2) {
        _showError('Failed to enable app lock: $e2');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set ${widget.lockType.toUpperCase()}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _pinController,
              decoration: InputDecoration(
                labelText: 'Enter ${widget.lockType.toUpperCase()}',
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              keyboardType: widget.lockType == 'pin' 
                ? TextInputType.number 
                : TextInputType.text,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPinController,
              decoration: InputDecoration(
                labelText: 'Confirm ${widget.lockType.toUpperCase()}',
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              keyboardType: widget.lockType == 'pin' 
                ? TextInputType.number 
                : TextInputType.text,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _enableAppLock,
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Enable App Lock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Privacy Exceptions Management Screen
class PrivacyExceptionsScreen extends StatefulWidget {
  const PrivacyExceptionsScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyExceptionsScreen> createState() => _PrivacyExceptionsScreenState();
}

class _PrivacyExceptionsScreenState extends State<PrivacyExceptionsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _exceptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExceptions();
  }

  Future<void> _loadExceptions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final data = await _supabase
          .from('ngm_privacy_exceptions')
          .select()
          .eq('user_id', userId!);
      
      setState(() {
        _exceptions = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Exceptions')),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _exceptions.isEmpty
          ? const Center(child: Text('No exceptions set'))
          : ListView.builder(
              itemCount: _exceptions.length,
              itemBuilder: (context, index) {
                final exception = _exceptions[index];
                return ListTile(
                  title: Text(exception['exception_type']),
                  subtitle: Text('User ID: ${exception['target_user_id']}'),
                  trailing: Text(exception['permission']),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new exception
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}