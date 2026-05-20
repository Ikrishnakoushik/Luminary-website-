import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';
import '../models/story.dart';
import 'story_viewer_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../widgets/post_card.dart';
import '../services/api_service.dart';
import 'reels_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import 'create_reel_screen.dart';
import 'reels_camera_screen.dart';
import '../services/webrtc_service.dart';
import '../services/socket_service.dart';
import 'call_screen.dart';
import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int _currentIndex = 0;
  List<Post> _posts = [];
  List<StoryGroup> _storyGroups = [];
  bool _isLoadingStories = true;
  bool _isUploadingStory = false;
  bool _isLoadingPosts = true;
  String? _postsError;
  final ApiService _apiService = ApiService();
  late WebRTCService _webrtcService;
  final SocketService _socketService = SocketService();
  
  StreamSubscription? _newPostSub;
  StreamSubscription? _postLikedSub;
  StreamSubscription? _newCommentSub;
  int _newPostsCount = 0;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadStories();
    _loadPosts();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final res = await _apiService.get('/api/app/version');
      if (res != null && res['latestVersion'] != null) {
        final packageInfo = await PackageInfo.fromPlatform();
        if (packageInfo.version != res['latestVersion']) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Update Available'),
                content: Text(res['updateMessage'] ?? 'A new version is available.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final url = Uri.parse(res['apkUrl']);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Update'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      // Ignore errors silently
    }
  }

  Future<void> _loadStories() async {
    try {
      final groups = await _apiService.fetchStoriesFeed();
      if (mounted) setState(() { _storyGroups = groups; _isLoadingStories = false; });
    } catch(e) { if(mounted) setState(() => _isLoadingStories = false); }
  }

  Future<void> _loadPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_posts');
      if (cachedStr != null) {
        final List<dynamic> decoded = jsonDecode(cachedStr);
        if (mounted) {
          setState(() {
            _posts = decoded.map((j) => Post.fromJson(j)).toList();
            _isLoadingPosts = false;
          });
        }
      }
    } catch (e) {
      // Ignore cache errors
    }

    try {
      final posts = await _apiService.fetchPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoadingPosts = false;
          _postsError = null;
        });
      }
      final prefs = await SharedPreferences.getInstance();
      final rawData = await _apiService.get('/api/posts');
      prefs.setString('cached_posts', jsonEncode(rawData));
    } catch (e) {
      if (mounted) {
        setState(() {
          _postsError = e.toString();
          if (_posts.isEmpty) _isLoadingPosts = false;
        });
      }
    }
  }


  void _initServices() {
    _webrtcService = WebRTCService();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final data = jsonDecode(payload);
          final userId = data['user']?['id'];
          if (userId != null) {
            SharedPreferences.getInstance().then((prefs) => prefs.setString('current_user_id', userId));
            
            // Connect Global Socket
            _socketService.connect(userId);
            
            // Initialize WebRTC
            _webrtcService.initialize(userId);
            _webrtcService.onIncomingCall = (incomingData) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      webrtcService: _webrtcService,
                      isIncoming: true,
                      targetUserId: incomingData['from'],
                      targetUsername: 'Incoming Call',
                      isVideoCall: incomingData['isVideo'] ?? false,
                      incomingData: incomingData,
                    ),
                  ),
                );
              }
            };
            
            // Listen to real-time feed events
            _setupRealTimeFeedListeners();
          }
        }
      } catch (e) {
        // ignore
      }
    }
  }

  void _setupRealTimeFeedListeners() {
    _newPostSub = _socketService.onNewPost.listen((postData) {
      if (mounted) {
        setState(() {
          _newPostsCount++;
        });
      }
    });

    _postLikedSub = _socketService.onPostLiked.listen((data) {
      final postId = data['postId'];
      final likes = List<String>.from(data['likes']);
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == postId);
          if (index != -1) {
            _posts[index].likes = likes;
          }
        });
      }
    });

    _newCommentSub = _socketService.onNewComment.listen((data) {
      final postId = data['postId'];
      final comments = List<dynamic>.from(data['comments']);
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == postId);
          if (index != -1) {
            // Simplified: we just update the comments list length if needed, 
            // since the Post model usually holds the comments list.
            // (Assuming Post model has comments or we just refresh data)
            _posts[index].comments = comments;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _newPostSub?.cancel();
    _postLikedSub?.cancel();
    _newCommentSub?.cancel();
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Solid Vintage Background
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          
          // Main Content Area
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildFeedView(),
              const ReelsScreen(),
              const MessagesScreen(),
              const ProfileScreen(),
            ],
          ),

          // Custom Edge-to-Edge Glass Header Overlay (Only on Home tab)
          if (_currentIndex == 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildGlassHeader(isDark),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildGlassHeader(bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 15,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark 
                ? [Colors.black.withValues(alpha: 0.4), Colors.black.withValues(alpha: 0.1)] 
                : [Colors.white.withValues(alpha: 0.6), Colors.white.withValues(alpha: 0.2)],
            ),
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 28,
                color: isDark ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 10),
              const Text(
                'Vylithra',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  
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

  Widget _buildFeedView() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _newPostsCount = 0);
        await _loadStories();
        await _loadPosts();
      },
      child: _isLoadingPosts 
        ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
        : _posts.isEmpty 
          ? Center(child: Text(_postsError != null ? 'Error: $_postsError' : 'No posts available.', style: TextStyle(color: _postsError != null ? Colors.red : Colors.grey)))
          : Stack(
              children: [
                ListView.builder(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 70, 
                    bottom: 100,
                  ),
                  itemCount: _posts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildStoryRail();
                    return PostCard(post: _posts[index - 1], storyGroups: _storyGroups);
                  },
                ),
                if (_newPostsCount > 0)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _newPostsCount = 0);
                          _loadPosts();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            '$_newPostsCount New Posts',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }


  Widget _buildBottomNav(bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
        child: Container(
          height: 65 + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.6),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(Icons.home_filled, 0, isDark),
                _navItem(Icons.play_circle_outline, 1, isDark),
                _uploadItem(isDark), // Central Upload Button
                _navItem(Icons.send_outlined, 2, isDark),
                _navItem(Icons.person_outline, 3, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _uploadItem(bool isDark) {
    return Expanded(
      child: InkWell(
        onTap: _showUploadOptions,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.add,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildUploadOption(
              icon: Icons.post_add,
              title: 'Create Post',
              subtitle: 'Share text and images with your followers',
              color: Colors.blue,
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
                if (result == true) {
                  _loadPosts();
                }
              },
            ),
            const SizedBox(height: 16),
            _buildUploadOption(
              icon: Icons.video_call,
              title: 'Create Reel',
              subtitle: 'Upload a video with editing tools',
              color: Colors.purple,
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateReelScreen()));
                if (result == true) {
                  _loadPosts(); // Reels also show up in posts feed
                }
              },
            ),
            const SizedBox(height: 16),
            _buildUploadOption(
              icon: Icons.camera_front,
              title: 'Record Reel (ML)',
              subtitle: 'Real-time background changing camera',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelsCameraScreen())); 
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, bool isDark) {
    final isActive = _currentIndex == index;
    
    // Smooth transition for icons
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform: Matrix4.diagonal3Values(
              isActive ? 1.15 : 1.0,
              isActive ? 1.15 : 1.0,
              1.0,
            ),
            child: Icon(
              icon,
              size: 28,
              color: isActive 
                  ? Theme.of(context).colorScheme.primary // Sepia/Copper accent
                  : (isDark ? Colors.white38 : Colors.black45),
            ),
          ),
        ),
      ),
    );
  }
}
