import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late Future<List<Post>> _reelsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _reelsFuture = _apiService.fetchPosts(); // Assuming we use same feed for now, or you can add endpoint filtering
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Post>>(
      future: _reelsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No reels available.', style: TextStyle(color: Colors.white)));
        }

        // Filter for posts with images for a better reels-like experience
        final reels = snapshot.data!.where((p) => p.image != null).toList();

        if (reels.isEmpty) {
          return const Center(child: Text('No visual reels available.', style: TextStyle(color: Colors.white)));
        }

        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: reels.length,
          itemBuilder: (context, index) {
            // Re-use PostCard but force it to take full height
            return Container(
              height: MediaQuery.of(context).size.height,
              color: Colors.black, // Reels usually have black background
              child: Center(
                child: PostCard(post: reels[index]),
              ),
            );
          },
        );
      },
    );
  }
}
