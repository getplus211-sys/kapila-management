import 'package:flutter/material.dart';
import '../services/password_reset_service.dart';

// ============================================================
// FORGOT PASSWORD SCREEN
// User email enter કરે - reset link send થાય
// ============================================================
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;   // Login screen પરથી pre-fill

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await PasswordResetService.sendResetEmail(
      email: _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      setState(() => _emailSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Error occurred'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          child: Column(
            children: [
              // Back Button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFEEEEF5)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _emailSent
                        ? _buildSuccessState()
                        : _buildFormState(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FORM STATE - Email input
  Widget _buildFormState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF7B4FD6).withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF7B4FD6).withOpacity(0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.lock_reset,
            size: 50,
            color: Color(0xFF9B6FF0),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Password Reset',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEEEEF5),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'તમારો email address enter કરો.\nReset link send કરીશું.',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF8890AA),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Card
        Container(
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
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: const TextStyle(color: Color(0xFFEEEEF5)),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: Color(0xFF8890AA)),
                    hintText: 'yourname@email.com',
                    hintStyle: const TextStyle(color: Color(0xFF8890AA)),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8890AA)),
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
                    if (value == null || value.trim().isEmpty) {
                      return 'Email address enter કરો';
                    }
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Valid email address enter કરો';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Send Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendResetEmail,
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
                          'Reset Link મોકલો',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // SUCCESS STATE - Email sent confirmation
  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF7B4FD6).withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF7B4FD6).withOpacity(0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 60,
            color: Color(0xFF9B6FF0),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Email Send થઈ ગઈ! ✅',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEEEEF5),
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141828),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF252A40), width: 1),
          ),
          child: Column(
            children: [
              Text(
                _emailController.text.trim(),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9B6FF0),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ઉપરના email પર reset link send\nકરવામાં આવ્યો છે.\n\nEmail ખોલો અને link પર click\nકરો - app automatically ખૂલશે.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8890AA),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Spam note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Email ન મળ્યો? Spam/Junk folder\ncheckk કરો.',
                  style: TextStyle(color: Colors.amber, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Back to Login Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B4FD6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF7B4FD6).withOpacity(0.4),
            ),
            child: const Text(
              'Login પર પાછા જાઓ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Resend option
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: const Text(
            'બીજી email ID try કરો',
            style: TextStyle(
              color: Color(0xFF8890AA),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF8890AA),
            ),
          ),
        ),
      ],
    );
  }
}