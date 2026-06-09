import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class BackupCryptoService {
  BackupCryptoService._();

  static final AesGcm _cipher = AesGcm.with256bits();

  static Future<Map<String, String>> encryptJson({
    required Map<String, dynamic> payload,
    required List<int> secretKeyBytes,
    required List<int> nonce,
  }) async {
    final clearText = utf8.encode(jsonEncode(payload));
    final secretKey = SecretKey(secretKeyBytes);
    final secretBox = await _cipher.encrypt(
      clearText,
      secretKey: secretKey,
      nonce: nonce,
    );

    return <String, String>{
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  static Future<Map<String, dynamic>> decryptJson({
    required String nonceBase64,
    required String ciphertextBase64,
    required String macBase64,
    required List<int> secretKeyBytes,
  }) async {
    final nonce = base64Decode(nonceBase64);
    final cipherText = base64Decode(ciphertextBase64);
    final macBytes = base64Decode(macBase64);
    final secretKey = SecretKey(secretKeyBytes);
    final clearText = await _cipher.decrypt(
      SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      ),
      secretKey: secretKey,
    );
    final decoded = jsonDecode(utf8.decode(clearText));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Payload backup tidak valid.');
    }
    return decoded;
  }
}
