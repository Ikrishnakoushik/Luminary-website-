import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  String? _currentUserId;
  String? _currentCallTarget;
  bool isCallActive = false;
  bool isVideoCall = false;

  // Callbacks for UI updates
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function()? onCallEnded;
  Function(Map<String, dynamic> data)? onIncomingCall;
  Function()? onCallAccepted;

  StreamSubscription<DatabaseEvent>? _signalSubscription;

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

  void _listenForSignals() {
    if (_currentUserId == null) return;
    
    // Set presence status
    _db.child('webrtc/status/$_currentUserId').set(true);
    _db.child('webrtc/status/$_currentUserId').onDisconnect().remove();

    _signalSubscription = _db.child('webrtc/signals/$_currentUserId').onChildAdded.listen((event) {
      if (event.snapshot.value == null) return;
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final type = data['type'];
      final payload = Map<String, dynamic>.from(data['payload'] ?? {});

      _handleIncomingSignal(type, payload);
      
      // Remove signal after processing
      event.snapshot.ref.remove();
    });
  }

  Future<bool> isUserOnline(String userId) async {
    final event = await _db.child('webrtc/status/$userId').once();
    return event.snapshot.value != null;
  }

  Future<void> _handleIncomingSignal(String type, Map<String, dynamic> payload) async {
    switch (type) {
      case 'call-made':
        if (isCallActive) {
          _sendSignal('call-rejected', {'to': payload['from']});
          return;
        }
        _currentCallTarget = payload['from'];
        isVideoCall = payload['isVideo'] ?? false;
        if (onIncomingCall != null) {
          onIncomingCall!(payload);
        }
        break;
      case 'answer-made':
        if (_peerConnection != null) {
          final answer = RTCSessionDescription(payload['answer']['sdp'], payload['answer']['type']);
          await _peerConnection!.setRemoteDescription(answer);
          if (onCallAccepted != null) onCallAccepted!();
        }
        break;
      case 'ice-candidate':
        if (_peerConnection != null) {
          final candidateMap = Map<String, dynamic>.from(payload['candidate']);
          final candidate = RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
        }
        break;
      case 'call-rejected':
      case 'call-ended':
        endCall();
        break;
    }
  }

  void _sendSignal(String type, Map<String, dynamic> payload) {
    if (payload['to'] == null) return;
    final targetRef = _db.child('webrtc/signals/${payload['to']}').push();
    targetRef.set({
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
    
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo,
      });
      if (onLocalStream != null) onLocalStream!(localStream!);

      await _createPeerConnection(targetId);

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _sendSignal('call-made', {
        'to': targetId,
        'from': _currentUserId,
        'isVideo': isVideo,
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        }
      });
      isCallActive = true;
    } catch (e) {
      endCall();
    }
  }

  Future<void> acceptCall(Map<String, dynamic> incomingData) async {
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideoCall,
      });
      if (onLocalStream != null) onLocalStream!(localStream!);

      final targetId = incomingData['from'];
      await _createPeerConnection(targetId);

      final offer = RTCSessionDescription(incomingData['offer']['sdp'], incomingData['offer']['type']);
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

    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;

    remoteStream?.getTracks().forEach((track) => track.stop());
    remoteStream?.dispose();
    remoteStream = null;

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;

    isCallActive = false;
    _currentCallTarget = null;

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
    _db.child('webrtc/status/$_currentUserId').remove();
    endCall();
  }
}
