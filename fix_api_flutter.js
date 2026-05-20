const fs = require('fs');

let api = fs.readFileSync('vylithra_mobile/lib/services/api_service.dart', 'utf8');

// Add model import
if (!api.includes("import '../models/story.dart';")) {
    api = api.replace("import '../models/post.dart';", "import '../models/post.dart';\nimport '../models/story.dart';");
}

const methods = `
  Future<List<StoryGroup>> fetchStoriesFeed() async {
    final List<dynamic> data = await get('/api/stories/feed');
    return data.map((json) => StoryGroup.fromJson(json)).toList();
  }

  Future<List<Story>> fetchUserStories(String userId) async {
    final List<dynamic> data = await get('/api/stories/user/$userId');
    return data.map((json) => Story.fromJson(json)).toList();
  }

  Future<dynamic> uploadStory(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/stories/upload'));
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['x-auth-token'] = token;
      }

      request.files.add(await http.MultipartFile.fromPath('storyMedia', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } on SocketException {
      throw Exception('Unable to connect to the server. Please check your internet connection.');
    }
  }
`;

if (!api.includes('fetchStoriesFeed()')) {
    api = api.replace('}\n\n', '}\n' + methods + '\n');
    fs.writeFileSync('vylithra_mobile/lib/services/api_service.dart', api);
    console.log('ApiService updated');
}
