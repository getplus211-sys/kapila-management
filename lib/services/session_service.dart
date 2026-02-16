import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SessionService {
  final _supabase = Supabase.instance.client;

  // ✅ Schema: session_id, user_id, device_type, device_name, 
  //    device_model, os_version, app_version, ip_address,
  //    is_current, last_active_at, session_token_hash
  Future<void> createSession({required String sessionTokenHash}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final deviceInfo = DeviceInfoPlugin();
      String deviceType = 'unknown';
      String deviceName = 'unknown';
      String deviceModel = 'unknown';
      String osVersion = 'unknown';

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceType = 'android';
        deviceName = info.device;
        deviceModel = info.model;
        osVersion = 'Android ${info.version.release}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceType = 'ios';
        deviceName = info.name;
        deviceModel = info.model;
        osVersion = '${info.systemName} ${info.systemVersion}';
      }

      // Mark all previous sessions as not current
      await _supabase.from('ngm_active_sessions').update({
        'is_current': false,
      }).eq('user_id', userId);

      // Create new session
      await _supabase.from('ngm_active_sessions').insert({
        'user_id': userId,
        'device_type': deviceType,
        'device_name': deviceName,
        'device_model': deviceModel,
        'os_version': osVersion,
        'app_version': '1.0.0',
        'is_current': true,
        'last_active_at': DateTime.now().toIso8601String(),
        'session_token_hash': sessionTokenHash,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Session created');
    } catch (e) {
      debugPrint('Error creating session: $e');
    }
  }

  // ✅ Update last active
  Future<void> updateLastActive() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('ngm_active_sessions').update({
        'last_active_at': DateTime.now().toIso8601String(),
      })
      .eq('user_id', userId)
      .eq('is_current', true);
    } catch (e) {
      debugPrint('Error updating last active: $e');
    }
  }

  // ✅ Load all active sessions
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('ngm_active_sessions')
          .select()
          .eq('user_id', userId)
          .order('last_active_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting sessions: $e');
      return [];
    }
  }

  // ✅ Terminate specific session
  Future<void> terminateSession(String sessionId) async {
    try {
      await _supabase
          .from('ngm_active_sessions')
          .delete()
          .eq('session_id', sessionId);
    } catch (e) {
      debugPrint('Error terminating session: $e');
    }
  }

  // ✅ Terminate all other sessions
  Future<void> terminateAllOtherSessions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('ngm_active_sessions')
          .delete()
          .eq('user_id', userId)
          .eq('is_current', false);
    } catch (e) {
      debugPrint('Error terminating sessions: $e');
    }
  }
}