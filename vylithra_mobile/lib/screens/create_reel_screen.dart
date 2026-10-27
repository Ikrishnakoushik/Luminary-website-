import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_editor/video_editor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:just_audio/just_audio.dart';
import 'share_reel_screen.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  final ImagePicker _picker = ImagePicker();
  VideoEditorController? _controller;

  // Audio Mixer State
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _selectedAudioPath;
  // Filter State
  String _selectedFilter = 'None';
  final List<String> _filters = ['None', 'Grayscale', 'Sepia', 'Invert'];

  @override
  void dispose() {
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      _initializeVideo(File(video.path));
    }
  }

  void _initializeVideo(File file) async {
    _controller?.dispose();
    _controller = VideoEditorController.file(
      file,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(seconds: 60),
    );

    await _controller!.initialize();

    // Sync audio player with video playback
    _controller!.video.addListener(() {
      if (_selectedAudioPath != null) {
        if (_controller!.isPlaying && !_audioPlayer.playing) {
          _audioPlayer.play();
        } else if (!_controller!.isPlaying && _audioPlayer.playing) {
          _audioPlayer.pause();
        }
      }
    });

    setState(() {});
  }

  Future<void> _pickAudio() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'audio',
      extensions: <String>['mp3', 'wav', 'aac', 'm4a'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );

    if (file != null && file.path.isNotEmpty) {
      String path = file.path;
      setState(() {
        _selectedAudioPath = path;
      });
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.setLoopMode(LoopMode.one);

      // Mute original video audio
      _controller?.video.setVolume(0.0);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio track added! Muted original video.'),
        ),
      );
    }
  }

  void _showFilterSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Select Filter',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.purpleAccent
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          filter,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNext() async {
    if (_controller == null) return;

    // Pause players
    _controller!.video.pause();
    _audioPlayer.pause();

    // Pass the trim values, selected audio, and filter to the next screen for FFmpeg processing
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShareReelScreen(
          videoFile: _controller!.file,
          trimStart: _controller!.startTrim,
          trimEnd: _controller!.endTrim,
          audioPath: _selectedAudioPath,
          filter: _selectedFilter,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _controller != null && _controller!.initialized
            ? _buildEditor()
            : _buildPickerPlaceholder(),
      ),
    );
  }

  Widget _buildPickerPlaceholder() {
    return Center(
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
    );
  }

  Widget _buildEditor() {
    return Stack(
      children: [
        // Video Preview
        Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CropGridViewer.preview(controller: _controller!),
                  AnimatedBuilder(
                    animation: _controller!.video,
                    builder: (_, _) => AnimatedOpacity(
                      opacity: _controller!.isPlaying ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: _controller!.video.play,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Trimmer Timeline
            Container(
              height: 120,
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Trim Video',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TrimSlider(
                        controller: _controller!,
                        height: 50,
                        horizontalMargin: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Top Header
        Positioned(
          top: 10,
          left: 10,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                onPressed: _handleNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Right Side Toolbar
        Positioned(
          right: 16,
          top: MediaQuery.of(context).size.height * 0.2,
          child: Column(
            children: [
              _buildEditorTool(
                _selectedAudioPath != null
                    ? Icons.library_music
                    : Icons.music_note,
                _selectedAudioPath != null ? 'Change Song' : 'Add Song',
                _pickAudio,
                color: _selectedAudioPath != null
                    ? Colors.purpleAccent
                    : Colors.white,
              ),
              const SizedBox(height: 24),
              _buildEditorTool(
                Icons.auto_awesome,
                'Filter: $_selectedFilter',
                _showFilterSelector,
                color: _selectedFilter != 'None'
                    ? Colors.purpleAccent
                    : Colors.white,
              ),
              const SizedBox(height: 24),
              _buildEditorTool(Icons.crop, 'Crop', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pinch the video preview to crop and rotate!',
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorTool(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
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
            child: Icon(icon, color: color, size: 28),
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
