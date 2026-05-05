import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'messages_screen.dart'; // To navigate to messages

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<dynamic> _profileFuture;
  final ApiService _apiService = ApiService();
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    final endpoint = widget.userId != null ? '/api/users/${widget.userId}' : '/api/users/profile';
    _profileFuture = _apiService.get(endpoint).catchError((e) => null);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to toggle follow: $e')));
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
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('No \${type} yet.'));
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMe = widget.userId == null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [const Color(0xFF0F172A), const Color(0xFF8B5CF6).withValues(alpha: 0.1), const Color(0xFF0F172A)]
            : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
        ),
      ),
      child: FutureBuilder<dynamic>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + (isMe ? 80 : 20),
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                sliver: SliverToBoxAdapter(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (!isMe)
                              Align(
                                alignment: Alignment.topLeft,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            const CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.person, size: 50, color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              profileData['username'] ?? 'User',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profileData['bio'] ?? '',
                              style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStat('Followers', (profileData['followers']?.length ?? 0).toString(), () => _showFollowModal('followers', displayId)),
                                _buildStat('Following', (profileData['following']?.length ?? 0).toString(), () => _showFollowModal('following', displayId)),
                                _buildStat('Posts', '0', null),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (isMe)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: () {},
                                  child: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isFollowing ? Colors.green : const Color(0xFFE11D48),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      onPressed: _toggleFollow,
                                      child: Text(_isFollowing ? 'Following' : 'Follow', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen()));
                                      },
                                      child: Text('Message', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Placeholder for user's posts grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                      );
                    },
                    childCount: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String count, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
