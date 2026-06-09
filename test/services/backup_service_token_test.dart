import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/services/backup_service.dart';

void main() {
  group('BackupService.isValidKeyTokenFormat', () {
    test('accepts 32-byte base64 token', () {
      final token = base64Encode(List<int>.filled(32, 1));
      expect(BackupService.isValidKeyTokenFormat(token), isTrue);
    });

    test('rejects invalid base64 token', () {
      expect(BackupService.isValidKeyTokenFormat('###bad###'), isFalse);
    });

    test('rejects non-32-byte token', () {
      final token = base64Encode(List<int>.filled(16, 1));
      expect(BackupService.isValidKeyTokenFormat(token), isFalse);
    });
  });
}
