import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';

class CommentSheet extends StatefulWidget {
  final Post post;

  const CommentSheet({super.key, required this.post});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final commentsArray = await ApiService().commentOnPost(widget.post.id, text);
      setState(() {
        widget.post.comments = commentsArray;
        _commentController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            height: 5,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text('Comments', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          Flexible(
            child: widget.post.comments.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.post.comments.length,
                    itemBuilder: (context, index) {
                      final comment = widget.post.comments[index];
                      // Backend returns { text: String, user: String, username: String } usually, but it might just be the objects
                      final username = comment['username'] ?? 'User';
                      final text = comment['text'] ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(username, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        subtitle: Text(text, style: TextStyle(color: textColor)),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmitting
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.blueAccent),
                        onPressed: _submitComment,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
