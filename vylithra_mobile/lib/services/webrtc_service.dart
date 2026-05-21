import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'socket_service.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final SocketService _socketService = SocketService();
  
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  String? _currentUserId;
  String? _currentCallTarget;
  bool isCallActive = false;
  bool isVideoCall = false;
  bool _isCallConnected = false;
  Timer? _ringTimer;

  // Callbacks for UI updates
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function()? onCallEnded;
  Function(Map<String, dynamic> data)? onIncomingCall;
  Function()? onCallAccepted;

  StreamSubscription<Map<String, dynamic>>? _signalSubscription;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:global.stun.twilio.com:3478'}
    ]
  };

  void initialize(String userId) {
    _currentUserId = userId;
    _listenForSignals();
  }

  Map<String, dynamic>? _incomingOfferPayload;

  void _listenForSignals() {
    if (_currentUserId == null) return;
    
    _signalSubscription?.cancel();
    // Instead of Firebase, we listen to our global SocketService stream for 'webrtc_signal' events
    _signalSubscription = _socketService.onWebRTCSignal.listen((data) {
      final type = data['type'];
      final payload = Map<String, dynamic>.from(data['payload'] ?? {});
      _handleIncomingSignal(type, payload);
    });
  }

  Future<bool> isUserOnline(String targetId) async {
    // With pure WebRTC via sockets, we can assume online, 
    // or we could implement a ping/pong over socket.
    // For now, always try.
    return true; 
  }

  Future<void> _handleIncomingSignal(String type, Map<String, dynamic> payload) async {
    switch (type) {
      case 'call-made':
        if (isCallActive) {
          _sendSignal('call-rejected', {'to': payload['from']});
          return;
        }
        if (_currentCallTarget == payload['from']) {
          // Already ringing from this user, just update the payload and ignore
          _incomingOfferPayload = payload;
          return;
        }
        _currentCallTarget = payload['from'];
        isVideoCall = payload['isVideo'] ?? false;
        _incomingOfferPayload = payload;
        
        if (onIncomingCall != null) {
          onIncomingCall!(payload);
        }
        break;
      case 'answer-made':
        _isCallConnected = true;
        _ringTimer?.cancel();
        final answer = RTCSessionDescription(payload['answer']['sdp'], payload['answer']['type']);
        await _peerConnection?.setRemoteDescription(answer);
        if (onCallAccepted != null) onCallAccepted!();
        break;
      case 'ice-candidate':
        final candidate = RTCIceCandidate(
          payload['candidate']['candidate'],
          payload['candidate']['sdpMid'],
          payload['candidate']['sdpMLineIndex'],
        );
        await _peerConnection?.addCandidate(candidate);
        break;
      case 'call-rejected':
      case 'call-ended':
        endCall();
        break;
    }
  }

  void _sendSignal(String type, Map<String, dynamic> payload) {
    if (payload['to'] == null) return;
    // Emit through our global SocketService
    _socketService.emit('webrtc_signal', {
      'to': payload['to'],
      'type': type,
      'payload': payload,
    });
  }

  Future<void> _createPeerConnection(String targetId) async {
    _peerConnection = await createPeerConnection(_iceServers);

    if (localStream != null) {
      localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, localStream!);
      });
    }

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _sendSignal('ice-candidate', {
        'to': targetId,
        'from': _currentUserId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        if (onRemoteStream != null) onRemoteStream!(remoteStream!);
      }
    };
  }

  Future<void> initiateCall(String targetId, bool isVideo) async {
    _currentCallTarget = targetId;
    isVideoCall = isVideo;
    _isCallConnected = false;
    
    try {
      await [Permission.camera, Permission.microphone].request();
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo,
      });
      if (onLocalStream != null) onLocalStream!(localStream!);

      await _createPeerConnection(targetId);

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      void sendOfferSignal() {
        _sendSignal('call-made', {
          'to': targetId,
          'from': _currentUserId,
          'isVideo': isVideo,
          'offer': {
            'type': offer.type,
            'sdp': offer.sdp,
          }
        });
      }

      sendOfferSignal();
      isCallActive = true;
      
      _ringTimer?.cancel();
      _ringTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (isCallActive && !_isCallConnected && _peerConnection != null) {
          sendOfferSignal();
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      endCall();
    }
  }

  Future<void> acceptCall(Map<String, dynamic> incomingData) async {
    try {
      final payloadToUse = incomingData.isNotEmpty ? incomingData : _incomingOfferPayload;
      if (payloadToUse == null) throw Exception("No incoming offer payload found");

      await [Permission.camera, Permission.microphone].request();
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideoCall,
      });
      if (onLocalStream != null) onLocalStream!(localStream!);

      final targetId = payloadToUse['from'];
      await _createPeerConnection(targetId);

      final offer = RTCSessionDescription(payloadToUse['offer']['sdp'], payloadToUse['offer']['type']);
      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _sendSignal('answer-made', {
        'to': targetId,
        'from': _currentUserId,
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        }
      });
      isCallActive = true;
    } catch (e) {
      rejectCall();
    }
  }

  void rejectCall() {
    if (_currentCallTarget != null) {
      _sendSignal('call-rejected', {'to': _currentCallTarget});
    }
    endCall();
  }

  void endCall() {
    if (_currentCallTarget != null && isCallActive) {
      _sendSignal('call-ended', {'to': _currentCallTarget});
    }
    isCallActive = false;
    _isCallConnected = false;
    _ringTimer?.cancel();
    _currentCallTarget = null;
    _incomingOfferPayload = null;
    
    localStream?.getTracks().forEach((track) {
      track.stop();
    });
    localStream?.dispose();
    localStream = null;

    remoteStream?.getTracks().forEach((track) {
      track.stop();
    });
    remoteStream?.dispose();
    remoteStream = null;

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;

    if (onCallEnded != null) onCallEnded!();
  }

  void toggleMic() {
    if (localStream != null) {
      final audioTrack = localStream!.getAudioTracks()[0];
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  void toggleCamera() {
    if (localStream != null && localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = localStream!.getVideoTracks()[0];
      videoTrack.enabled = !videoTrack.enabled;
    }
  }

  void dispose() {
    _signalSubscription?.cancel();
    endCall();
  }
}
