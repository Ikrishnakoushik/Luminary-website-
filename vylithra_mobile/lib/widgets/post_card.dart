
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/story.dart';
import '../screens/story_viewer_screen.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final List<StoryGroup>? storyGroups;

  const PostCard({super.key, required this.post, this.storyGroups});

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
    final cardColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final iconColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(2, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP: User Profile Info
                Row(
                  children: [
                    
                    Builder(builder: (context) {
                      final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUserId;
                      final authorId = widget.post.userId;
                      
                      StoryGroup? group;
                      if (widget.storyGroups != null && authorId != null) {
                        try {
                           group = widget.storyGroups!.firstWhere((g) => g.userId == authorId);
                        } catch(e) {}
                      }
                      
                      final bool hasActiveStory = group != null && !group.stories.every((s) => s.viewers.contains(currentUserId));
                      
                      Widget avatarWidget = CircleAvatar(
                        radius: 20,
                        backgroundImage: widget.post.authorProfilePicture.isNotEmpty 
                          ? CachedNetworkImageProvider(widget.post.authorProfilePicture)
                          : null,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: widget.post.authorProfilePicture.isEmpty 
                          ? Text(widget.post.authorName.isNotEmpty ? widget.post.authorName[0].toUpperCase() : 'U')
                          : null,
                      );
                      
                      if (hasActiveStory) {
                         avatarWidget = Container(
                           padding: const EdgeInsets.all(2),
                           decoration: const BoxDecoration(
                             shape: BoxShape.circle,
                             gradient: LinearGradient(
                               colors: [Colors.purple, Colors.orange],
                               begin: Alignment.topRight,
                               end: Alignment.bottomLeft,
                             ),
                           ),
                           child: Container(
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                             ),
                             child: avatarWidget,
                           ),
                         );
                      }
                      
                      return GestureDetector(
                        onTap: () {
                          if (group != null) {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerScreen(
                               stories: group!.stories,
                               userName: group.userName,
                               userProfilePicture: group.userProfilePicture,
                               onComplete: () { if(mounted) setState((){}); },
                             )));
                          } else {
                             // Go to profile
                             // Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: authorId)));
                          }
                        },
                        child: avatarWidget,
                      );
                    }),

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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
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
