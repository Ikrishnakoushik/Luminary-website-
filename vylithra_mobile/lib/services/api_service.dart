import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';

class ApiService {
  // Use https://www.vylithra.in for production (must include www to avoid 307 redirects)
  static const String baseUrl = 'https://www.vylithra.in';

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
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } on SocketException {
      throw Exception('Unable to connect to the server. Please check your internet connection or server IP.');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } on SocketException {
      throw Exception('Unable to connect to the server. Please check your internet connection or server IP.');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Oops! Our servers took a quick nap. Please try again. (Code: ${response.statusCode})';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['msg'] != null) {
          if (response.statusCode == 500) {
            errorMessage = 'Oops! Our servers took a quick nap. Please try again.';
          } else {
            errorMessage = errorData['msg'];
          }
        }
      } catch (e) {
        // Ignore json decoding errors, fallback to default errorMessage
      }
      throw Exception(errorMessage);
    }
  }
  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } on SocketException {
      throw Exception('Unable to connect to the server. Please check your internet connection or server IP.');
    }
  }

  Future<dynamic> toggleFollow(String userId, bool currentlyFollowing) async {
    final endpoint = currentlyFollowing ? '/api/users/$userId/unfollow' : '/api/users/$userId/follow';
    if (currentlyFollowing) {
        return await delete(endpoint);
    } else {
        return await post(endpoint, {});
    }
  }

  Future<List<dynamic>> getFollowers(String userId) async {
    return await get('/api/users/$userId/followers');
  }

  Future<List<dynamic>> getFollowing(String userId) async {
    return await get('/api/users/$userId/following');
  }
  Future<List<Post>> fetchPosts() async {
    final List<dynamic> data = await get('/api/posts');
    return data.map((json) => Post.fromJson(json)).toList();
  }

  Future<dynamic> uploadFile(String endpoint, File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['x-auth-token'] = token;
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } on SocketException {
      throw Exception('Unable to connect to the server. Please check your internet connection.');
    }
  }
}
