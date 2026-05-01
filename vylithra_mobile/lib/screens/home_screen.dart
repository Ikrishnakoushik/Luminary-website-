import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../services/api_service.dart';

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
      extendBody: true, // Crucial for bottom nav blur effect
      appBar: AppBar(
        title: const Text('Vylithra', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0, // Prevents Material 3 scroll tint
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
            height: 1,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: FutureBuilder<List<Post>>(
          future: _postsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No stories available.'));
            }

            final posts = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // Padding for bottom nav
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return PostCard(post: posts[index]);
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          height: 60 + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark 
                ? [const Color(0xCC0F172A), const Color(0xF20A0F1E)] // Dark mode gradient
                : [const Color(0xCCFFFFFF), const Color(0xF2E2EEFF)], // Light mode gradient
            ),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
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
                _navItem(Icons.send_outlined, 2, isDark),
                _navItem(Icons.person_outline, 3, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, bool isDark) {
    final isActive = _currentIndex == index;
    
    // Colors from the CSS
    final activeColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF4A5568);
    final inactiveColor = const Color(0xFFA0A8B9);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Center(
          child: Icon(
            icon,
            size: 28, // 1.65rem
            color: isActive ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }
}
