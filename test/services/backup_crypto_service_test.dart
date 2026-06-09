import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/services/backup_crypto_service.dart';

void main() {
  group('BackupCryptoService', () {
    test('encrypt and decrypt payload roundtrip', () async {
      final payload = <String, dynamic>{
        'version': 1,
        'transactions': [
          {'amount': 1000, 'category': 'food'},
        ],
      };
      final key = List<int>.generate(32, (i) => i + 1);
      final nonce = List<int>.generate(12, (i) => i + 10);

      final encrypted = await BackupCryptoService.encryptJson(
        payload: payload,
        secretKeyBytes: key,
        nonce: nonce,
      );

      final decrypted = await BackupCryptoService.decryptJson(
        nonceBase64: encrypted['nonce']!,
        ciphertextBase64: encrypted['ciphertext']!,
        macBase64: encrypted['mac']!,
        secretKeyBytes: key,
      );

      expect(decrypted, payload);
    });

    test('throws when key is wrong', () async {
      final payload = <String, dynamic>{'hello': 'world'};
      final key = List<int>.filled(32, 7);
      final wrongKey = List<int>.filled(32, 9);
      final nonce = List<int>.generate(12, (i) => i + 2);
      final encrypted = await BackupCryptoService.encryptJson(
        payload: payload,
        secretKeyBytes: key,
        nonce: nonce,
      );

      expect(
        () => BackupCryptoService.decryptJson(
          nonceBase64: encrypted['nonce']!,
          ciphertextBase64: encrypted['ciphertext']!,
          macBase64: encrypted['mac']!,
          secretKeyBytes: wrongKey,
        ),
        throwsA(isA<Object>()),
      );
    });
  });
}
