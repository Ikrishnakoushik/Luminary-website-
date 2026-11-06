import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/webrtc_service.dart';
import '../services/socket_service.dart';
import '../services/e2ee_service.dart';
import '../providers/auth_provider.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUsername;

  const ChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService _socketService = SocketService();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _chatClearedSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageViewedSubscription;

  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _token;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _extractUserId();
    _fetchMessages();
    _initSocket();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _fetchMessages(isBackground: true);
      }
    });
  }

  void _extractUserId() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    _token = token;
    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          final data = jsonDecode(payload);
          _currentUserId = data['user']?['id'] ?? data['id'] ?? data['user']?['_id'] ?? data['_id'];
          if (_currentUserId != null) {
            WebRTCService().initialize(_currentUserId!);
            _socketService.connect(_currentUserId!);
            E2EEService.instance.init(_currentUserId!, token, ApiService.baseUrl);
          }
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    try {
      final messages = await _apiService.get(
        '/api/messages/${widget.targetUserId}',
      );
      if (mounted && messages is List) {
        final currentToken = _token ?? (mounted ? Provider.of<AuthProvider>(context, listen: false).token ?? '' : '');

        // Decrypt E2EE messages
        for (final msg in messages) {
          if (msg is Map<String, dynamic> && msg['isE2EE'] == true && msg['iv'] != null) {
            final dec = await E2EEService.instance.decryptMessage(
              msg['content']?.toString() ?? '',
              msg['iv']?.toString(),
              widget.targetUserId,
              currentToken,
              ApiService.baseUrl,
            );
            msg['content'] = dec;
          }
        }

        if (isBackground) {
          bool hasNew = false;
          for (final msg in messages) {
            final msgId = msg['_id'];
            if (msgId != null && !_messages.any((m) => m['_id'] == msgId)) {
              _messages.add(msg);
              hasNew = true;
            }
          }
          if (hasNew) {
            setState(() {});
            _scrollToBottom();
          }
        } else {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted && !isBackground) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initSocket() {
    if (_currentUserId == null) return;

    // We assume SocketService is already connected globally via HomeScreen.
    _messageSubscription = _socketService.onNewMessage.listen((data) async {
      final senderData = data['sender'];
      final senderId = senderData is Map ? senderData['_id'] : senderData;

      if (senderId == widget.targetUserId || senderId == _currentUserId) {
        if (data['isE2EE'] == true && data['iv'] != null) {
          final currentToken = _token ?? (mounted ? Provider.of<AuthProvider>(context, listen: false).token ?? '' : '');
          final dec = await E2EEService.instance.decryptMessage(
            data['content']?.toString() ?? '',
            data['iv']?.toString(),
            widget.targetUserId,
            currentToken,
            ApiService.baseUrl,
          );
          data['content'] = dec;
        }

        if (mounted) {
          setState(() {
            final msgId = data['_id']?.toString();
            // Check if we already have this message by _id
            if (msgId != null && _messages.any((m) => m['_id']?.toString() == msgId)) {
              return;
            }
            // If sent by me, reconcile pending optimistic message
            if (senderId == _currentUserId) {
              final optIndex = _messages.indexWhere((m) => m['isOptimistic'] == true);
              if (optIndex != -1) {
                _messages[optIndex] = data;
                return;
              }
            }
            _messages.add(data);
          });
          _scrollToBottom();
        }
      }
    });

    _messageViewedSubscription?.cancel();
    _messageViewedSubscription = _socketService.onMessageViewed.listen((data) {
      final msgId = data['messageId']?.toString();
      if (msgId != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['_id']?.toString() == msgId);
          if (idx != -1) {
            _messages[idx]['isViewed'] = true;
            _messages[idx]['attachmentUrl'] = null;
          }
        });
      }
    });

    _chatClearedSubscription?.cancel();
    _chatClearedSubscription = _socketService.onChatCleared.listen((data) {
      final chatWith = data['chatWith'];
      final clearedBy = data['clearedBy'];
      if (chatWith == widget.targetUserId || clearedBy == widget.targetUserId) {
        if (mounted) {
          setState(() {
            _messages.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat was cleared')),
          );
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _resolveMediaUrl(dynamic url) {
    if (url == null) return '';
    final str = url.toString().trim();
    if (str.isEmpty) return '';
    if (str.startsWith('http://') || str.startsWith('https://')) return str;
    if (str.startsWith('/')) return '${ApiService.baseUrl}$str';
    return '${ApiService.baseUrl}/$str';
  }

  void _openMediaViewer(String mediaUrl, bool isVideo) {
    final fullUrl = _resolveMediaUrl(mediaUrl);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: isVideo
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline, color: Colors.white, size: 72),
                          const SizedBox(height: 12),
                          const Text(
                            'Video Attachment',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              fullUrl,
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Image.network(
                      fullUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
            ),
            Positioned(
              top: 40,
              right: 64,
              child: IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Downloading file to device...')),
                  );
                },
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewOnceMedia(Map<String, dynamic> msg) {
    final mediaUrl = msg['attachmentUrl']?.toString();
    if (mediaUrl == null || mediaUrl.isEmpty) return;
    final isVideo = msg['attachmentType'] == 'video';
    final fullUrl = _resolveMediaUrl(mediaUrl);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: isVideo
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline, color: Color(0xFF14B8A6), size: 72),
                          const SizedBox(height: 12),
                          const Text(
                            'View Once Video',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This media will disappear permanently once closed.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Image.network(
                      fullUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF14B8A6), width: 1.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('1', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(width: 8),
                    Text('View Once Media', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final msgId = msg['_id']?.toString();
                  if (msgId != null && !msgId.startsWith('opt_')) {
                    try {
                      await _apiService.put('/api/messages/$msgId/view-once', {});
                    } catch (_) {}
                  }
                  if (mounted) {
                    setState(() {
                      msg['isViewed'] = true;
                      msg['attachmentUrl'] = null;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_currentUserId == null) {
      _extractUserId();
    }
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    // Optimistic UI update
    final optimisticMsg = {
      '_id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender': {'_id': _currentUserId ?? 'me'},
      'content': text,
      'createdAt': DateTime.now().toIso8601String(),
      'isOptimistic': true,
    };

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token ?? '';

      // Encrypt message for recipient
      final enc = await E2EEService.instance.encryptMessage(
        text,
        widget.targetUserId,
        token,
        ApiService.baseUrl,
      );

      final savedMsg = await _apiService.post(
        '/api/messages/${widget.targetUserId}',
        {
          'content': enc['content'],
          'iv': enc['iv'],
          'isE2EE': enc['isE2EE'],
        },
      );

      // Replace optimistic message with saved one
      setState(() {
        final index = _messages.indexWhere(
          (m) => m['_id'] == optimisticMsg['_id'],
        );
        if (index != -1) {
          if (savedMsg is Map<String, dynamic>) {
            savedMsg['content'] = text;
          }
          final savedId = savedMsg['_id']?.toString();
          if (savedId != null && _messages.any((m) => m['_id']?.toString() == savedId)) {
            _messages.removeAt(index);
          } else {
            _messages[index] = savedMsg;
          }
        }
      });
    } catch (e) {
      // Revert if failed
      setState(() {
        _messages.removeWhere((m) => m['_id'] == optimisticMsg['_id']);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  Future<void> _logCall(bool isVideo) async {
    try {
      final savedMsg = await _apiService.post(
        '/api/messages/${widget.targetUserId}',
        {
          'content': isVideo ? 'Video Call' : 'Voice Call',
          'attachmentType': 'call',
        },
      );
      setState(() => _messages.add(savedMsg));
      _scrollToBottom();
    } catch (e) {
      debugPrint('Failed to log call: $e');
    }
  }

  Future<void> _pickAndUploadMedia(bool isVideo, {bool isViewOnce = false}) async {
    final picker = ImagePicker();
    final XFile? pickedFile = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile == null || _currentUserId == null) return;

    File file = File(pickedFile.path);

    // Show uploading indicator (optimistic ui with a loader)
    final optimisticMsg = {
      '_id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender': {'_id': _currentUserId},
      'content': isViewOnce 
          ? (isVideo ? '1 Video · View once' : '1 Photo · View once')
          : 'Uploading media...',
      'attachmentType': isVideo ? 'video' : 'image',
      'isViewOnce': isViewOnce,
      'isOptimistic': true,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() => _messages.add(optimisticMsg));
    _scrollToBottom();

    try {
      final uploadRes = await _apiService.uploadFile(
        '/api/messages/upload',
        file,
      );
      final fileUrl = uploadRes['url'] ?? uploadRes['fileUrl'];

      if (fileUrl == null) {
        throw Exception("Failed to get file URL from server.");
      }

      final savedMsg = await _apiService
          .post('/api/messages/${widget.targetUserId}', {
            'content': isViewOnce
                ? (isVideo ? '1 Video · View once' : '1 Photo · View once')
                : (isVideo ? 'Sent a video' : 'Sent an image'),
            'attachmentUrl': fileUrl,
            'attachmentType': isVideo ? 'video' : 'image',
            'isViewOnce': isViewOnce,
          });

      setState(() {
        final index = _messages.indexWhere(
          (m) => m['_id'] == optimisticMsg['_id'],
        );
        if (index != -1) {
          final savedId = savedMsg['_id']?.toString();
          if (savedId != null && _messages.any((m) => m['_id']?.toString() == savedId)) {
            _messages.removeAt(index);
          } else {
            _messages[index] = savedMsg;
          }
        }
      });
    } catch (e) {
      setState(
        () => _messages.removeWhere((m) => m['_id'] == optimisticMsg['_id']),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.blue),
                title: Text(
                  'Photo',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text('Send a photo in chat', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMedia(false, isViewOnce: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.looks_one_outlined, color: Color(0xFF14B8A6)),
                title: Text(
                  'View Once Photo',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text('Disappears after being viewed once', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMedia(false, isViewOnce: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined, color: Colors.purple),
                title: Text(
                  'Video',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text('Send a video in chat', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMedia(true, isViewOnce: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.looks_one_outlined, color: Colors.deepOrange),
                title: Text(
                  'View Once Video',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text('Disappears after being played once', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMedia(true, isViewOnce: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Clear Chat'),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all messages in this conversation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeClearChat(false);
            },
            child: const Text('Clear for Me'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeClearChat(true);
            },
            child: const Text('Clear for Everyone'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeClearChat(bool forEveryone) async {
    try {
      await _apiService.delete(
        '/api/messages/clear/${widget.targetUserId}?forEveryone=$forEveryone',
      );
      if (mounted) {
        setState(() {
          _messages.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat cleared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear chat: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageSubscription?.cancel();
    _chatClearedSubscription?.cancel();
    _messageViewedSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          widget.targetUsername,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              if (_currentUserId == null) {
                _extractUserId();
              }
              if (_currentUserId != null) {
                WebRTCService().initialize(_currentUserId!);
                _socketService.connect(_currentUserId!);
              }
              _logCall(false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    webrtcService: WebRTCService(),
                    isIncoming: false,
                    targetUserId: widget.targetUserId,
                    targetUsername: widget.targetUsername,
                    isVideoCall: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              if (_currentUserId == null) {
                _extractUserId();
              }
              if (_currentUserId != null) {
                WebRTCService().initialize(_currentUserId!);
                _socketService.connect(_currentUserId!);
              }
              _logCall(true);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    webrtcService: WebRTCService(),
                    isIncoming: false,
                    targetUserId: widget.targetUserId,
                    targetUsername: widget.targetUsername,
                    isVideoCall: true,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_chat') {
                _showClearChatDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Clear Chat',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchMessages,
                      color: const Color(0xFF3B82F6),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        top:
                            MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            20,
                        bottom: 20,
                        left: 16,
                        right: 16,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final senderData = msg['sender'];
                        final senderId = senderData is Map
                            ? senderData['_id']
                            : senderData;
                        final isMe = senderId == _currentUserId;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF3B82F6)
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20).copyWith(
                                bottomRight: isMe
                                    ? const Radius.circular(0)
                                    : null,
                                bottomLeft: !isMe
                                    ? const Radius.circular(0)
                                    : null,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (msg['attachmentType'] == 'call')
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        msg['content'] == 'Video Call'
                                            ? Icons.videocam
                                            : Icons.phone,
                                        color: isMe
                                            ? Colors.white
                                            : const Color(0xFF3B82F6),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        msg['content'] ?? '',
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : (isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  if (msg['isViewOnce'] == true) ...[
                                    if (msg['isViewed'] == true || msg['attachmentUrl'] == null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.black12,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.grey, width: 1.5),
                                              ),
                                              child: const Icon(Icons.check, size: 12, color: Colors.grey),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              msg['attachmentType'] == 'video' ? 'Video · Opened' : 'Photo · Opened',
                                              style: TextStyle(
                                                color: isMe ? Colors.white70 : Colors.grey[600],
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      GestureDetector(
                                        onTap: () => _openViewOnceMedia(msg),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isMe ? Colors.white.withValues(alpha: 0.22) : const Color(0xFF0D9488).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: const Color(0xFF14B8A6), width: 1.2),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 20,
                                                height: 20,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: const Color(0xFF14B8A6), width: 1.5),
                                                ),
                                                child: const Text('1', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 11)),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                msg['attachmentType'] == 'video' ? 'Video · View once' : 'Photo · View once',
                                                style: TextStyle(
                                                  color: isMe ? Colors.white : const Color(0xFF14B8A6),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(Icons.play_arrow, size: 16, color: Color(0xFF14B8A6)),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ] else ...[
                                    if (msg['attachmentUrl'] != null &&
                                        msg['attachmentUrl']
                                            .toString()
                                            .isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: msg['attachmentType'] == 'image'
                                            ? Stack(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _openMediaViewer(
                                                      msg['attachmentUrl'].toString(),
                                                      false,
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                      child: Image.network(
                                                        _resolveMediaUrl(
                                                          msg['attachmentUrl'],
                                                        ),
                                                        width: 220,
                                                        height: 220,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (context, error, stackTrace) => Container(
                                                          width: 220,
                                                          height: 150,
                                                          color: Colors.black12,
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.broken_image,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 8,
                                                    right: 8,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        _openMediaViewer(msg['attachmentUrl'].toString(), false);
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withValues(alpha: 0.65),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.download_rounded,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : GestureDetector(
                                                onTap: () => _openMediaViewer(
                                                  msg['attachmentUrl'].toString(),
                                                  true,
                                                ),
                                                child: Container(
                                                  width: 220,
                                                  height: 120,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black26,
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.play_circle_fill,
                                                      size: 50,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    if (msg['content'] != null &&
                                        msg['content'].toString().isNotEmpty &&
                                        msg['content'] != 'Sent an image' &&
                                        msg['content'] != 'Sent a video' &&
                                        msg['content'] != '[Attachment]' &&
                                        msg['content'] != 'Photo')
                                      Text(
                                        msg['content'] ?? '',
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : (isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          fontSize: 16,
                                        ),
                                      ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            ),
            // Input Bar
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    onPressed: _showAttachmentMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
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
}
