import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:catatuang/data/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  final db = DatabaseService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_currency': 'IDR'});
    await db.initForTesting(factory: databaseFactoryFfi);
    await db.clearAllData();
  });

  test('adds and reads a transaction with resolved currency', () async {
    await db.addTransaction(
      isExpense: true,
      amount: 25000,
      wallet: 'cash',
      category: 'food',
      transactionDate: DateTime(2026, 9, 16),
      isCleared: true,
      note: 'kopi',
    );
    final all = await db.getAllTransactions();
    expect(all, hasLength(1));
    expect(all.first.amount, 25000);
    expect(all.first.currency, 'IDR');
  });

  test('updates and deletes a transaction', () async {
    await db.addTransaction(
      isExpense: true,
      amount: 10000,
      wallet: 'cash',
      category: 'food',
      transactionDate: DateTime(2026, 9, 16),
      isCleared: true,
    );
    var tx = (await db.getAllTransactions()).first;
    await db.updateTransaction(
      id: tx.id,
      isExpense: false,
      amount: 20000,
      wallet: 'bank',
      category: 'salary',
      transactionDate: DateTime(2026, 9, 17),
      isCleared: true,
    );
    tx = (await db.getAllTransactions()).first;
    expect(tx.isExpense, isFalse);
    expect(tx.amount, 20000);
    expect(tx.category, 'salary');

    await db.deleteTransaction(tx.id);
    expect(await db.getAllTransactions(), isEmpty);
  });

  test('transfer creates two legs and paired delete removes both', () async {
    await db.addTransfer(
      amount: 100000,
      sourceWallet: 'cash',
      destWallet: 'bank',
      transactionDate: DateTime(2026, 9, 16),
    );
    var all = await db.getAllTransactions();
    expect(all, hasLength(2));
    expect(all.every((t) => t.transferGroupId.isNotEmpty), isTrue);

    await db.deleteTransactionWithPair(all.first);
    all = await db.getAllTransactions();
    expect(all, isEmpty);
  });

  test('split group delete removes all parts', () async {
    await db.addSplitTransaction(
      isExpense: true,
      wallet: 'cash',
      transactionDate: DateTime(2026, 9, 16),
      parts: const [
        SplitPart(category: 'food', amount: 10000),
        SplitPart(category: 'shopping', amount: 15000),
      ],
    );
    final all = await db.getAllTransactions();
    expect(all, hasLength(2));
    await db.deleteTransactionDeep(all.first);
    expect(await db.getAllTransactions(), isEmpty);
  });

  test('cycle expense total excludes transfers', () async {
    await db.addTransaction(
      isExpense: true,
      amount: 50000,
      wallet: 'cash',
      category: 'food',
      transactionDate: DateTime(2026, 9, 10),
      isCleared: true,
    );
    await db.addTransfer(
      amount: 999999,
      sourceWallet: 'cash',
      destWallet: 'bank',
      transactionDate: DateTime(2026, 9, 11),
    );
    final total = await db.getCycleExpenseTotal(DateTime(2026, 9, 16), 1);
    expect(total, 50000);
  });

  test('watchTransactions emits after a write', () async {
    final future = db.watchTransactions().skip(1).first;
    await db.addTransaction(
      isExpense: true,
      amount: 1000,
      wallet: 'cash',
      category: 'food',
      transactionDate: DateTime(2026, 9, 16),
      isCleared: true,
    );
    final emitted = await future;
    expect(emitted, hasLength(1));
    expect(emitted.first.amount, 1000);
  });

  test('debt payment updates remaining and records a transaction', () async {
    await db.addDebt(name: 'Budi', isReceivable: false, amount: 100000);
    final debt = (await db.getAllDebts()).first;
    await db.applyDebtPayment(
      debtId: debt.id,
      amount: 40000,
      wallet: 'bank',
      category: 'bills',
      transactionDate: DateTime(2026, 9, 16),
    );
    final updated = (await db.getAllDebts()).first;
    expect(updated.remaining, 60000);
    expect(updated.isSettled, isFalse);
    expect(await db.getAllTransactions(), hasLength(1));
  });

  test('backup payload round-trips transactions and bills', () async {
    await db.addTransaction(
      isExpense: true,
      amount: 12345,
      wallet: 'cash',
      category: 'food',
      transactionDate: DateTime(2026, 9, 16),
      isCleared: true,
    );
    await db.addRecurringBill(name: 'Listrik', amount: 200000, dueDay: 20);
    final payload = await db.exportBackupPayload();

    await db.clearAllData();
    expect(await db.getAllTransactions(), isEmpty);

    await db.restoreBackupPayload(payload);
    expect(await db.getAllTransactions(), hasLength(1));
    expect(await db.getAllRecurringBills(), hasLength(1));
  });

  test('deleteTransactionDeep handles plain transactions', () async {
    await db.addTransaction(
      isExpense: true,
      amount: 100,
      wallet: 'cash',
      category: 'food',
      transactionDate: DateTime(2026, 9, 16),
      isCleared: true,
    );
    final tx = (await db.getAllTransactions()).first;
    await db.deleteTransactionDeep(tx);
    expect(await db.getAllTransactions(), isEmpty);
  });
}
