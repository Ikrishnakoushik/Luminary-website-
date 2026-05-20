import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io_client;
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io_client.Socket? _socket;
  
  // Stream Controllers for global broadcasting
  final _postController = StreamController<Map<String, dynamic>>.broadcast();
  final _likeController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcSignalController = StreamController<Map<String, dynamic>>.broadcast();

  // Public Streams
  Stream<Map<String, dynamic>> get onNewPost => _postController.stream;
  Stream<Map<String, dynamic>> get onPostLiked => _likeController.stream;
  Stream<Map<String, dynamic>> get onNewComment => _commentController.stream;
  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onWebRTCSignal => _webrtcSignalController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String userId) {
    if (_socket != null) return;

    _socket = io_client.io(ApiService.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Socket Connected globally');
      _socket!.emit('join_chat', userId);
    });

    _socket!.on('new_post', (data) => _postController.add(Map<String, dynamic>.from(data)));
    _socket!.on('post_liked', (data) => _likeController.add(Map<String, dynamic>.from(data)));
    _socket!.on('new_comment', (data) => _commentController.add(Map<String, dynamic>.from(data)));
    _socket!.on('new_message', (data) => _messageController.add(Map<String, dynamic>.from(data)));
    _socket!.on('webrtc_signal', (data) => _webrtcSignalController.add(Map<String, dynamic>.from(data)));

    _socket!.onDisconnect((_) {
      print('Socket Disconnected globally');
    });
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    // Don't close streams because it's a singleton and we might reconnect
  }
}
