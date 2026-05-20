const fs = require('fs');

let home = fs.readFileSync('vylithra_mobile/lib/screens/home_screen.dart', 'utf8');

// Imports
if (!home.includes("import '../models/story.dart';")) {
    home = home.replace("import '../models/post.dart';", "import '../models/post.dart';\nimport '../models/story.dart';\nimport 'story_viewer_screen.dart';\nimport 'package:image_picker/image_picker.dart';\nimport 'package:cached_network_image/cached_network_image.dart';\nimport 'dart:io';");
}

// State variables
if (!home.includes("List<StoryGroup> _storyGroups = [];")) {
    home = home.replace("List<Post> _posts = [];", "List<Post> _posts = [];\n  List<StoryGroup> _storyGroups = [];\n  bool _isLoadingStories = true;\n  bool _isUploadingStory = false;");
}

// _loadPosts to _loadData
if (!home.includes("await _loadStories();")) {
    home = home.replace("Future<void> _loadPosts() async {", "Future<void> _loadStories() async {\n    try {\n      final groups = await _apiService.fetchStoriesFeed();\n      if (mounted) setState(() { _storyGroups = groups; _isLoadingStories = false; });\n    } catch(e) { if(mounted) setState(() => _isLoadingStories = false); }\n  }\n\n  Future<void> _loadPosts() async {");
    
    // Add _loadStories to initState and onRefresh
    home = home.replace("super.initState();\n    _loadPosts();", "super.initState();\n    _loadStories();\n    _loadPosts();");
    home = home.replace("await _loadPosts();", "await _loadStories();\n        await _loadPosts();");
}

// Build Feed View
const storyRailWidget = `
  Widget _buildStoryRail() {
    if (_isLoadingStories && _storyGroups.isEmpty) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    }
    
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?['id'];
    
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _storyGroups.length + 1,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            // My Story (Add)
            return GestureDetector(
              onTap: _pickAndUploadStory,
              child: Container(
                width: 72,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          height: 68,
                          width: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
                          ),
                          child: _isUploadingStory 
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.add, color: Colors.grey, size: 30),
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Your Story', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          }
          
          final group = _storyGroups[index - 1];
          final allViewed = group.stories.every((s) => s.viewers.contains(currentUserId));
          
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerScreen(
                stories: group.stories,
                userName: group.userName,
                userProfilePicture: group.userProfilePicture,
                onComplete: () {
                  if (mounted) setState(() {});
                },
              )));
            },
            child: Container(
              width: 72,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    height: 68,
                    width: 68,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: allViewed ? null : const LinearGradient(
                        colors: [Colors.purple, Colors.orange],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      border: allViewed ? Border.all(color: Colors.grey.withOpacity(0.3), width: 2) : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                      ),
                      child: CircleAvatar(
                        backgroundImage: group.userProfilePicture.isNotEmpty 
                          ? CachedNetworkImageProvider(group.userProfilePicture)
                          : null,
                        backgroundColor: Colors.grey[800],
                        child: group.userProfilePicture.isEmpty 
                          ? Text(group.userName.isNotEmpty ? group.userName[0].toUpperCase() : 'U')
                          : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(group.userName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _pickAndUploadStory() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _isUploadingStory = true);
      try {
        await _apiService.uploadStory(File(pickedFile.path));
        await _loadStories();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        if (mounted) setState(() => _isUploadingStory = false);
      }
    }
  }
`;

if (!home.includes('_buildStoryRail()')) {
    home = home.replace("Widget _buildFeedView() {", storyRailWidget + "\n  Widget _buildFeedView() {");
    
    // Inject story rail into ListView
    home = home.replace(
        "itemCount: _posts.length,",
        "itemCount: _posts.length + 1,"
    );
    
    home = home.replace(
        "return PostCard(post: _posts[index]);",
        "if (index == 0) return _buildStoryRail();\n                return PostCard(post: _posts[index - 1], storyGroups: _storyGroups);"
    );
    
    fs.writeFileSync('vylithra_mobile/lib/screens/home_screen.dart', home);
    console.log('HomeScreen updated for Stories');
}
