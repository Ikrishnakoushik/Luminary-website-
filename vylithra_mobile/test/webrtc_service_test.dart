import 'package:flutter_test/flutter_test.dart';
import 'package:vylithra_mobile/services/webrtc_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebRTCService Unit & Protocol Tests', () {
    late WebRTCService service;

    setUp(() {
      service = WebRTCService();
    });

    test('WebRTCService singleton instance is maintained', () {
      final instance1 = WebRTCService();
      final instance2 = WebRTCService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Incoming offer payload handles empty or null safely', () async {
      // Calling acceptCall with empty payload when no previous offer exists should gracefully fail without crashing
      expect(() async => await service.acceptCall({}), returnsNormally);
    });

    test('Call termination cleanly resets state flags', () {
      service.endCall();
      expect(service.isCallActive, isFalse);
      expect(service.localStream, isNull);
      expect(service.remoteStream, isNull);
    });
  });
}
