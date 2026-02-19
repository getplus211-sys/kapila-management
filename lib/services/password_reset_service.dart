import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// PASSWORD RESET SERVICE
// Supabase auth operations handle કરે
// ============================================================

// ✅ Result wrapper - success/error clearly handle
class ResetResult {
  final bool isSuccess;
  final String? errorMessage;

  const ResetResult.success() : isSuccess = true, errorMessage = null;
  const ResetResult.failure(this.errorMessage) : isSuccess = false;
}

class PasswordResetService {
  static final _supabase = Supabase.instance.client;

  // ============================================================
  // STEP 1: Forgot Password - Reset email send karo
  //
  // Supabase Dashboard Configuration:
  //   Authentication > URL Configuration:
  //   Site URL: https://bhmycvrbucmbbrpzeane.supabase.co
  //   Redirect URL: https://kapilalearning.app/reset-password
  //   (Android App Links domain - your AndroidManifest.xml domain)
  // ============================================================
  static Future<ResetResult> sendResetEmail({
    required String email,
  }) async {
    try {
      debugPrint('📧 Sending password reset email to: $email');

      await _supabase.auth.resetPasswordForEmail(
        email,
        // ✅ IMPORTANT: આ redirect URL Supabase Dashboard માં allow list માં હોવો જ જોઈએ
        // Deep link format: https://yourapp.com/reset-password
        // Android App Links: AndroidManifest.xml માં configure થયેલ domain
        redirectTo: 'https://kapilalearning.vercel.app/reset-password',
      );

      debugPrint('✅ Password reset email sent successfully');
      return const ResetResult.success();

    } on AuthException catch (e) {
      debugPrint('❌ AuthException sending reset email: ${e.message}');
      return ResetResult.failure(_getReadableError(e.message));
    } catch (e) {
      debugPrint('❌ Error sending reset email: $e');
      return const ResetResult.failure('Email send કરવામાં error આવ્યો. ફરી try કરો.');
    }
  }

  // ============================================================
  // STEP 2: Reset Password - New password set karo
  // (Session already active from deep link token)
  // ============================================================
  static Future<ResetResult> updatePassword({
    required String newPassword,
  }) async {
    try {
      debugPrint('🔑 Updating password...');

      // ✅ Current session check
      final session = _supabase.auth.currentSession;
      if (session == null) {
        return const ResetResult.failure(
          'Session expired. Reset link ફરીથી use કરો.',
        );
      }

      // ✅ Supabase updateUser - password update
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        debugPrint('✅ Password updated successfully for: ${response.user!.email}');
        return const ResetResult.success();
      } else {
        return const ResetResult.failure('Password update failed. ફરી try કરો.');
      }

    } on AuthException catch (e) {
      debugPrint('❌ AuthException updating password: ${e.message}');
      return ResetResult.failure(_getReadableError(e.message));
    } catch (e) {
      debugPrint('❌ Error updating password: $e');
      return const ResetResult.failure('Password update error. ફરી try કરો.');
    }
  }

  // ============================================================
  // Error messages - Gujarati/readable format
  // ============================================================
  static String _getReadableError(String error) {
    final lower = error.toLowerCase();

    if (lower.contains('user not found') || lower.contains('no user found')) {
      return 'આ email address registered નથી.';
    }
    if (lower.contains('invalid email')) {
      return 'Valid email address enter કરો.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'ઘણા attempts. થોડા સમય પછી try કરો.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Internet connection check કરો.';
    }
    if (lower.contains('expired') || lower.contains('invalid token')) {
      return 'Reset link expire થઈ ગઈ. ફરીથી Forgot Password try કરો.';
    }
    if (lower.contains('same password') || lower.contains('different from')) {
      return 'New password old password કરતાં અલગ હોવી જોઈએ.';
    }
    if (lower.contains('weak password')) {
      return 'Password weak છે. Strong password use કરો.';
    }

    return error; // Default - original error
  }
}