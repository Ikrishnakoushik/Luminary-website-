import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import 'dart:ui';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class CallScreen extends StatefulWidget {
  final WebRTCService webrtcService;
  final bool isIncoming;
  final String targetUserId;
  final String targetUsername;
  final bool isVideoCall;
  final Map<String, dynamic>? incomingData;

  const CallScreen({
    super.key,
    required this.webrtcService,
    required this.isIncoming,
    required this.targetUserId,
    required this.targetUsername,
    required this.isVideoCall,
    this.incomingData,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMicOn = true;
  bool _isCamOn = true;
  bool _isConnected = false;
  bool _isTargetOnline = true; // Assume online until checked
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupCallbacks();
    
    if (widget.isIncoming) {
      // Incoming call: Play ringtone
      _playRingtone(true);
    } else {
      // Outgoing call: check if target is online
      _checkStatusAndCall();
    }
  }

  Future<void> _checkStatusAndCall() async {
    final isOnline = await widget.webrtcService.isUserOnline(widget.targetUserId);
    if (mounted) {
      setState(() {
        _isTargetOnline = isOnline;
      });
      if (mounted) {
        // ALWAYS initiate call regardless of "online" status in DB
        // The background service will catch it on their end!
        widget.webrtcService.initiateCall(widget.targetUserId, widget.isVideoCall);
        _playRingtone(false);
      }
    }
  }

  void _playRingtone(bool isIncoming) {
    _isRinging = true;
    if (isIncoming) {
      FlutterRingtonePlayer().playRingtone(looping: true);
    } else {
      // Play a dialing tone or generic notification for outgoing
      FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: true,
        volume: 0.5,
      );
    }
  }

  void _stopRingtone() {
    if (_isRinging) {
      FlutterRingtonePlayer().stop();
      _isRinging = false;
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupCallbacks() {
    widget.webrtcService.onLocalStream = (stream) {
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      }
    };

    widget.webrtcService.onRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isConnected = true;
          _stopRingtone();
        });
      }
    };

    widget.webrtcService.onCallEnded = () {
      _stopRingtone();
      if (mounted) {
        Navigator.pop(context);
      }
    };

    widget.webrtcService.onCallAccepted = () {
      _stopRingtone();
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
      }
    };
  }

  @override
  void dispose() {
    _stopRingtone();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _toggleMic() {
    setState(() {
      _isMicOn = !_isMicOn;
    });
    widget.webrtcService.toggleMic();
  }

  void _toggleCam() {
    setState(() {
      _isCamOn = !_isCamOn;
    });
    widget.webrtcService.toggleCamera();
  }

  void _endCall() {
    if (widget.isIncoming && !_isConnected) {
      widget.webrtcService.rejectCall();
    } else {
      widget.webrtcService.endCall();
    }
    _stopRingtone();
    Navigator.pop(context);
  }

  void _acceptCall() {
    _stopRingtone();
    if (widget.incomingData != null) {
      widget.webrtcService.acceptCall(widget.incomingData!);
    }
  }

  String _getStatusText() {
    if (_isConnected) return 'Connected';
    if (widget.isIncoming) return 'Incoming Call...';
    if (!_isTargetOnline) return 'Offline';
    return 'Ringing...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video or Avatar background
          if (widget.isVideoCall && _isConnected)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white12,
                      child: Icon(Icons.person, size: 60, color: Colors.white54),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.targetUsername,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusText(),
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Local Video (PiP)
          if (widget.isVideoCall && _isCamOn && (_isConnected || !widget.isIncoming))
            Positioned(
              right: 20,
              bottom: 120,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.isIncoming && !_isConnected) ...[
                  _buildControlButton(Icons.call_end, Colors.red, _endCall),
                  _buildControlButton(Icons.call, Colors.green, _acceptCall),
                ] else ...[
                  _buildControlButton(_isMicOn ? Icons.mic : Icons.mic_off, _isMicOn ? Colors.white24 : Colors.red, _toggleMic),
                  if (widget.isVideoCall)
                    _buildControlButton(_isCamOn ? Icons.videocam : Icons.videocam_off, _isCamOn ? Colors.white24 : Colors.red, _toggleCam),
                  _buildControlButton(Icons.call_end, Colors.red, _endCall),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            color: color,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}
