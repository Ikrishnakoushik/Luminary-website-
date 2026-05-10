import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io_client;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/webrtc_service.dart';
import '../providers/auth_provider.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUsername;

  const ChatScreen({super.key, required this.targetUserId, required this.targetUsername});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late io_client.Socket socket;
  
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _extractUserId();
    _fetchMessages();
    _initSocket();
  }

  void _extractUserId() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final data = jsonDecode(payload);
          _currentUserId = data['user']?['id'];
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final messages = await _apiService.get('/api/messages/${widget.targetUserId}');
      if (mounted) {
        setState(() {
          _messages = messages ?? [];
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initSocket() {
    if (_currentUserId == null) return;

    socket = io_client.io(ApiService.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    socket.connect();
    
    socket.onConnect((_) {
      socket.emit('join_chat', _currentUserId);
    });

    socket.on('new_message', (data) {
      final senderData = data['sender'];
      final senderId = senderData is Map ? senderData['_id'] : senderData;
      
      if (senderId == widget.targetUserId || senderId == _currentUserId) {
        if (mounted) {
          setState(() {
            // Check if we already appended it optimistically
            if (!_messages.any((m) => m['_id'] == data['_id'])) {
              _messages.add(data);
            }
          });
          _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    _messageController.clear();
    
    // Optimistic UI update
    final optimisticMsg = {
      '_id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender': {'_id': _currentUserId},
      'content': text,
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();

    try {
      final savedMsg = await _apiService.post('/api/messages/${widget.targetUserId}', {
        'content': text,
      });
      
      // Replace optimistic message with saved one
      setState(() {
        final index = _messages.indexWhere((m) => m['_id'] == optimisticMsg['_id']);
        if (index != -1) {
          _messages[index] = savedMsg;
        }
      });
    } catch (e) {
      // Revert if failed
      setState(() {
        _messages.removeWhere((m) => m['_id'] == optimisticMsg['_id']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  Future<void> _logCall(bool isVideo) async {
    try {
      final savedMsg = await _apiService.post('/api/messages/${widget.targetUserId}', {
        'content': isVideo ? 'Video Call' : 'Voice Call',
        'attachmentType': 'call',
      });
      setState(() => _messages.add(savedMsg));
      _scrollToBottom();
    } catch (e) {
      debugPrint('Failed to log call: $e');
    }
  }

  Future<void> _pickAndUploadMedia(bool isVideo) async {
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
      'content': 'Uploading media...',
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    setState(() => _messages.add(optimisticMsg));
    _scrollToBottom();

    try {
      final uploadRes = await _apiService.uploadFile('/api/messages/upload', file);
      final fileUrl = uploadRes['url'] ?? uploadRes['fileUrl']; 
      
      if (fileUrl == null) throw Exception("Failed to get file URL from server.");

      final savedMsg = await _apiService.post('/api/messages/${widget.targetUserId}', {
        'content': isVideo ? 'Sent a video' : 'Sent an image',
        'attachmentUrl': fileUrl,
        'attachmentType': isVideo ? 'video' : 'image',
      });
      
      setState(() {
        final index = _messages.indexWhere((m) => m['_id'] == optimisticMsg['_id']);
        if (index != -1) _messages[index] = savedMsg;
      });
    } catch (e) {
      setState(() => _messages.removeWhere((m) => m['_id'] == optimisticMsg['_id']));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: Text('Image', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMedia(false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.red),
                title: Text('Video', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMedia(true);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
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
        backgroundColor: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(widget.targetUsername, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
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
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
                        bottom: 20,
                        left: 16,
                        right: 16,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final senderData = msg['sender'];
                        final senderId = senderData is Map ? senderData['_id'] : senderData;
                        final isMe = senderId == _currentUserId;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isMe 
                                  ? const Color(0xFF3B82F6) 
                                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20).copyWith(
                                bottomRight: isMe ? const Radius.circular(0) : null,
                                bottomLeft: !isMe ? const Radius.circular(0) : null,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (msg['attachmentType'] == 'call')
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        msg['content'] == 'Video Call' ? Icons.videocam : Icons.phone,
                                        color: isMe ? Colors.white : const Color(0xFF3B82F6),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        msg['content'] ?? '',
                                        style: TextStyle(
                                          color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  if (msg['attachmentUrl'] != null && msg['attachmentUrl'].toString().isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: msg['attachmentType'] == 'image'
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              msg['attachmentUrl'], 
                                              width: 200, 
                                              height: 200, 
                                              fit: BoxFit.cover,
                                            )
                                          )
                                        : Container(
                                            width: 200, height: 100,
                                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                                            child: const Center(child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white)),
                                          ),
                                    ),
                                  Text(
                                    msg['content'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Input Bar
            Container(
              padding: EdgeInsets.only(
                left: 16, 
                right: 16, 
                top: 12, 
                bottom: MediaQuery.of(context).padding.bottom + 12
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: isDark ? Colors.white54 : Colors.black54),
                    onPressed: _showAttachmentMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                        filled: true,
                        fillColor: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
