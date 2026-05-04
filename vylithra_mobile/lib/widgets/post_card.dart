import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/post.dart';

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
  }

  void _showActionMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Brand Palette
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
    final textColor = isDark ? Colors.white : const Color(0xFF134E4A);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF115E59).withValues(alpha: 0.7);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF115E59);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF14B8A6).withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: isDark ? ImageFilter.blur(sigmaX: 10, sigmaY: 10) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP: User Profile Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark ? Colors.white12 : const Color(0xFF14B8A6).withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: isDark ? Colors.white54 : const Color(0xFF14B8A6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.post.authorName,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Just now", // Placeholder for timestamp
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_horiz, color: iconColor),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. MIDDLE: Cover Image (if exists)
                if (widget.post.image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      widget.post.image!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: isDark ? Colors.white12 : Colors.black12,
                        child: const Center(child: Icon(Icons.image_not_supported)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. TEXT CONTEXT
                Text(
                  widget.post.content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),

                // 4. BOTTOM: Interactive Actions
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionItem(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.redAccent : iconColor,
                        label: 'Like',
                        onTap: _toggleLike,
                        textColor: subTextColor,
                      ),
                      _buildActionItem(
                        icon: Icons.chat_bubble_outline,
                        color: iconColor,
                        label: 'Comment',
                        onTap: () => _showActionMessage('Comments coming soon!'),
                        textColor: subTextColor,
                      ),
                      _buildActionItem(
                        icon: Icons.share_outlined,
                        color: iconColor,
                        label: 'Share',
                        onTap: () => _showActionMessage('Share menu opened!'),
                        textColor: subTextColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
