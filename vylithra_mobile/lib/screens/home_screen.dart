import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../services/api_service.dart';
import 'reels_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import 'create_reel_screen.dart';
import 'reels_camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late Future<List<Post>> _postsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _postsFuture = _apiService.fetchPosts();
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _postsFuture = _apiService.fetchPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dynamic Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFF0FDFA), const Color(0xFFE6F8F5)],
                stops: isDark ? [0.0, 1.0] : [0.0, 1.0],
              ),
            ),
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

          // Custom Edge-to-Edge Glass Header Overlay
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
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5),
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

  Widget _buildFeedView() {
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: FutureBuilder<List<Post>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No stories available.'));
          }

          final posts = snapshot.data!;
          return ListView.builder(
            // Padding to ensure content isn't hidden under header or bottom nav
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 70, 
              bottom: 100,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return PostCard(post: posts[index]);
            },
          );
        },
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
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
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
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
              },
            ),
            const SizedBox(height: 16),
            _buildUploadOption(
              icon: Icons.video_call,
              title: 'Create Reel',
              subtitle: 'Upload a video with editing tools',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateReelScreen())); 
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
                  ? const Color(0xFF3B82F6) // Vibrant Blue
                  : (isDark ? Colors.white38 : Colors.black45),
            ),
          ),
        ),
      ),
    );
  }
}
