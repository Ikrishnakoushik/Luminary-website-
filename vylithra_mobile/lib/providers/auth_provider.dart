import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  String? _vylithraToken;
  final ApiService _apiService = ApiService();

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  String? get token => _vylithraToken;

  AuthProvider() {
    _loadToken();
  }

  Future<void> syncFcmToken() async {
    try {
      if (_isAuthenticated) {
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _apiService.put('/api/users/fcm-token', {'fcmToken': fcmToken});
        }
      }
    } catch (e) {
      debugPrint('Failed to sync FCM Token: $e');
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _vylithraToken = prefs.getString('auth_token');
    _isAuthenticated = _vylithraToken != null;
    _isInitialized = true;
    notifyListeners();
    if (_isAuthenticated) {
      syncFcmToken();
    }
  }

  Future<Map<String, dynamic>> signIn(String email, String password, [String? totpCode]) async {
    try {
      final data = {
        'email': email,
        'password': password,
        'totpCode': totpCode,
      };

      final response = await _apiService.post('/api/login', data);
      
      if (response != null) {
        if (response['requires2FA'] == true) {
          return {'requires2FA': true};
        }
        
        if (response['requiresVerification'] == true) {
          throw Exception(response['msg'] ?? 'Please verify your email before logging in.');
        }

        if (response['token'] != null) {
          await _saveToken(response['token']);
          await syncFcmToken();
          return {'success': true};
        }
      }
      throw Exception('Login failed: Invalid response');
    } catch (e) {
      throw Exception('Login Error: $e');
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    try {
      final response = await _apiService.post('/api/register', {
        'email': email,
        'password': password,
        'username': username,
        'role': 'reader',
      });
      // Backend should return msg about OTP sent
      if (response == null) throw Exception('Registration failed');
    } catch (e) {
      throw Exception('Signup Error: $e');
    }
  }

  Future<void> verifyEmail(String email, String otp) async {
    try {
      final response = await _apiService.post('/api/verify-email', {
        'email': email,
        'otp': otp,
      });
      
      if (response != null && response['token'] != null) {
        await _saveToken(response['token']);
      } else {
        throw Exception('Verification failed: No token returned');
      }
    } catch (e) {
      throw Exception('Verification Error: $e');
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      if (email.isEmpty) throw Exception('Please enter your email address');
      await _apiService.post('/api/auth/forgot-password', {'email': email});
    } catch (e) {
      throw Exception('Reset Error: $e');
    }
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    try {
      await _apiService.post('/api/auth/reset-password', {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });
    } catch (e) {
      throw Exception('Password Reset Error: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    _vylithraToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _vylithraToken!);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _vylithraToken = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
