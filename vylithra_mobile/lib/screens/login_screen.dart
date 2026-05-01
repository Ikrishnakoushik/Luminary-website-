import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (_isLogin) {
        final result = await auth.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (result['requires2FA'] == true) {
          if (mounted) await _show2FADialog();
        }
      } else {
        await auth.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _usernameController.text.trim(),
        );
        if (mounted) await _showVerifyEmailDialog(_emailController.text.trim());
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _show2FADialog() async {
    final totpController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Two-Factor Auth', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: totpController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter 6-digit Authenticator Code',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await Provider.of<AuthProvider>(context, listen: false).signIn(
                  _emailController.text.trim(),
                  _passwordController.text,
                  totpController.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _showVerifyEmailDialog(String email) async {
    final otpController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Verify Email', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('We sent a 6-digit code to $email', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit OTP',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await Provider.of<AuthProvider>(context, listen: false).verifyEmail(email, otpController.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetPasswordDialog(String email) async {
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the 6-digit code sent to $email', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit OTP',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'New Password',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await Provider.of<AuthProvider>(context, listen: false).resetPassword(email, otpController.text.trim(), newPasswordController.text);
                if (ctx.mounted) Navigator.of(ctx).pop();
                setState(() => _successMessage = 'Password reset successfully! You can now log in.');
              } catch (e) {
                setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Recover Account', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: resetEmailController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter your email',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await Provider.of<AuthProvider>(context, listen: false).forgotPassword(resetEmailController.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) await _showResetPasswordDialog(resetEmailController.text.trim());
              } catch (e) {
                setState(() {
                  _errorMessage = e.toString().replaceFirst('Exception: ', '');
                  _successMessage = null;
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Vylithra',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isLogin ? 'Sign in to continue' : 'Create a new account',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 36),
              
              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(color: Colors.greenAccent),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
                
              if (!_isLogin) ...[
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                ),
                obscureText: true,
              ),
              
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                )
              else
                const SizedBox(height: 32),
                
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          _isLogin ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? "Don't have an account?" : "Already have an account?",
                    style: const TextStyle(color: Colors.white54),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = null;
                        _successMessage = null;
                      });
                    },
                    child: Text(
                      _isLogin ? 'Sign Up' : 'Sign In',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
