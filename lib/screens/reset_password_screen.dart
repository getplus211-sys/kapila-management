import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/password_reset_service.dart';
import 'login_screen.dart';

// ============================================================
// RESET PASSWORD SCREEN
// Deep link થી app ખૂલ્યા પછી આ screen દેખાય
// User new password set કરે
// ============================================================
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSessionValid = false;
  bool _isCheckingSession = true;

  // Password strength
  double _passwordStrength = 0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_checkPasswordStrength);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Session valid છે? (Deep link token valid?)
  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final session = Supabase.instance.client.auth.currentSession;
    if (mounted) {
      setState(() {
        _isSessionValid = session != null;
        _isCheckingSession = false;
      });
    }
  }

  // Password strength checker
  void _checkPasswordStrength() {
    final password = _newPasswordController.text;
    double strength = 0;

    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;

    String text;
    Color color;
    if (strength <= 0.25) {
      text = 'Weak';
      color = Colors.red;
    } else if (strength <= 0.5) {
      text = 'Fair';
      color = Colors.orange;
    } else if (strength <= 0.75) {
      text = 'Good';
      color = const Color(0xFF9B6FF0);
    } else {
      text = 'Strong ✅';
      color = Colors.green;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthText = text;
      _passwordStrengthColor = color;
    });
  }

  // Password update karo
  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await PasswordResetService.updatePassword(
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      _showSuccessAndNavigate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Password update failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Success - Login screen par jao
  void _showSuccessAndNavigate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF252A40), width: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Password Update થઈ ગઈ! 🎉',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEEEEF5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'તમારી new password સેટ થઈ ગઈ.\nHવે login કરો.',
              style: TextStyle(color: Color(0xFF8890AA)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Supabase.instance.client.auth.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B4FD6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF7B4FD6).withOpacity(0.4),
              ),
              child: const Text('Login કરો'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B0E1A),
              Color(0xFF1C2035),
            ],
          ),
        ),
        child: SafeArea(
          child: _isCheckingSession
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7B4FD6)),
                )
              : !_isSessionValid
                  ? _buildInvalidSession()
                  : _buildPasswordForm(),
        ),
      ),
    );
  }

  // Invalid/Expired session UI
  Widget _buildInvalidSession() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, color: Color(0xFF9B6FF0), size: 80),
            const SizedBox(height: 24),
            const Text(
              'Link Expired ⚠️',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEEEEF5),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Password reset link expire થઈ ગઈ\nઅથવા invalid છે.\n\nForgot Password ફરીથી try કરો.',
              style: TextStyle(color: Color(0xFF8890AA), fontSize: 15, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B4FD6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF7B4FD6).withOpacity(0.4),
              ),
              child: const Text(
                'Login Page પર જાઓ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main password form
  Widget _buildPasswordForm() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Header Icon
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF7B4FD6).withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF7B4FD6).withOpacity(0.4),
              width: 2,
            ),
          ),
          child: const Icon(Icons.lock_open, size: 45, color: Color(0xFF9B6FF0)),
        ),
        const SizedBox(height: 16),
        const Text(
          'New Password Set કરો',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEEEEF5),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Strong password choose કરો',
          style: TextStyle(color: Color(0xFF8890AA), fontSize: 14),
        ),
        const SizedBox(height: 30),

        // Form Card
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141828),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF252A40), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Password Requirements Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B4FD6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF7B4FD6).withOpacity(0.3),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password Requirements:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9B6FF0),
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 6),
                          _RequirementRow(text: 'ઓછામાં ઓછા 8 characters'),
                          _RequirementRow(text: 'એક Capital letter (A-Z)'),
                          _RequirementRow(text: 'એક Number (0-9)'),
                          _RequirementRow(text: 'એક Special character (!@#\$)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // New Password Field
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      style: const TextStyle(color: Color(0xFFEEEEF5)),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: const TextStyle(color: Color(0xFF8890AA)),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8890AA)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF8890AA),
                          ),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF252A40)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF252A40)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7B4FD6), width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1C2035),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'New password enter કરો';
                        }
                        if (value.length < 8) {
                          return 'ઓછામાં ઓછા 8 characters જોઈએ';
                        }
                        if (!value.contains(RegExp(r'[A-Z]'))) {
                          return 'એક Capital letter add કરો';
                        }
                        if (!value.contains(RegExp(r'[0-9]'))) {
                          return 'એક Number add કરો';
                        }
                        return null;
                      },
                    ),

                    // Password Strength Indicator
                    if (_newPasswordController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _passwordStrength,
                              backgroundColor: const Color(0xFF252A40),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _passwordStrengthColor,
                              ),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _passwordStrengthText,
                            style: TextStyle(
                              color: _passwordStrengthColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(color: Color(0xFFEEEEF5)),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: const TextStyle(color: Color(0xFF8890AA)),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8890AA)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF8890AA),
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF252A40)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF252A40)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7B4FD6), width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1C2035),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password confirm કરો';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords match નથી';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Update Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B4FD6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF7B4FD6).withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF7B4FD6).withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Password Update કરો',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Cancel
                    TextButton(
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      ),
                      child: const Text(
                        'Cancel - Login પર જાઓ',
                        style: TextStyle(color: Color(0xFF8890AA)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// Helper widget - password requirement row
class _RequirementRow extends StatelessWidget {
  final String text;
  const _RequirementRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF9B6FF0)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8890AA)),
          ),
        ],
      ),
    );
  }
}