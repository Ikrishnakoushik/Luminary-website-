import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class E2EEService {
  static final E2EEService instance = E2EEService._internal();
  E2EEService._internal();

  final _ecdh = Ecdh.p256(length: 32);
  final _aesGcm = AesGcm.with256bits();

  KeyPair? _myKeyPair;
  String? _myPublicKeyBase64;
  String? _currentUserId;
  final Map<String, String> _userPublicKeysCache = {};
  final Map<String, SecretKey> _sharedKeysCache = {};

  bool get isReady => _myKeyPair != null && _myPublicKeyBase64 != null;
  String? get currentUserId => _currentUserId;

  /// Initialize device keys for the logged-in user
  Future<void> init(String userId, String token, String baseUrl) async {
    if (userId.isEmpty) return;
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();

    final privKeyB64 = prefs.getString('vyl_e2ee_priv_$userId');
    final pubKeyB64 = prefs.getString('vyl_e2ee_pub_$userId');

    if (privKeyB64 == null || pubKeyB64 == null) {
      // Generate fresh ECDH P-256 Keypair
      _myKeyPair = await _ecdh.newKeyPair();
      final keyPairData = await _myKeyPair!.extract();
      _myPublicKeyBase64 = base64Encode(keyPairData.publicKey.bytes);

      final privBytes = keyPairData.bytes;
      await prefs.setString('vyl_e2ee_priv_$userId', base64Encode(privBytes));
      await prefs.setString('vyl_e2ee_pub_$userId', _myPublicKeyBase64!);

      // Sync public key to backend
      try {
        await http.post(
          Uri.parse('$baseUrl/users/keys'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'x-auth-token': token,
          },
          body: jsonEncode({'publicKey': _myPublicKeyBase64}),
        );
      } catch (e) {
        // Retry later
      }
    } else {
      final privBytes = base64Decode(privKeyB64);
      _myKeyPair = await _ecdh.newKeyPairFromSeed(privBytes);
      _myPublicKeyBase64 = pubKeyB64;
    }
  }

  /// Fetch recipient's public key from backend or memory cache
  Future<String?> getRecipientPublicKey(String otherUserId, String token, String baseUrl) async {
    if (_userPublicKeysCache.containsKey(otherUserId)) {
      return _userPublicKeysCache[otherUserId];
    }
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/users/$otherUserId/public-key'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-auth-token': token,
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && data['publicKey'] != null) {
          final pk = data['publicKey'].toString();
          _userPublicKeysCache[otherUserId] = pk;
          return pk;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Derive shared AES-GCM-256 key with recipient
  Future<SecretKey?> getSharedKey(String otherUserId, String token, String baseUrl) async {
    if (_sharedKeysCache.containsKey(otherUserId)) {
      return _sharedKeysCache[otherUserId];
    }
    if (_myKeyPair == null) return null;

    final remotePubB64 = await getRecipientPublicKey(otherUserId, token, baseUrl);
    if (remotePubB64 == null) return null;

    try {
      final pubBytes = base64Decode(remotePubB64);
      // If public key is standard 91-byte SPKI, extract the 65-byte uncompressed point
      List<int> rawPointBytes = pubBytes;
      if (pubBytes.length > 65) {
        rawPointBytes = pubBytes.sublist(pubBytes.length - 65);
      }
      final remotePublicKey = SimplePublicKey(rawPointBytes, type: KeyPairType.p256);

      final sharedSecret = await _ecdh.sharedSecretKey(
        keyPair: _myKeyPair!,
        remotePublicKey: remotePublicKey,
      );

      _sharedKeysCache[otherUserId] = sharedSecret;
      return sharedSecret;
    } catch (e) {
      return null;
    }
  }

  /// Encrypt outgoing message using AES-GCM-256 with 12-byte random nonce
  Future<Map<String, dynamic>> encryptMessage(String plaintext, String otherUserId, String token, String baseUrl) async {
    final sharedKey = await getSharedKey(otherUserId, token, baseUrl);
    if (sharedKey == null) {
      // Fallback
      return {'content': plaintext, 'iv': null, 'isE2EE': false};
    }

    try {
      final secretBox = await _aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: sharedKey,
      );

      final combinedCipherBytes = [...secretBox.cipherText, ...secretBox.mac.bytes];
      return {
        'content': base64Encode(combinedCipherBytes),
        'iv': base64Encode(secretBox.nonce),
        'isE2EE': true,
      };
    } catch (e) {
      return {'content': plaintext, 'iv': null, 'isE2EE': false};
    }
  }

  /// Decrypt incoming message
  Future<String> decryptMessage(String ciphertextB64, String? ivB64, String otherUserId, String token, String baseUrl) async {
    if (ivB64 == null || ivB64.isEmpty) return ciphertextB64;

    final sharedKey = await getSharedKey(otherUserId, token, baseUrl);
    if (sharedKey == null) return ciphertextB64;

    try {
      final allBytes = base64Decode(ciphertextB64);
      if (allBytes.length <= 16) return ciphertextB64;

      final cipherBytes = allBytes.sublist(0, allBytes.length - 16);
      final macBytes = allBytes.sublist(allBytes.length - 16);
      final nonceBytes = base64Decode(ivB64);

      final secretBox = SecretBox(
        cipherBytes,
        nonce: nonceBytes,
        mac: Mac(macBytes),
      );

      final decryptedBytes = await _aesGcm.decrypt(secretBox, secretKey: sharedKey);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      return '🔒 [Encrypted Message]';
    }
  }
}

