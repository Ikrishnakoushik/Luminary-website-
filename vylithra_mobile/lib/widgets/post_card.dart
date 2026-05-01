import 'package:flutter/material.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 21, // 42px diameter
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                backgroundImage: post.image != null ? NetworkImage(post.image!) : null,
                child: post.image == null ? const Icon(Icons.person, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              Text(
                post.authorName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Body
          Text(
            post.content,
            style: const TextStyle(fontSize: 15),
          ),
          
          // Image (if any)
          if (post.image != null) ...[
             const SizedBox(height: 12),
             ClipRRect(
               borderRadius: BorderRadius.circular(8),
               child: Image.network(
                 post.image!,
                 width: double.infinity,
                 fit: BoxFit.cover,
               ),
             )
          ],

          const SizedBox(height: 10),

          // Actions
          Row(
            children: [
              _buildActionButton(Icons.favorite_border),
              const SizedBox(width: 20),
              _buildActionButton(Icons.chat_bubble_outline),
              const SizedBox(width: 20),
              _buildActionButton(Icons.send_outlined),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon) {
    return InkWell(
      onTap: () {},
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Icon(icon, size: 26), // 1.4rem approx 22-26px
      ),
    );
  }
}
