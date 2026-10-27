import 'package:flutter/material.dart';
import '../models/story.dart';
import '../services/api_service.dart';
import 'package:video_player/video_player.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final String userName;
  final String userProfilePicture;
  final VoidCallback onComplete;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.userName,
    required this.userProfilePicture,
    required this.onComplete,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  VideoPlayerController? _videoController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
    _loadStory(0);
  }

  void _loadStory(int index) {
    _animationController.stop();
    _animationController.reset();
    _videoController?.dispose();
    _videoController = null;

    final story = widget.stories[index];
    _apiService.put(
      '/api/stories/${story.id}/view',
      {},
    ); // Mark as viewed silently

    if (story.mediaType == 'video') {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl))
            ..initialize().then((_) {
              setState(() {
                _animationController.duration =
                    _videoController!.value.duration;
                _videoController!.play();
                _animationController.forward();
              });
            });
    } else {
      setState(() {
        _animationController.duration = const Duration(seconds: 5);
        _animationController.forward();
      });
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _loadStory(_currentIndex);
      });
    } else {
      widget.onComplete();
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _loadStory(_currentIndex);
      });
    } else {
      _loadStory(0);
    }
  }

  void _pause() {
    _animationController.stop();
    _videoController?.pause();
  }

  void _resume() {
    _animationController.forward();
    _videoController?.play();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final double screenWidth = MediaQuery.of(context).size.width;
          final double tapPosition = details.globalPosition.dx;

          if (tapPosition < screenWidth / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        onLongPress: _pause,
        onLongPressUp: _resume,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Layer
            if (story.mediaType == 'video')
              _videoController != null && _videoController!.value.isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
            else
              Center(child: Image.network(story.mediaUrl, fit: BoxFit.contain)),

            // UI Layer
            SafeArea(
              child: Column(
                children: [
                  // Progress Bars
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: List.generate(
                        widget.stories.length,
                        (index) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _buildProgressBar(index),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: widget.userProfilePicture.isNotEmpty
                              ? NetworkImage(widget.userProfilePicture)
                              : null,
                          backgroundColor: Colors.grey[800],
                          child: widget.userProfilePicture.isEmpty
                              ? Text(
                                  widget.userName.isNotEmpty
                                      ? widget.userName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            widget.onComplete();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int index) {
    if (index < _currentIndex) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else if (index == _currentIndex) {
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _animationController.value,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white30,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
  }
}
