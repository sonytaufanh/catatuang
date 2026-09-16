import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../data/database_service.dart';
import '../data/recurring_bill_store.dart';
import '../data/transaction_store.dart';
import 'backup_crypto_service.dart';
import 'category_budget_service.dart';
import 'master_data_service.dart';
import 'notification_service.dart';
import 'recurring_transaction_service.dart';
import 'savings_goal_service.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const String keyAutoBackup = 'profile_auto_backup';
  static const String keyLastBackupAt = 'last_auto_backup_at';
  static const String _schema = 'catatuang_backup_v3';
  static const String _legacySchema = 'catatuang_backup_v2';
  static const String _legacyChecksumSalt = 'catatuang_local_integrity_salt';
  static const String _encryptionKeyId = 'catatuang_backup_key_v1';
  static const String _keyExportSchema = 'catatuang_key_export_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String> backupNow() async {
    final payload = await DatabaseService.instance.exportBackupPayload();
    payload['masterData'] = await MasterDataService.instance.exportPayload();
    payload['recurringTemplates'] = await RecurringTransactionService.instance
        .exportPayload();
    payload['categoryBudgets'] = await CategoryBudgetService.instance
        .exportPayload();
    payload['savingsGoal'] = await SavingsGoalService.instance.exportPayload();
    final protectedPayload = await _protectPayload(payload);
    final file = await _backupFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(protectedPayload));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastBackupAt, DateTime.now().toIso8601String());
    return file.path;
  }

  Future<bool> restoreFromLatestBackup() async {
    final decoded = await _readLatestBackupEnvelope();
    if (decoded == null) {
      return false;
    }
    final payload = await _extractProtectedPayload(decoded);
    await DatabaseService.instance.restoreBackupPayload(payload);
    final masterData = payload['masterData'];
    if (masterData is Map<String, dynamic>) {
      await MasterDataService.instance.restorePayload(masterData);
    }
    final recurringTemplates = payload['recurringTemplates'];
    if (recurringTemplates is List) {
      await RecurringTransactionService.instance.restorePayload(
        recurringTemplates,
      );
    }
    final categoryBudgets = payload['categoryBudgets'];
    if (categoryBudgets is Map) {
      await CategoryBudgetService.instance.restorePayload(
        Map<String, dynamic>.from(categoryBudgets),
      );
    }
    final savingsGoal = payload['savingsGoal'];
    if (savingsGoal is Map) {
      await SavingsGoalService.instance.restorePayload(
        Map<String, dynamic>.from(savingsGoal),
      );
    }
    await refreshTransactions();
    await refreshRecurringBills();
    await NotificationService.instance.syncFromPreferences();
    return true;
  }

  Future<void> autoBackupIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(keyAutoBackup) ?? true;
    if (!enabled) return;

    final now = DateTime.now();
    final lastRaw = prefs.getString(keyLastBackupAt);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    if (last != null && now.difference(last).inDays < 7) {
      return;
    }
    await backupNow();
    await prefs.setString(keyLastBackupAt, now.toIso8601String());
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyLastBackupAt);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/backups/catatuang_backup.json');
  }

  Future<File> _backupKeyFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/backups/catatuang_backup_key.json');
  }

  Future<String> exportEncryptionKeyToFile() async {
    final key = await _getOrCreateEncryptionKey();
    final file = await _backupKeyFile();
    await file.parent.create(recursive: true);
    final envelope = <String, dynamic>{
      'schema': _keyExportSchema,
      'createdAt': DateTime.now().toIso8601String(),
      'key': base64Encode(key),
    };
    await file.writeAsString(jsonEncode(envelope));
    return file.path;
  }

  Future<bool> importEncryptionKeyFromFile() async {
    final file = await _backupKeyFile();
    if (!await file.exists()) {
      return false;
    }
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format file kunci backup tidak valid.');
    }
    if (decoded['schema'] != _keyExportSchema || decoded['key'] is! String) {
      throw const FormatException('Skema file kunci backup tidak dikenali.');
    }
    await importEncryptionKeyFromToken(decoded['key'] as String);
    return true;
  }

  Future<bool?> validateCurrentKeyForLatestEncryptedBackup() async {
    final envelope = await _readLatestBackupEnvelope();
    if (envelope == null) return null;
    if (envelope['schema'] != _schema) return null;
    try {
      await _extractProtectedPayload(envelope);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> exportEncryptionKeyToken() async {
    final key = await _getOrCreateEncryptionKey();
    return base64Encode(key);
  }

  Future<void> importEncryptionKeyFromToken(String token) async {
    final normalized = token.trim();
    if (!isValidKeyTokenFormat(normalized)) {
      throw const FormatException('Token kunci backup tidak valid.');
    }
    await _secureStorage.write(key: _encryptionKeyId, value: normalized);
  }

  static bool isValidKeyTokenFormat(String token) {
    if (token.isEmpty) return false;
    try {
      final key = base64Decode(token);
      return key.length == 32;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _readLatestBackupEnvelope() async {
    final file = await _backupFile();
    if (!await file.exists()) {
      return null;
    }
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format backup tidak valid.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _protectPayload(
    Map<String, dynamic> payload,
  ) async {
    final key = await _getOrCreateEncryptionKey();
    final encrypted = await BackupCryptoService.encryptJson(
      payload: payload,
      secretKeyBytes: key,
      nonce: _randomBytes(12),
    );
    return <String, dynamic>{
      'schema': _schema,
      'ciphertext': encrypted['ciphertext'],
      'nonce': encrypted['nonce'],
      'mac': encrypted['mac'],
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _extractProtectedPayload(
    Map<String, dynamic> decoded,
  ) async {
    final schema = decoded['schema'];
    if (schema == _schema) {
      final nonce = decoded['nonce'];
      final ciphertext = decoded['ciphertext'];
      final mac = decoded['mac'];
      if (nonce is! String || ciphertext is! String || mac is! String) {
        throw const FormatException('Format backup terenkripsi tidak valid.');
      }
      final key = await _getOrCreateEncryptionKey();
      return BackupCryptoService.decryptJson(
        nonceBase64: nonce,
        ciphertextBase64: ciphertext,
        macBase64: mac,
        secretKeyBytes: key,
      );
    }
    final payload = decoded['payload'];
    final checksum = decoded['checksum'];
    if (schema == _legacySchema && payload is Map<String, dynamic>) {
      final prefs = await SharedPreferences.getInstance();
      final salt = prefs.getString(_legacyChecksumSalt) ?? '';
      final payloadJson = jsonEncode(payload);
      final expected = _fnv1a32('$salt::$payloadJson');
      if (expected != checksum) {
        throw const FormatException(
          'Backup rusak atau tidak valid (checksum mismatch).',
        );
      }
      return payload;
    }
    if (decoded.containsKey('transactions')) {
      return decoded;
    }
    throw const FormatException('Format backup tidak dikenali.');
  }

  String _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;
    var hash = 0x811C9DC5;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<List<int>> _getOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _encryptionKeyId);
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }
    final key = _randomBytes(32);
    await _secureStorage.write(key: _encryptionKeyId, value: base64Encode(key));
    return key;
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(
      length,
      (_) => random.nextInt(256),
      growable: false,
    );
  }
}
