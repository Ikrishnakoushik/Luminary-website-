import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (post.image != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 2), // small separator
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 450,
          maxHeight: 650,
        ),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(post.image!),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Gradient Scrim for readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 300,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black87,
                      Colors.black54,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content overlaid
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildActionButton(Icons.favorite_border, true, isDark),
                      const SizedBox(width: 24),
                      _buildActionButton(Icons.chat_bubble_outline, true, isDark),
                      const SizedBox(width: 24),
                      _buildActionButton(Icons.send_outlined, true, isDark),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // No image fallback (text only)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      post.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(post.content, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildActionButton(Icons.favorite_border, false, isDark),
                    const SizedBox(width: 24),
                    _buildActionButton(Icons.chat_bubble_outline, false, isDark),
                    const SizedBox(width: 24),
                    _buildActionButton(Icons.send_outlined, false, isDark),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, bool overlayOnImage, bool isDark) {
    return InkWell(
      onTap: () {},
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Icon(
        icon,
        size: 28,
        color: overlayOnImage 
          ? Colors.white 
          : (isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }
}
