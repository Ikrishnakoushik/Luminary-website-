import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../screens/profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late Future<List<Post>> _reelsFuture;
  final ApiService _apiService = ApiService();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _reelsFuture = _apiService.fetchReels();
  }

  Future<void> _refreshReels() async {
    setState(() {
      _reelsFuture = _apiService.fetchReels();
    });
    await _reelsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Post>>(
      future: _reelsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.pinkAccent),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading reels: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _refreshReels,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No reels available.',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _refreshReels,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        final reels = snapshot.data!.where((p) => p.videoUrl != null).toList();

        if (reels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No video reels available.',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _refreshReels,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshReels,
          color: Colors.pinkAccent,
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return ReelVideoPlayer(
                post: reels[index],
                isCurrentPage: _currentPage == index,
              );
            },
          ),
        );
      },
    );
  }
}

class ReelVideoPlayer extends StatefulWidget {
  final Post post;
  final bool isCurrentPage;

  const ReelVideoPlayer({
    super.key,
    required this.post,
    required this.isCurrentPage,
  });

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    String vUrl = widget.post.videoUrl!;
    if (vUrl.startsWith('/')) {
      vUrl = 'https://www.vylithra.in$vUrl';
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(vUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.setLooping(true);
          if (widget.isCurrentPage) {
            _controller.play();
          }
        }
      });
  }

  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage != oldWidget.isCurrentPage) {
      if (widget.isCurrentPage && _isInitialized) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          if (_isInitialized)
            GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Play/Pause Overlay Indicator
          if (_isInitialized && !_controller.value.isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white54, size: 80),
            ),

          // Bottom Info Overlay (Instagram Style)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16).copyWith(bottom: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: widget.post.isAnonymous
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProfileScreen(
                                        userId: widget.post.userId,
                                      ),
                                    ),
                                  );
                                },
                          child: Text(
                            '@${widget.post.authorName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.post.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Actions Column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionIcon(Icons.favorite_border, 'Like'),
                      const SizedBox(height: 16),
                      _buildActionIcon(Icons.comment_outlined, 'Comment'),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'Check out this reel by ${widget.post.authorName} on Vylithra: ${widget.post.content}',
                            ),
                          );
                        },
                        child: _buildActionIcon(Icons.share_outlined, 'Share'),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          final prev = _isSaved;
                          setState(() {
                            _isSaved = !_isSaved;
                          });
                          try {
                            final isSaved = await ApiService().toggleSavePost(
                              widget.post.id,
                            );
                            setState(() {
                              _isSaved = isSaved;
                            });
                          } catch (e) {
                            setState(() {
                              _isSaved = prev;
                            });
                          }
                        },
                        child: _buildActionIcon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          'Save',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
