import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      _initializeVideo(File(video.path));
    }
  }

  void _initializeVideo(File file) {
    _videoController?.dispose();
    _selectedVideo = file;
    _videoController = VideoPlayerController.file(file)
      ..initialize().then((_) {
        setState(() {});
        _videoController!.setLooping(true);
        _videoController!.play();
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _showFeatureMock(String featureName, IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.purpleAccent),
            const SizedBox(height: 16),
            Text(
              featureName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This advanced editing feature is ready to be wired up to a native video processing SDK!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        ),
      ),
    );
  }

  void _handleUpload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing and uploading Reel...')),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel published successfully!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player or Picker Placeholder
          if (_videoController != null && _videoController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_camera_front, size: 80, color: Colors.white54),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select Video from Gallery'),
                  ),
                ],
              ),
            ),

          // Top Header (Back & Next)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                if (_selectedVideo != null)
                  ElevatedButton(
                    onPressed: _handleUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // Right Side Editing Toolbar (Only shows if video is selected)
          if (_selectedVideo != null)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.25,
              child: Column(
                children: [
                  _buildEditorTool(Icons.music_note, 'Add Song', () => _showFeatureMock('Audio Mixer', Icons.music_note)),
                  const SizedBox(height: 24),
                  _buildEditorTool(Icons.content_cut, 'Trim/Break', () => _showFeatureMock('Video Trimmer', Icons.content_cut)),
                  const SizedBox(height: 24),
                  _buildEditorTool(Icons.auto_awesome, 'Filters', () => _showFeatureMock('Color Filters', Icons.auto_awesome)),
                  const SizedBox(height: 24),
                  _buildEditorTool(Icons.wallpaper, 'Background', () => _showFeatureMock('AI Background Removal', Icons.wallpaper)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorTool(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
