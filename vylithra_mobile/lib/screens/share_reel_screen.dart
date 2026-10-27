import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:video_compress/video_compress.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class ShareReelScreen extends StatefulWidget {
  final File videoFile;
  final Duration trimStart;
  final Duration trimEnd;
  final String? audioPath;
  final String filter;

  const ShareReelScreen({
    super.key,
    required this.videoFile,
    required this.trimStart,
    required this.trimEnd,
    this.audioPath,
    this.filter = 'None',
  });

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please write a caption')));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Processing video...')));

    try {
      File fileToUpload = widget.videoFile;

      // 1. Process with FFmpeg if editing was done
      bool needsProcessing =
          widget.trimStart.inMilliseconds > 0 ||
          widget.audioPath != null ||
          widget.filter != 'None';

      if (needsProcessing) {
        final tempDir = await getTemporaryDirectory();
        final outputPath =
            '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4';

        // Build FFmpeg command
        List<String> cmd = [];

        // Input video (trimming)
        cmd.add('-ss');
        cmd.add(widget.trimStart.inSeconds.toString());
        cmd.add('-t');
        cmd.add((widget.trimEnd - widget.trimStart).inSeconds.toString());
        cmd.add('-i');
        cmd.add('"${widget.videoFile.path}"');

        // Input audio if provided
        if (widget.audioPath != null) {
          cmd.add('-i');
          cmd.add('"${widget.audioPath!}"');
        }

        // Filters
        String vfString = '';
        if (widget.filter == 'Grayscale') {
          vfString = 'hue=s=0';
        } else if (widget.filter == 'Sepia') {
          vfString =
              'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131';
        } else if (widget.filter == 'Invert') {
          vfString = 'negate';
        }

        if (vfString.isNotEmpty) {
          cmd.add('-vf');
          cmd.add(vfString);
        }

        // Audio mapping
        if (widget.audioPath != null) {
          cmd.add('-c:v');
          cmd.add('libx264'); // Re-encode video if applying filters
          cmd.add('-map');
          cmd.add('0:v:0');
          cmd.add('-map');
          cmd.add('1:a:0');
          cmd.add('-shortest'); // End encoding when the shortest stream ends
        } else {
          if (vfString.isEmpty) {
            cmd.add('-c');
            cmd.add('copy'); // Fast copy if no visual filters
          }
        }

        cmd.add('-y'); // Overwrite output
        cmd.add('"$outputPath"');

        final String commandString = cmd.join(' ');
        debugPrint('FFmpeg command: $commandString');

        final session = await FFmpegKit.execute(commandString);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          fileToUpload = File(outputPath);
        } else {
          final logs = await session.getLogsAsString();
          debugPrint('FFmpeg Error: $logs');
          throw Exception('Video processing failed');
        }
      }

      // 2. Compress the processed video
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Compressing Reel...')));

      final info = await VideoCompress.compressVideo(
        fileToUpload.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      fileToUpload = info?.file ?? fileToUpload;

      // 3. Upload

      await ApiService().uploadReel(
        _captionController.text,
        fileToUpload,
        _isAnonymous,
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
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
                      child: Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 30,
                      ),
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
              title: const Text(
                'Post Anonymously',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Hide your username and profile picture from this reel.',
              ),
              value: _isAnonymous,
              onChanged: (val) => setState(() => _isAnonymous = val),
              activeThumbColor: Colors.blueAccent,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
