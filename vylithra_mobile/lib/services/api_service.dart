import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';

class ApiService {
  // Use https://vylithra.in for production
  static const String baseUrl = 'https://vylithra.in';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
      headers['x-auth-token'] = token;
    }
    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _getHeaders(),
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['msg'] != null) {
          // If the server returns 500, we might still want to override it with our friendly message, 
          // but usually the server returns the friendly message itself now.
          // For 400/403/404, we definitely want the real error message.
          if (response.statusCode == 500) {
            throw Exception('Oops! Our servers took a quick nap. Please try again.');
          }
          throw Exception(errorData['msg']);
        }
      } catch (e) {
        if (e.toString().contains('Oops!')) throw e;
        // Ignore json decoding errors
      }
      throw Exception('Oops! Our servers took a quick nap. Please try again. (Code: ${response.statusCode})');
    }
  }

  Future<List<Post>> fetchPosts() async {
    final List<dynamic> data = await get('/api/posts');
    return data.map((json) => Post.fromJson(json)).toList();
  }
}
