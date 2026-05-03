import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Provider.of<AuthProvider>(context, listen: false).forgotPassword(email);
      setState(() {
        _otpSent = true;
        _successMessage = 'A 6-digit code has been sent to $email';
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;

    if (otp.isEmpty || newPassword.isEmpty) {
      setState(() => _errorMessage = 'Please enter the code and a new password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Provider.of<AuthProvider>(context, listen: false).resetPassword(email, otp, newPassword);
      setState(() {
        _successMessage = 'Password reset successfully!';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context); // Go back to login
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF0F172A), const Color(0xFF3B82F6).withValues(alpha: 0.15), const Color(0xFF8B5CF6).withValues(alpha: 0.15), const Color(0xFF0F172A)]
              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
            stops: isDark ? [0.0, 0.4, 0.6, 1.0] : null,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_reset, size: 60, color: isDark ? Colors.white : Colors.black87),
                      const SizedBox(height: 16),
                      Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _otpSent ? 'Enter the code and your new password.' : 'Enter your email to receive a reset code.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      
                      if (_successMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(_successMessage!, style: const TextStyle(color: Colors.greenAccent), textAlign: TextAlign.center),
                        ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                        ),
                        
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        isDark: isDark,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_otpSent,
                      ),
                      
                      if (_otpSent) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _otpController,
                          label: '6-Digit Code',
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _newPasswordController,
                          label: 'New Password',
                          isDark: isDark,
                          obscureText: true,
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : (_otpSent ? _resetPassword : _sendResetLink),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  _otpSent ? 'Update Password' : 'Send Code',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    bool obscureText = false,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(28),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white : Colors.black),
          borderRadius: BorderRadius.circular(28),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(28),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
    );
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
