import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<dynamic> _profileFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _profileFuture = _apiService.get('/api/users/profile').catchError((e) => null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

          // Dummy data fallback
          final profileData = (snapshot.hasData && snapshot.data != null) 
              ? snapshot.data 
              : {
                  'username': 'My Profile',
                  'bio': 'Welcome to my Vylithra page! ✨',
                  'followers': 1205,
                  'following': 150,
                };

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 80,
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
                                _buildStat('Followers', profileData['followers']?.toString() ?? '0'),
                                _buildStat('Following', profileData['following']?.toString() ?? '0'),
                                _buildStat('Posts', '0'),
                              ],
                            ),
                            const SizedBox(height: 24),
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

  Widget _buildStat(String label, String count) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
