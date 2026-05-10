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

  // Design Colors
  final Color bgColor = const Color(0xFFF8F4EF);
  final Color darkTextColor = const Color(0xFF332211);
  final Color lightTextColor = const Color(0xFFBDB5B0);
  final Color buttonBgColor = const Color(0xFFF2E6DB);
  final Color buttonBorderColor = const Color(0xFFE6D8CC);
  final Color orangeBorderColor = const Color(0xFFDE7336);

  @override
  void initState() {
    super.initState();
    final endpoint = widget.userId != null ? '/api/users/${widget.userId}' : '/api/users/profile';
    _profileFuture = _apiService.get(endpoint).catchError((e) => null);
    
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
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(type == 'followers' ? 'Followers' : 'Following', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: darkTextColor)),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: type == 'followers' ? _apiService.getFollowers(userId) : _apiService.getFollowing(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('No $type yet.', style: TextStyle(color: darkTextColor)));
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final u = snapshot.data![index];
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.black, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(u['username'] ?? 'User', style: TextStyle(color: darkTextColor)),
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
          Text(count, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w900, fontSize: 18, color: darkTextColor)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.lora(fontSize: 13, color: lightTextColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMe = widget.userId == null;

    return FutureBuilder<dynamic>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
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
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: bgColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              title: Text(username, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w900, fontSize: 26, color: Colors.black)),
              actions: [
                if (isMe)
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black, size: 32),
                    padding: const EdgeInsets.only(right: 16),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: Icon(Icons.settings, color: darkTextColor),
                                  title: Text('Settings', style: TextStyle(color: darkTextColor)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Avatar + Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Avatar with orange outer ring
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: orangeBorderColor, width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: Colors.black,
                                  backgroundImage: profileData['profilePicture'] != null && profileData['profilePicture'] != ''
                                      ? NetworkImage(profileData['profilePicture'].startsWith('/') ? 'https://www.vylithra.in${profileData['profilePicture']}' : profileData['profilePicture'])
                                      : null,
                                  child: profileData['profilePicture'] == null || profileData['profilePicture'] == '' 
                                      ? const Icon(Icons.person, size: 45, color: Colors.white)
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
                          const SizedBox(height: 16),
                          // Display Name & Bio
                          Text(
                            profileData['displayName'] ?? username,
                            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, fontSize: 18, color: darkTextColor),
                          ),
                          if (profileData['bio'] != null && profileData['bio'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              profileData['bio'],
                              style: TextStyle(fontSize: 14, color: darkTextColor),
                            ),
                          ],
                          const SizedBox(height: 20),
                          // Action Buttons
                          if (isMe)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      side: BorderSide(color: buttonBorderColor, width: 1),
                                      backgroundColor: buttonBgColor,
                                      elevation: 0,
                                    ),
                                    onPressed: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Text('Edit Profile', style: GoogleFonts.lora(fontWeight: FontWeight.w700, fontSize: 15, color: darkTextColor)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      side: BorderSide(color: buttonBorderColor, width: 1),
                                      backgroundColor: buttonBgColor,
                                      elevation: 0,
                                    ),
                                    onPressed: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Text('Share Profile', style: GoogleFonts.lora(fontWeight: FontWeight.w700, fontSize: 15, color: darkTextColor)),
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
                                      backgroundColor: _isFollowing ? bgColor : darkTextColor,
                                      foregroundColor: _isFollowing ? darkTextColor : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: _isFollowing ? buttonBorderColor : Colors.transparent),
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: _toggleFollow,
                                    child: Text(
                                      _isFollowing ? 'Following' : 'Follow', 
                                      style: GoogleFonts.lora(fontWeight: FontWeight.w700, fontSize: 15)
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      side: BorderSide(color: buttonBorderColor, width: 1),
                                      backgroundColor: buttonBgColor,
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen()));
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Text('Message', style: GoogleFonts.lora(fontWeight: FontWeight.w700, fontSize: 15, color: darkTextColor)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border(
                            top: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                          ),
                        ),
                        child: TabBar(
                          indicatorColor: Colors.black,
                          indicatorWeight: 2,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey.withValues(alpha: 0.6),
                          tabs: const [
                            Tab(icon: Icon(Icons.grid_view_rounded, size: 28)),
                            Tab(icon: Icon(Icons.filter_none, size: 26)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: Container(
                color: bgColor,
                child: FutureBuilder<List<Post>>(
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
                        _buildGrid(imagePosts, false),
                        _buildGrid(videoPosts, true),
                      ],
                    );
                  }
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<Post> items, bool isVideo) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.videocam_outlined : Icons.camera_alt_outlined, 
              size: 80, 
              color: const Color(0xFFC4BCB4)
            ),
            const SizedBox(height: 10),
            Text(
              'No ${isVideo ? 'Reels' : 'Posts'} Yet', 
              style: GoogleFonts.lora(fontSize: 22, color: const Color(0xFFC4BCB4))
            ),
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
          color: Colors.white,
          child: mediaUrl != null
              ? Image.network(
                  mediaUrl.startsWith('/') ? 'https://www.vylithra.in$mediaUrl' : mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error, color: Colors.grey)),
                )
              : Center(child: Text(post.content, textAlign: TextAlign.center, style: GoogleFonts.lora(fontSize: 10, color: darkTextColor), maxLines: 3)),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._child);

  final Widget _child;

  @override
  double get minExtent => 48.0;
  @override
  double get maxExtent => 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
