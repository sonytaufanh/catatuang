import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Password/PIN hashing using PBKDF2-HMAC-SHA256 with a random per-secret
/// salt and constant-time verification.
///
/// Format: `pbkdf2$<iterations>$<saltBase64>$<hashBase64>`.
class PasswordHasher {
  PasswordHasher._();

  static const int iterations = 120000;
  static const int _bits = 256;
  static const String _prefix = 'pbkdf2';

  static bool isHashed(String stored) => stored.startsWith('$_prefix\$');

  static Future<String> hash(String value) async {
    final salt = _randomSalt();
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _bits,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(value)),
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return '$_prefix\$$iterations\$${base64Encode(salt)}\$${base64Encode(bytes)}';
  }

  static Future<bool> verify(String value, String stored) async {
    if (!isHashed(stored)) return false;
    final parts = stored.split('\$');
    if (parts.length != 4) return false;
    final parsedIterations = int.tryParse(parts[1]);
    if (parsedIterations == null || parsedIterations <= 0) return false;
    late final List<int> salt;
    late final List<int> expected;
    try {
      salt = base64Decode(parts[2]);
      expected = base64Decode(parts[3]);
    } catch (_) {
      return false;
    }
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: parsedIterations,
      bits: _bits,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(value)),
      nonce: salt,
    );
    final actual = await key.extractBytes();
    return _constantTimeEquals(actual, expected);
  }

  static List<int> _randomSalt() => List<int>.generate(
    16,
    (_) => Random.secure().nextInt(256),
    growable: false,
  );

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
