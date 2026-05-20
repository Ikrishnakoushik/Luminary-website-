import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';

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

  // Design Colors matching the exact vintage design
  final Color bgColor = const Color(0xFFF8F6EB);
  final Color darkTextColor = const Color(0xFF3E2723);
  final Color lightTextColor = const Color(0xFF5D4037);
  final Color buttonBgColor = const Color(0xFF4A3B31); // Dark Brown
  final Color buttonBorderColor = const Color(0xFF4A3B31);
  final Color avatarBorderColor = const Color(0xFF8E6A4B); // Lighter brown for border

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

  Widget _buildStatColumn(String count, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, fontSize: 24, color: darkTextColor, height: 1.0)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.playfairDisplay(fontSize: 14, color: darkTextColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: const Color(0xFFDCD4C6), // Light separator color
      margin: const EdgeInsets.symmetric(horizontal: 10),
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
        final String displayName = profileData['displayName'] ?? username;
        final String cleanHandle = '@${username.toLowerCase().replaceAll(" ", "")}';

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: bgColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(cleanHandle, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: darkTextColor)),
              actions: [
                if (isMe)
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black, size: 28),
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
                                    Navigator.pop(context); // close bottom sheet
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                                    );
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
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top Row: Follow Button - Avatar - Message Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Follow Button
                              if (!isMe)
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing ? Colors.transparent : buttonBgColor,
                                      foregroundColor: _isFollowing ? buttonBgColor : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: _isFollowing ? buttonBorderColor : Colors.transparent, width: 2),
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: _toggleFollow,
                                    child: Text(
                                      _isFollowing ? 'FOLLOWING' : 'FOLLOW', 
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: buttonBgColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: () {},
                                    child: Text('EDIT', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
                                  ),
                                ),
                              
                              const SizedBox(width: 15),
                              
                              // Avatar
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: avatarBorderColor, width: 2.5),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: avatarBorderColor,
                                  backgroundImage: profileData['profilePicture'] != null && profileData['profilePicture'] != ''
                                      ? NetworkImage(profileData['profilePicture'].startsWith('/') ? 'https://www.vylithra.in' + profileData['profilePicture'].toString() : profileData['profilePicture'])
                                      : null,
                                  child: profileData['profilePicture'] == null || profileData['profilePicture'] == '' 
                                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                                      : null,
                                ),
                              ),
                              
                              const SizedBox(width: 15),

                              // Message Button
                              if (!isMe)
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      side: BorderSide(color: buttonBorderColor, width: 2),
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen()));
                                    },
                                    child: Text('MESSAGE', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: buttonBgColor, letterSpacing: 0.5)),
                                  ),
                                )
                              else
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      side: BorderSide(color: buttonBorderColor, width: 2),
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: () {},
                                    child: Text('SHARE', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: buttonBgColor, letterSpacing: 0.5)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          // Display Name & Handle
                          Text(
                            displayName,
                            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, fontSize: 26, color: darkTextColor, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cleanHandle,
                            style: GoogleFonts.inter(fontSize: 13, color: lightTextColor, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 12),
                          
                          // Bio
                          if (profileData['bio'] != null && profileData['bio'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Text(
                                profileData['bio'],
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(fontSize: 15, color: darkTextColor, height: 1.4),
                              ),
                            ),
                          
                          const SizedBox(height: 25),
                          
                          // Stats Row
                          FutureBuilder<List<Post>>(
                            future: _postsFuture,
                            builder: (context, postSnapshot) {
                              final int postCount = postSnapshot.hasData ? postSnapshot.data!.length : 0;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildStatColumn(postCount.toString(), 'Posts', null),
                                  _buildVerticalDivider(),
                                  _buildStatColumn((profileData['followers']?.length ?? 0).toString(), 'Followers', () => _showFollowModal('followers', displayId)),
                                  _buildVerticalDivider(),
                                  _buildStatColumn((profileData['following']?.length ?? 0).toString(), 'Following', () => _showFollowModal('following', displayId)),
                                ],
                              );
                            }
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
                          border: const Border(
                            bottom: BorderSide(color: Color(0xFFDCD4C6), width: 1.5),
                          ),
                        ),
                        child: TabBar(
                          indicatorColor: buttonBgColor,
                          indicatorWeight: 3,
                          labelColor: buttonBgColor,
                          unselectedLabelColor: lightTextColor,
                          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                          tabs: const [
                            Tab(text: 'PHOTOS'),
                            Tab(text: 'TAGGED'),
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
              color: lightTextColor
            ),
            const SizedBox(height: 10),
            Text(
              isVideo ? 'No Reels Yet' : 'No Posts Yet', 
              style: GoogleFonts.playfairDisplay(fontSize: 22, color: lightTextColor)
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 15,
        childAspectRatio: 0.8, // Make polaroid taller
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final post = items[index];
        final String? mediaUrl = isVideo ? post.videoUrl : post.image;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
          child: Stack(
            children: [
              // Media
              Positioned.fill(
                child: Container(
                  color: const Color(0xFFE0E0E0),
                  child: mediaUrl != null
                    ? Image.network(
                        mediaUrl.startsWith('/') ? 'https://www.vylithra.in$mediaUrl' : mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error, color: Colors.grey)),
                      )
                    : Center(child: Text(post.content, textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontSize: 10, color: darkTextColor), maxLines: 3)),
                ),
              ),
              
              // Dark corners
              Positioned(top: 0, left: 0, child: _buildPhotoCorner(true, true)),
              Positioned(top: 0, right: 0, child: _buildPhotoCorner(true, false)),
              Positioned(bottom: 0, left: 0, child: _buildPhotoCorner(false, true)),
              Positioned(bottom: 0, right: 0, child: _buildPhotoCorner(false, false)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoCorner(bool isTop, bool isLeft) {
    // A simple triangle drawing for corners
    return CustomPaint(
      size: const Size(12, 12),
      painter: CornerPainter(isTop: isTop, isLeft: isLeft),
    );
  }
}

class CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  
  CornerPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2A2018)..style = PaintingStyle.fill;
    final path = Path();
    
    if (isTop && isLeft) {
      path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(0, size.height);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0); path.lineTo(0, size.height); path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0); path.lineTo(size.width, size.height); path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
