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
  bool _showHeartAnimation = false;

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
  }

  void _handleDoubleTapLike() {
    setState(() {
      _isLiked = true;
      _showHeartAnimation = true;
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
      }
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

    if (widget.post.image != null) {
      return GestureDetector(
        onDoubleTap: _handleDoubleTapLike,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2), // small separator
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 450,
            maxHeight: 650,
          ),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(widget.post.image!),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Enhanced Gradient Scrim for readability
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 400,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black,
                        Colors.black87,
                        Colors.black54,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              
              // Double Tap Heart Animation
              if (_showHeartAnimation)
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: val,
                      child: Opacity(
                        opacity: val < 0.9 ? val : 1.0 - ((val - 0.9) * 10),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 100,
                        ),
                      ),
                    );
                  },
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
                          widget.post.authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 10),
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.post.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 10),
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildLikeButton(true, isDark),
                        const SizedBox(width: 24),
                        _buildActionButton(
                          Icons.chat_bubble_outline, 
                          true, 
                          isDark, 
                          () => _showActionMessage('Comments coming soon!'),
                        ),
                        const SizedBox(width: 24),
                        _buildActionButton(
                          Icons.send_outlined, 
                          true, 
                          isDark,
                          () => _showActionMessage('Share menu opened!'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                      widget.post.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(widget.post.content, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildLikeButton(false, isDark),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      Icons.chat_bubble_outline, 
                      false, 
                      isDark,
                      () => _showActionMessage('Comments coming soon!'),
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      Icons.send_outlined, 
                      false, 
                      isDark,
                      () => _showActionMessage('Share menu opened!'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton(bool overlayOnImage, bool isDark) {
    return InkWell(
      onTap: _toggleLike,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _isLiked ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(_isLiked),
          size: 28,
          color: _isLiked 
              ? Colors.redAccent 
              : (overlayOnImage ? Colors.white : (isDark ? Colors.white70 : Colors.black54)),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, bool overlayOnImage, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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
