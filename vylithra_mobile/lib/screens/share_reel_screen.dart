import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:video_compress/video_compress.dart';

class ShareReelScreen extends StatefulWidget {
  final File videoFile;

  const ShareReelScreen({super.key, required this.videoFile});

  @override
  State<ShareReelScreen> createState() => _ShareReelScreenState();
}

class _ShareReelScreenState extends State<ShareReelScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  double _compressionProgress = 0;
  Subscription? _subscription;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _fetchPrivacyDefault();
    _subscription = VideoCompress.compressProgress$.subscribe((progress) {
      if (mounted) {
        setState(() {
          _compressionProgress = progress;
        });
      }
    });
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

  @override
  void dispose() {
    _subscription?.unsubscribe();
    VideoCompress.deleteAllCache();
    super.dispose();
  }

  Future<void> _handleUpload() async {
    if (_captionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a caption')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Compressing and uploading Reel...')),
    );

    try {
      final info = await VideoCompress.compressVideo(
        widget.videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      final fileToUpload = info?.file ?? widget.videoFile;

      await ApiService().uploadReel(_captionController.text, fileToUpload, _isAnonymous);
      if (mounted) {
        // Pop both the ShareReelScreen and the CreateReelScreen, returning true to refresh
        Navigator.pop(context); // Pop share screen
        Navigator.pop(context, true); // Pop create screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel published successfully!')),
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
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('New Reel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.video_library, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Write a caption...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Post Anonymously', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Hide your username and profile picture from this reel.'),
              value: _isAnonymous,
              onChanged: (val) => setState(() => _isAnonymous = val),
              activeColor: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isUploading
                  ? Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          _compressionProgress > 0 && _compressionProgress < 100
                              ? 'Compressing: ${_compressionProgress.toStringAsFixed(0)}%'
                              : 'Uploading...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: _handleUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
