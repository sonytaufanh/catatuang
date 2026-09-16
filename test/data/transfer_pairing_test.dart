import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/data/database_service.dart';
import 'package:catatuang/data/models/transaction_record.dart';

TransactionRecord _record({
  required int id,
  required bool isExpense,
  required String wallet,
  required String category,
  required int amount,
  DateTime? date,
  DateTime? createdAt,
  String groupId = '',
}) {
  final timestamp = date ?? DateTime(2026, 9, 16, 9);
  return TransactionRecord()
    ..id = id
    ..isExpense = isExpense
    ..amount = amount
    ..wallet = wallet
    ..category = category
    ..transactionDate = timestamp
    ..isCleared = true
    ..transferGroupId = groupId
    ..createdAt = createdAt ?? timestamp;
}

void main() {
  group('isTransferCategory', () {
    test('detects transfer categories regardless of case/space', () {
      expect(DatabaseService.isTransferCategory('transfer_out'), isTrue);
      expect(DatabaseService.isTransferCategory(' Transfer_In '), isTrue);
      expect(DatabaseService.isTransferCategory('food'), isFalse);
    });
  });

  group('isTransferCounterpart', () {
    test('matches by explicit transferGroupId', () {
      final out = _record(
        id: 1,
        isExpense: true,
        wallet: 'cash',
        category: 'transfer_out',
        amount: 100000,
        groupId: 'trf_abc',
      );
      final inLeg = _record(
        id: 2,
        isExpense: false,
        wallet: 'bank',
        category: 'transfer_in',
        amount: 100000,
        groupId: 'trf_abc',
      );
      expect(DatabaseService.isTransferCounterpart(out, inLeg), isTrue);
      expect(DatabaseService.isTransferCounterpart(inLeg, out), isTrue);
    });

    test('does not match different group ids', () {
      final out = _record(
        id: 1,
        isExpense: true,
        wallet: 'cash',
        category: 'transfer_out',
        amount: 100000,
        groupId: 'trf_abc',
      );
      final other = _record(
        id: 3,
        isExpense: false,
        wallet: 'bank',
        category: 'transfer_in',
        amount: 100000,
        groupId: 'trf_xyz',
      );
      expect(DatabaseService.isTransferCounterpart(out, other), isFalse);
    });

    test('falls back to heuristic for legacy transfers without group id', () {
      final created = DateTime(2026, 9, 16, 9, 0, 0);
      final out = _record(
        id: 1,
        isExpense: true,
        wallet: 'cash',
        category: 'transfer_out',
        amount: 50000,
        date: DateTime(2026, 9, 10),
        createdAt: created,
      );
      final inLeg = _record(
        id: 2,
        isExpense: false,
        wallet: 'bank',
        category: 'transfer_in',
        amount: 50000,
        date: DateTime(2026, 9, 10),
        createdAt: created.add(const Duration(milliseconds: 200)),
      );
      expect(DatabaseService.isTransferCounterpart(out, inLeg), isTrue);
    });

    test('rejects different amount, same wallet, or non-transfer', () {
      final created = DateTime(2026, 9, 16, 9);
      final out = _record(
        id: 1,
        isExpense: true,
        wallet: 'cash',
        category: 'transfer_out',
        amount: 50000,
        createdAt: created,
      );
      expect(
        DatabaseService.isTransferCounterpart(
          out,
          _record(
            id: 2,
            isExpense: false,
            wallet: 'bank',
            category: 'transfer_in',
            amount: 99999,
            createdAt: created,
          ),
        ),
        isFalse,
      );
      expect(
        DatabaseService.isTransferCounterpart(
          out,
          _record(
            id: 3,
            isExpense: false,
            wallet: 'cash',
            category: 'transfer_in',
            amount: 50000,
            createdAt: created,
          ),
        ),
        isFalse,
      );
      expect(
        DatabaseService.isTransferCounterpart(
          out,
          _record(
            id: 4,
            isExpense: false,
            wallet: 'bank',
            category: 'salary',
            amount: 50000,
            createdAt: created,
          ),
        ),
        isFalse,
      );
    });
  });
}
