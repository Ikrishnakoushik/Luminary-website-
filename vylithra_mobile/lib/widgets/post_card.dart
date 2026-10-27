import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post.dart';
import '../models/story.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/profile_screen.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../screens/edit_post_screen.dart';
import 'comment_sheet.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final List<StoryGroup>? storyGroups;

  const PostCard({super.key, required this.post, this.storyGroups});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUserId;
      if (currentUserId != null && widget.post.likes.contains(currentUserId)) {
        if (mounted) setState(() => _isLiked = true);
      }
    });
  }

  void _toggleLike() async {
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUserId;
    if (currentUserId == null) return;

    final prevLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        if (!widget.post.likes.contains(currentUserId)) {
          widget.post.likes.add(currentUserId);
        }
      } else {
        widget.post.likes.remove(currentUserId);
      }
    });

    try {
      final updatedLikes = await ApiService().toggleLikePost(widget.post.id);
      if (mounted) {
        setState(() {
          widget.post.likes = updatedLikes;
          _isLiked = updatedLikes.contains(currentUserId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = prevLiked;
          if (_isLiked) {
            if (!widget.post.likes.contains(currentUserId)) {
              widget.post.likes.add(currentUserId);
            }
          } else {
            widget.post.likes.remove(currentUserId);
          }
        });
        _showActionMessage('Failed to like post.');
      }
    }
  }

  void _toggleSave() async {
    final prev = _isSaved;
    setState(() {
      _isSaved = !_isSaved;
    });
    try {
      final isSaved = await ApiService().toggleSavePost(widget.post.id);
      setState(() {
        _isSaved = isSaved;
      });
      _showActionMessage(isSaved ? 'Post saved!' : 'Post removed from saved.');
    } catch (e) {
      setState(() {
        _isSaved = prev;
      });
      _showActionMessage('Failed to save post.');
    }
  }

  void _showActionMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPostOptions() {
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUserId;
    final isMe =
        currentUserId != null &&
        widget.post.userId.isNotEmpty &&
        currentUserId == widget.post.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF8F6EB);
        final textColor = isDark ? Colors.white : const Color(0xFF3E2723);

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.share_outlined, color: textColor),
                  title: Text(
                    'Share Post',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Check out this post by ${widget.post.authorName} on Vylithra: ${widget.post.content}',
                      ),
                    );
                  },
                ),
                if (!isMe)
                  ListTile(
                    leading: const Icon(
                      Icons.report_outlined,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Report Post',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet first
                      _showReportDialog();
                    },
                  ),
                if (isMe) ...[
                  ListTile(
                    leading: Icon(Icons.edit_outlined, color: textColor),
                    title: Text(
                      'Edit Post',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditPostScreen(post: widget.post),
                        ),
                      );
                      if (result == true && mounted) {
                        setState(() {}); // refresh post UI
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Post',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final reportReasons = [
      {
        'title': 'Hate Speech & Discrimination',
        'act': 'Violates IT Act Sec 66A / 153A IPC',
      },
      {
        'title': 'Harassment or Bullying',
        'act': 'Violates IT Act Sec 67 & IPC 509',
      },
      {'title': 'Obscene or Nudity', 'act': 'Violates IT Act Sec 67, 67A'},
      {'title': 'Child Exploitation', 'act': 'Violates POCSO Act / IT Act 67B'},
      {'title': 'Privacy Violation', 'act': 'Violates IT Act Sec 66E'},
      {'title': 'Identity Theft', 'act': 'Violates IT Act Sec 66C'},
      {'title': 'Defamation', 'act': 'Violates IPC Sec 499 & 500'},
      {
        'title': 'Fake News & Misinformation',
        'act': 'Violates IPC Sec 505 / IT Rules',
      },
      {
        'title': 'Cyber Extortion & Blackmail',
        'act': 'Violates IPC Sec 384 & 503',
      },
      {'title': 'Voyeurism', 'act': 'Violates IPC Sec 354C'},
      {'title': 'Cyber Stalking', 'act': 'Violates IPC Sec 354D'},
      {
        'title': 'Copyright Infringement',
        'act': 'Violates DMCA Title 17 / Copyright Act',
      },
      {'title': 'Terrorism or Illegal Acts', 'act': 'Violates IT Act Sec 66F'},
      {'title': 'Spam or Scam', 'act': 'Violates IT Act Sec 66D'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF8F6EB),
        title: Text(
          'Why are you reporting this post?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF3E2723),
            fontSize: 18,
          ),
        ),
        contentPadding: const EdgeInsets.only(top: 12),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: reportReasons.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: Colors.grey),
            itemBuilder: (context, index) {
              final reason = reportReasons[index];
              return ListTile(
                title: Text(
                  reason['title']!,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  reason['act']!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context); // Close dialog
                  try {
                    // Send report to backend
                    await ApiService().post(
                      '/api/posts/${widget.post.id}/report',
                      {'reason': reason['title']},
                    );
                    if (mounted) {
                      _showActionMessage(
                        'Report submitted. We will review this post.',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      _showActionMessage(
                        'You have already reported this post or an error occurred.',
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF8F6EB),
        title: Text(
          'Delete Post',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF3E2723),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService().delete('/api/posts/${widget.post.id}');
                if (mounted) {
                  _showActionMessage('Post deleted successfully');
                  // Trigger a refresh somehow if needed
                }
              } catch (e) {
                if (mounted) _showActionMessage('Error deleting post');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.1);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
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
          ),
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
                  Builder(
                    builder: (context) {
                      final currentUserId = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).currentUserId;
                      final authorId = widget.post.userId;

                      StoryGroup? group;
                      if (widget.storyGroups != null) {
                        try {
                          group = widget.storyGroups!.firstWhere(
                            (g) => g.userId == authorId,
                          );
                        } catch (e) {
                          // Handled: author has no story group
                        }
                      }

                      final bool hasActiveStory =
                          group != null &&
                          !group.stories.every(
                            (s) => s.viewers.contains(currentUserId),
                          );

                      Widget avatarWidget = CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            widget.post.authorProfilePicture.isNotEmpty
                            ? NetworkImage(widget.post.authorProfilePicture)
                            : null,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        child: widget.post.authorProfilePicture.isEmpty
                            ? Text(
                                widget.post.authorName.isNotEmpty
                                    ? widget.post.authorName[0].toUpperCase()
                                    : 'U',
                              )
                            : null,
                      );

                      if (hasActiveStory) {
                        avatarWidget = Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF8E6A4B), Color(0xFF4A3B31)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: avatarWidget,
                          ),
                        );
                      }

                      if (widget.post.isAnonymous) {
                        avatarWidget = CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.person_off,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: widget.post.isAnonymous
                            ? null
                            : () {
                                if (group != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StoryViewerScreen(
                                        stories: group!.stories,
                                        userName: group.userName,
                                        userProfilePicture:
                                            group.userProfilePicture,
                                        onComplete: () {
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileScreen(userId: authorId),
                                    ),
                                  );
                                }
                              },
                        child: avatarWidget,
                      );
                    },
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.post.isAnonymous
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileScreen(userId: widget.post.userId),
                                ),
                              );
                            },
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
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: iconColor),
                    onPressed: _showPostOptions,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. TEXT CONTEXT
              Text(
                widget.post.content,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              // 4. BOTTOM: Interactive Actions
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionItem(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.redAccent : iconColor,
                        label: widget.post.likes.isNotEmpty
                            ? '${widget.post.likes.length}'
                            : 'Like',
                        onTap: _toggleLike,
                        textColor: subTextColor,
                      ),
                    ),
                    Expanded(
                      child: _buildActionItem(
                        icon: Icons.chat_bubble_outline,
                        color: iconColor,
                        label: widget.post.comments.isNotEmpty
                            ? '${widget.post.comments.length}'
                            : 'Comment',
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                CommentSheet(post: widget.post),
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                        textColor: subTextColor,
                      ),
                    ),
                    Expanded(
                      child: _buildActionItem(
                        icon: Icons.share_outlined,
                        color: iconColor,
                        label: 'Share',
                        onTap: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'Check out this post by ${widget.post.authorName} on Vylithra: ${widget.post.content}',
                            ),
                          );
                        },
                        textColor: subTextColor,
                      ),
                    ),
                    Expanded(
                      child: _buildActionItem(
                        icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: _isSaved ? iconColor : iconColor,
                        label: 'Save',
                        onTap: _toggleSave,
                        textColor: subTextColor,
                      ),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
