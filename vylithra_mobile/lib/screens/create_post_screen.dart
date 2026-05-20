import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _fetchPrivacyDefault();
  }

  Future<void> _fetchPrivacyDefault() async {
    try {
      final res = await ApiService().get('/api/users/privacy');
      if (mounted && res['hideProfileOnPosts'] == true) {
        setState(() => _isAnonymous = true);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_contentController.text.isEmpty && _selectedImage == null) return;
    
    setState(() {
      _isUploading = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading post...')),
    );
    
    try {
      await ApiService().uploadPost(_contentController.text, _selectedImage, _isAnonymous);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('New Post'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _isUploading 
          ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          : TextButton(
            onPressed: _handleUpload,
            child: const Text(
              'Share',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'What do you want to talk about?',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_selectedImage != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildActionIcon(Icons.image, 'Photo', _pickImage, Colors.green),
              ],
            ),
            const Divider(height: 30),
            SwitchListTile(
              title: const Text('Post Anonymously', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Hide your username and profile picture from this post.'),
              value: _isAnonymous,
              onChanged: (val) => setState(() => _isAnonymous = val),
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
