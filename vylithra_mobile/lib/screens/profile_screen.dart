import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import 'messages_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<dynamic> _profileFuture;
  late Future<List<Post>> _postsFuture;
  final ApiService _apiService = ApiService();
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    final endpoint = widget.userId != null ? '/api/users/${widget.userId}' : '/api/users/profile';
    _profileFuture = _apiService.get(endpoint).catchError((e) => null);
    
    // We don't have the user ID instantly if viewing 'me', but we can fetch posts if we know it.
    _postsFuture = _profileFuture.then((profile) {
      if (profile != null && profile['_id'] != null) {
        return _apiService.fetchUserPosts(profile['_id']);
      }
      return <Post>[];
    });

    if (widget.userId != null) {
      _checkIfFollowing();
    }
  }

  Future<void> _checkIfFollowing() async {
    try {
      final List<dynamic> following = await _apiService.getFollowing('me');
      setState(() {
        _isFollowing = following.any((u) => u['_id'] == widget.userId);
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.userId == null) return;
    try {
      await _apiService.toggleFollow(widget.userId!, _isFollowing);
      setState(() {
        _isFollowing = !_isFollowing;
        _profileFuture = _apiService.get('/api/users/${widget.userId}').catchError((e) => null);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to toggle follow: $e')));
      }
    }
  }

  void _showFollowModal(String type, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(type == 'followers' ? 'Followers' : 'Following', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: type == 'followers' ? _apiService.getFollowers(userId) : _apiService.getFollowing(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('No $type yet.'));
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final u = snapshot.data![index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(u['username'] ?? 'User'),
                        onTap: () {
                           Navigator.pop(context);
                           Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: u['_id'])));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.lora(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMe = widget.userId == null;

    return FutureBuilder<dynamic>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final profileData = (snapshot.hasData && snapshot.data != null) 
            ? snapshot.data 
            : {
                'username': 'User',
                'bio': '',
                'followers': [],
                'following': [],
              };

        final String displayId = profileData['_id'] ?? widget.userId ?? 'me';
        final String username = profileData['username'] ?? 'User';

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              title: Text(username, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 26, color: isDark ? Colors.white : Colors.black)),
              actions: [
                if (isMe)
                  IconButton(
                    icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.black, size: 30),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.settings),
                                  title: const Text('Settings'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon!')));
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.logout, color: Colors.red),
                                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    final auth = Provider.of<AuthProvider>(context, listen: false);
                                    await auth.logout();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, _) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Avatar + Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Avatar with glowing effect
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8), width: 1.5),
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: Colors.black,
                                  backgroundImage: profileData['profilePicture'] != null && profileData['profilePicture'] != ''
                                      ? NetworkImage(profileData['profilePicture'].startsWith('/') ? 'https://www.vylithra.in${profileData['profilePicture']}' : profileData['profilePicture'])
                                      : null,
                                  child: profileData['profilePicture'] == null || profileData['profilePicture'] == '' 
                                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                                      : null,
                                ),
                              ),
                              // Stats Columns
                              Expanded(
                                child: FutureBuilder<List<Post>>(
                                  future: _postsFuture,
                                  builder: (context, postSnapshot) {
                                    final int postCount = postSnapshot.hasData ? postSnapshot.data!.length : 0;
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildStatColumn('Posts', postCount.toString(), null),
                                        _buildStatColumn('Followers', (profileData['followers']?.length ?? 0).toString(), () => _showFollowModal('followers', displayId)),
                                        _buildStatColumn('Following', (profileData['following']?.length ?? 0).toString(), () => _showFollowModal('following', displayId)),
                                      ],
                                    );
                                  }
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Display Name & Bio
                          Text(
                            profileData['displayName'] ?? username,
                            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          if (profileData['bio'] != null && profileData['bio'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              profileData['bio'],
                              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Action Buttons
                          if (isMe)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFDCD0C0)),
                                      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5ECE5),
                                    ),
                                    onPressed: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFDCD0C0)),
                                      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5ECE5),
                                    ),
                                    onPressed: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text('Share Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing ? Theme.of(context).scaffoldBackgroundColor : Theme.of(context).colorScheme.primary,
                                      foregroundColor: _isFollowing ? Theme.of(context).colorScheme.onSurface : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        side: BorderSide(color: _isFollowing ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2) : Colors.transparent),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _toggleFollow,
                                    child: Text(
                                      _isFollowing ? 'Following' : 'Follow', 
                                      style: GoogleFonts.lora(fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                                    ),
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen()));
                                    },
                                    child: Text('Message', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        indicatorColor: isDark ? Colors.white : Colors.black,
                        labelColor: isDark ? Colors.white : Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_view_rounded, size: 28)),
                          Tab(icon: Icon(Icons.filter_none, size: 28)),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: FutureBuilder<List<Post>>(
                future: _postsFuture,
                builder: (context, postSnapshot) {
                  if (postSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final posts = postSnapshot.data ?? [];
                  final imagePosts = posts.where((p) => p.image != null || p.videoUrl == null).toList();
                  final videoPosts = posts.where((p) => p.videoUrl != null).toList();

                  return TabBarView(
                    children: [
                      _buildGrid(imagePosts),
                      _buildGrid(videoPosts, isVideo: true),
                    ],
                  );
                }
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<Post> items, {bool isVideo = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isVideo ? Icons.videocam_off_outlined : Icons.photo_camera_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No ${isVideo ? 'Reels' : 'Posts'} Yet', style: GoogleFonts.lora(fontSize: 20, color: Colors.grey.withValues(alpha: 0.6))),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final post = items[index];
        final String? mediaUrl = isVideo ? post.videoUrl : post.image;
        
        return Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6F0), // Polaroid cream
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: mediaUrl != null
              ? Image.network(
                  mediaUrl.startsWith('/') ? 'https://www.vylithra.in$mediaUrl' : mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error, color: Colors.grey)),
                )
              : Center(child: Text(post.content, textAlign: TextAlign.center, style: GoogleFonts.lora(fontSize: 10, color: Theme.of(context).colorScheme.onSurface), maxLines: 3)),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF9F5F0), // Matching beige from screenshot
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
