import 'dart:async';
import 'package:flutter/foundation.dart';
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
  // Group Calling State
  String? activeGroupId;
  final Map<String, RTCPeerConnection> _groupPeerConnections = {};
  final Map<String, MediaStream> _groupRemoteStreams = {};
  final Map<String, List<RTCIceCandidate>> _groupQueuedCandidates = {};

  Function(String participantId, MediaStream stream)? onGroupRemoteStream;
  Function(String participantId)? onGroupParticipantLeft;
  Function(String participantId)? onGroupParticipantJoined;
  StreamSubscription<Map<String, dynamic>>? _groupUserJoinedSub;
  StreamSubscription<Map<String, dynamic>>? _groupUserLeftSub;

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
  final List<RTCIceCandidate> _queuedIceCandidates = [];

  void _listenForSignals() {
    if (_currentUserId == null) return;
    
    _signalSubscription?.cancel();
    _groupUserJoinedSub?.cancel();
    _groupUserLeftSub?.cancel();
    if (activeGroupId != null) leaveGroupCall();
    // Instead of Firebase, we listen to our global SocketService stream for 'webrtc_signal' events
    _signalSubscription = _socketService.onWebRTCSignal.listen((data) {
      final type = data['type'];
      final payload = Map<String, dynamic>.from(data['payload'] ?? {});
      _handleIncomingSignal(type, payload);
    });
    _groupUserJoinedSub?.cancel();
    _groupUserJoinedSub = _socketService.onUserJoinedCall.listen((data) {
      if (activeGroupId == null) return;
      final participantId = data['userId'];
      if (participantId != null && participantId != _currentUserId) {
        _initiateGroupPeerConnection(participantId);
        onGroupParticipantJoined?.call(participantId);
      }
    });

    _groupUserLeftSub?.cancel();
    _groupUserLeftSub = _socketService.onUserLeftCall.listen((data) {
      if (activeGroupId == null) return;
      final participantId = data['userId'];
      if (participantId != null) {
        _removeGroupPeer(participantId);
        onGroupParticipantLeft?.call(participantId);
      }
    });
    // end group listeners
  }

    Future<RTCPeerConnection> _createGroupPeerConnection(String targetId) async {
    if (_groupPeerConnections.containsKey(targetId)) {
      return _groupPeerConnections[targetId]!;
    }

    final pc = await createPeerConnection(_iceServers);
    _groupPeerConnections[targetId] = pc;

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await pc.addTrack(track, localStream!);
      }
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _sendSignal('ice-candidate', {
        'to': targetId,
        'from': _currentUserId,
        'isGroupCall': true,
        'groupId': activeGroupId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _groupRemoteStreams[targetId] = stream;
        onGroupRemoteStream?.call(targetId, stream);
      }
    };

    return pc;
  }

  Future<void> _initiateGroupPeerConnection(String targetId) async {
    try {
      final pc = await _createGroupPeerConnection(targetId);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      _sendSignal('call-made', {
        'to': targetId,
        'from': _currentUserId,
        'isGroupCall': true,
        'groupId': activeGroupId,
        'isVideo': isVideoCall,
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        }
      });
    } catch (e) {
      debugPrint('Failed to initiate group peer connection to $targetId: $e');
    }
  }

  Future<void> _handleGroupOffer(String fromId, Map<String, dynamic> offerData) async {
    try {
      final pc = await _createGroupPeerConnection(fromId);
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      await pc.setRemoteDescription(offer);
      await _drainGroupQueuedCandidates(fromId);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _sendSignal('answer-made', {
        'to': fromId,
        'from': _currentUserId,
        'isGroupCall': true,
        'groupId': activeGroupId,
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        }
      });
    } catch (e) {
      debugPrint('Error handling group offer from $fromId: $e');
    }
  }

  Future<void> _drainGroupQueuedCandidates(String targetId) async {
    final pc = _groupPeerConnections[targetId];
    if (pc == null) return;
    final list = _groupQueuedCandidates[targetId] ?? [];
    _groupQueuedCandidates.remove(targetId);
    for (final candidate in list) {
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        // Safe candidate ignore
      }
    }
  }

  void _removeGroupPeer(String participantId) {
    if (_groupPeerConnections.containsKey(participantId)) {
      _groupPeerConnections[participantId]?.close();
      _groupPeerConnections[participantId]?.dispose();
      _groupPeerConnections.remove(participantId);
    }
    if (_groupRemoteStreams.containsKey(participantId)) {
      _groupRemoteStreams[participantId]?.dispose();
      _groupRemoteStreams.remove(participantId);
    }
    _groupQueuedCandidates.remove(participantId);
  }

  Future<void> joinGroupCall(String groupId, bool isVideo) async {
    activeGroupId = groupId;
    isVideoCall = isVideo;
    isCallActive = true;

    try {
      localStream = await _acquireMedia(isVideo);
      if (onLocalStream != null && localStream != null) {
        onLocalStream!(localStream!);
      }

      _socketService.emit('join-group-call', {
        'groupId': groupId,
        'userId': _currentUserId,
      });
    } catch (e) {
      leaveGroupCall();
      rethrow;
    }
  }

  void leaveGroupCall() {
    if (activeGroupId != null) {
      _socketService.emit('leave-group-call', {
        'groupId': activeGroupId,
        'userId': _currentUserId,
      });
    }

    for (final id in _groupPeerConnections.keys.toList()) {
      _removeGroupPeer(id);
    }

    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;

    activeGroupId = null;
    isCallActive = false;
    if (onCallEnded != null) onCallEnded!();
  }

  Future<void> _drainQueuedCandidates() async {
    if (_peerConnection == null) return;
    final candidates = List<RTCIceCandidate>.from(_queuedIceCandidates);
    _queuedIceCandidates.clear();
    for (final candidate in candidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        // Safe candidate drop if already connected
      }
    }
  }

  Future<bool> isUserOnline(String targetId) async {
    // With pure WebRTC via sockets, we can assume online, 
    // or we could implement a ping/pong over socket.
    // For now, always try.
    return true; 
  }

  Future<void> _handleIncomingSignal(String type, Map<String, dynamic> payload) async {
    // Handle group signals if activeGroupId is set or payload indicates group call
    if (activeGroupId != null || payload['isGroupCall'] == true) {
      final senderId = payload['from']?.toString();
      if (senderId == null || senderId == _currentUserId) return;

      switch (type) {
        case 'call-made':
          if (payload['offer'] != null) {
            await _handleGroupOffer(senderId, Map<String, dynamic>.from(payload['offer']));
          }
          break;
        case 'answer-made':
          final pc = _groupPeerConnections[senderId];
          if (pc != null && payload['answer'] != null) {
            final answer = RTCSessionDescription(payload['answer']['sdp'], payload['answer']['type']);
            await pc.setRemoteDescription(answer);
            await _drainGroupQueuedCandidates(senderId);
          }
          break;
        case 'ice-candidate':
          if (payload['candidate'] != null) {
            final candidate = RTCIceCandidate(
              payload['candidate']['candidate'],
              payload['candidate']['sdpMid'],
              payload['candidate']['sdpMLineIndex'],
            );
            final pc = _groupPeerConnections[senderId];
            if (pc != null) {
              final remoteDesc = await pc.getRemoteDescription();
              if (remoteDesc != null) {
                await pc.addCandidate(candidate);
              } else {
                _groupQueuedCandidates.putIfAbsent(senderId, () => []).add(candidate);
              }
            } else {
              _groupQueuedCandidates.putIfAbsent(senderId, () => []).add(candidate);
            }
          }
          break;
      }
      return;
    }

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
        await _drainQueuedCandidates();
        if (onCallAccepted != null) onCallAccepted!();
        break;
      case 'ice-candidate':
        final candidate = RTCIceCandidate(
          payload['candidate']['candidate'],
          payload['candidate']['sdpMid'],
          payload['candidate']['sdpMLineIndex'],
        );
        if (_peerConnection != null) {
          final remoteDesc = await _peerConnection!.getRemoteDescription();
          if (remoteDesc != null) {
            await _peerConnection!.addCandidate(candidate);
          } else {
            _queuedIceCandidates.add(candidate);
          }
        } else {
          _queuedIceCandidates.add(candidate);
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

    Future<MediaStream?> _acquireMedia(bool requestVideo) async {
    if (!requestVideo) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw Exception('Microphone permission is required for voice calls.');
      }
      return await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    }

    // Video Call: Request both mic and camera
    final micStatus = await Permission.microphone.request();
    final camStatus = await Permission.camera.request();

    if (!micStatus.isGranted) {
      throw Exception('Microphone permission is required for calls.');
    }

    if (camStatus.isGranted) {
      try {
        return await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': true,
        });
      } catch (e) {
        // Fallback to audio if camera hardware is busy or fails
        isVideoCall = false;
        return await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
      }
    } else {
      // Camera denied, graceful fallback to audio-only
      isVideoCall = false;
      return await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    }
  }

  Future<void> initiateCall(String targetId, bool isVideo) async {
    _currentCallTarget = targetId;
    isVideoCall = isVideo;
    _isCallConnected = false;
    
    try {
      localStream = await _acquireMedia(isVideo);
      isVideo = isVideoCall;
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
      if (payloadToUse == null || payloadToUse['offer'] == null) {
        throw Exception("No incoming offer payload found");
      }

      isVideoCall = payloadToUse['isVideo'] ?? isVideoCall;
      localStream = await _acquireMedia(isVideoCall);
      if (onLocalStream != null && localStream != null) onLocalStream!(localStream!);

      final targetId = payloadToUse['from'];
      await _createPeerConnection(targetId);

      final offer = RTCSessionDescription(payloadToUse['offer']['sdp'], payloadToUse['offer']['type']);
      await _peerConnection!.setRemoteDescription(offer);
      await _drainQueuedCandidates();

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
    _queuedIceCandidates.clear();
    
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
