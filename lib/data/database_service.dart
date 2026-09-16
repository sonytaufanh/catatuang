import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'models/debt_record.dart';
import 'models/recurring_bill_record.dart';
import 'models/transaction_record.dart';

/// One category line of a split transaction.
class SplitPart {
  const SplitPart({
    required this.category,
    required this.amount,
    this.note = '',
  });

  final String category;
  final int amount;
  final String note;
}

/// Local persistence backed by SQLite (SQLCipher, encrypted at rest).
///
/// Public API is intentionally stable so stores and screens do not need to
/// know about the underlying database.
class DatabaseService {
  DatabaseService._();
  static const int maxAmount = 1000000000;
  static const String _transferBackfillKey = 'transfer_group_backfill_v1';
  static const String _dbKeyStorageKey = 'catatuang_db_encryption_key_v2';
  static const int _schemaVersion = 1;

  static final DatabaseService instance = DatabaseService._();
  final Random _random = Random();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('Database belum diinisialisasi.');
    }
    return db;
  }

  final StreamController<List<TransactionRecord>> _transactionsController =
      StreamController<List<TransactionRecord>>.broadcast();
  final StreamController<List<RecurringBillRecord>> _recurringBillsController =
      StreamController<List<RecurringBillRecord>>.broadcast();
  final StreamController<List<DebtRecord>> _debtsController =
      StreamController<List<DebtRecord>>.broadcast();

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/catatuang.db';
    final password = await _resolveEncryptionKey();
    _db = await openDatabase(
      path,
      password: password,
      version: _schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  /// Opens an unencrypted in-memory/file database for tests using a custom
  /// factory (e.g. `databaseFactoryFfi`).
  Future<void> initForTesting({
    required DatabaseFactory factory,
    String path = inMemoryDatabasePath,
  }) async {
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        singleInstance: false,
      ),
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        isExpense INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        wallet TEXT NOT NULL,
        category TEXT NOT NULL,
        transactionDate INTEGER NOT NULL,
        isCleared INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        receiptPath TEXT NOT NULL DEFAULT '',
        transferGroupId TEXT NOT NULL DEFAULT '',
        splitGroupId TEXT NOT NULL DEFAULT '',
        currency TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_tx_date ON transactions(transactionDate DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_tx_transfer ON transactions(transferGroupId)',
    );
    await db.execute(
      'CREATE INDEX idx_tx_split ON transactions(splitGroupId)',
    );

    await db.execute('''
      CREATE TABLE recurring_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        dueDay INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        isReceivable INTEGER NOT NULL,
        principal INTEGER NOT NULL,
        remaining INTEGER NOT NULL,
        dueDate INTEGER,
        note TEXT NOT NULL DEFAULT '',
        interestRatePercent REAL NOT NULL DEFAULT 0,
        isSettled INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  Future<String> _resolveEncryptionKey() async {
    final stored = await _secureStorage.read(key: _dbKeyStorageKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final key = base64Encode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await _secureStorage.write(key: _dbKeyStorageKey, value: key);
    return key;
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  Map<String, Object?> _txToRow(TransactionRecord r, {bool includeId = false}) {
    return <String, Object?>{
      if (includeId) 'id': r.id,
      'isExpense': r.isExpense ? 1 : 0,
      'amount': r.amount,
      'wallet': r.wallet,
      'category': r.category,
      'transactionDate': r.transactionDate.millisecondsSinceEpoch,
      'isCleared': r.isCleared ? 1 : 0,
      'note': r.note,
      'receiptPath': r.receiptPath,
      'transferGroupId': r.transferGroupId,
      'splitGroupId': r.splitGroupId,
      'currency': r.currency,
      'createdAt': r.createdAt.millisecondsSinceEpoch,
    };
  }

  TransactionRecord _txFromRow(Map<String, Object?> row) {
    return TransactionRecord(
      id: (row['id'] as num).toInt(),
      isExpense: (row['isExpense'] as num).toInt() == 1,
      amount: (row['amount'] as num).toInt(),
      wallet: (row['wallet'] as String?) ?? '',
      category: (row['category'] as String?) ?? '',
      transactionDate: DateTime.fromMillisecondsSinceEpoch(
        (row['transactionDate'] as num).toInt(),
      ),
      isCleared: (row['isCleared'] as num).toInt() == 1,
      note: (row['note'] as String?) ?? '',
      receiptPath: (row['receiptPath'] as String?) ?? '',
      transferGroupId: (row['transferGroupId'] as String?) ?? '',
      splitGroupId: (row['splitGroupId'] as String?) ?? '',
      currency: (row['currency'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['createdAt'] as num).toInt(),
      ),
    );
  }

  Map<String, Object?> _billToRow(
    RecurringBillRecord r, {
    bool includeId = false,
  }) {
    return <String, Object?>{
      if (includeId) 'id': r.id,
      'name': r.name,
      'amount': r.amount,
      'dueDay': r.dueDay,
      'createdAt': r.createdAt.millisecondsSinceEpoch,
    };
  }

  RecurringBillRecord _billFromRow(Map<String, Object?> row) {
    return RecurringBillRecord(
      id: (row['id'] as num).toInt(),
      name: (row['name'] as String?) ?? '',
      amount: (row['amount'] as num).toInt(),
      dueDay: (row['dueDay'] as num).toInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['createdAt'] as num).toInt(),
      ),
    );
  }

  Map<String, Object?> _debtToRow(DebtRecord r, {bool includeId = false}) {
    return <String, Object?>{
      if (includeId) 'id': r.id,
      'name': r.name,
      'isReceivable': r.isReceivable ? 1 : 0,
      'principal': r.principal,
      'remaining': r.remaining,
      'dueDate': r.dueDate?.millisecondsSinceEpoch,
      'note': r.note,
      'interestRatePercent': r.interestRatePercent,
      'isSettled': r.isSettled ? 1 : 0,
      'createdAt': r.createdAt.millisecondsSinceEpoch,
    };
  }

  DebtRecord _debtFromRow(Map<String, Object?> row) {
    final due = row['dueDate'];
    return DebtRecord(
      id: (row['id'] as num).toInt(),
      name: (row['name'] as String?) ?? '',
      isReceivable: (row['isReceivable'] as num).toInt() == 1,
      principal: (row['principal'] as num).toInt(),
      remaining: (row['remaining'] as num).toInt(),
      dueDate: due == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((due as num).toInt()),
      note: (row['note'] as String?) ?? '',
      interestRatePercent:
          (row['interestRatePercent'] as num?)?.toDouble() ?? 0,
      isSettled: (row['isSettled'] as num).toInt() == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['createdAt'] as num).toInt(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Transfer/split helpers
  // ---------------------------------------------------------------------------

  static bool isTransferCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return normalized == 'transfer_out' || normalized == 'transfer_in';
  }

  static bool isTransferCounterpart(
    TransactionRecord tx,
    TransactionRecord candidate,
  ) {
    if (!isTransferCategory(tx.category)) return false;
    if (candidate.id == tx.id) return false;
    final group = tx.transferGroupId.trim();
    if (group.isNotEmpty) {
      return candidate.transferGroupId.trim() == group;
    }
    return _legacyTransferMatch(tx, candidate);
  }

  static bool _legacyTransferMatch(
    TransactionRecord tx,
    TransactionRecord candidate,
  ) {
    if (!isTransferCategory(candidate.category)) return false;
    final expected = tx.category.trim().toLowerCase() == 'transfer_out'
        ? 'transfer_in'
        : 'transfer_out';
    if (candidate.category.trim().toLowerCase() != expected) return false;
    if (candidate.amount != tx.amount) return false;
    if (candidate.wallet == tx.wallet) return false;
    if (candidate.transactionDate != tx.transactionDate) return false;
    return candidate.createdAt.difference(tx.createdAt).inSeconds.abs() <= 1;
  }

  static bool isSameSplitGroup(TransactionRecord a, TransactionRecord b) {
    final group = a.splitGroupId.trim();
    return group.isNotEmpty && group == b.splitGroupId.trim();
  }

  String _newTransferGroupId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = _random.nextInt(0x7fffffff).toRadixString(16);
    return 'trf_${now}_$rand';
  }

  String _newSplitGroupId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = _random.nextInt(0x7fffffff).toRadixString(16);
    return 'spl_${now}_$rand';
  }

  Future<String> _resolveCurrency(String provided) async {
    final normalized = provided.trim().toUpperCase();
    if (normalized.isNotEmpty) return normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('app_currency') ?? 'IDR';
    } catch (_) {
      return 'IDR';
    }
  }

  Future<void> _emitTransactions() async {
    if (!_transactionsController.hasListener) return;
    _transactionsController.add(await getAllTransactions());
  }

  Future<void> _emitRecurringBills() async {
    if (!_recurringBillsController.hasListener) return;
    _recurringBillsController.add(await getAllRecurringBills());
  }

  Future<void> _emitDebts() async {
    if (!_debtsController.hasListener) return;
    _debtsController.add(await getAllDebts());
  }

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  Stream<List<TransactionRecord>> watchTransactions() async* {
    yield await getAllTransactions();
    yield* _transactionsController.stream;
  }

  Stream<List<RecurringBillRecord>> watchRecurringBills() async* {
    yield await getAllRecurringBills();
    yield* _recurringBillsController.stream;
  }

  Stream<List<DebtRecord>> watchDebts() async* {
    yield await getAllDebts();
    yield* _debtsController.stream;
  }

  // ---------------------------------------------------------------------------
  // Recurring bills
  // ---------------------------------------------------------------------------

  Future<List<RecurringBillRecord>> getAllRecurringBills() async {
    final rows = await _database.query(
      'recurring_bills',
      orderBy: 'dueDay ASC, id ASC',
    );
    return rows.map(_billFromRow).toList(growable: false);
  }

  Future<void> addRecurringBill({
    required String name,
    required int amount,
    required int dueDay,
  }) async {
    _validateRecurringBillInput(name: name, amount: amount, dueDay: dueDay);
    final record = RecurringBillRecord(
      name: name.trim(),
      amount: amount,
      dueDay: dueDay.clamp(1, 31),
      createdAt: DateTime.now(),
    );
    await _database.insert('recurring_bills', _billToRow(record));
    await _emitRecurringBills();
  }

  Future<void> updateRecurringBill({
    required int id,
    required String name,
    required int amount,
    required int dueDay,
  }) async {
    _validateRecurringBillInput(name: name, amount: amount, dueDay: dueDay);
    final count = await _database.update(
      'recurring_bills',
      <String, Object?>{
        'name': name.trim(),
        'amount': amount,
        'dueDay': dueDay.clamp(1, 31),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Tagihan rutin tidak ditemukan.');
    }
    await _emitRecurringBills();
  }

  Future<void> deleteRecurringBill(int id) async {
    await _database.delete('recurring_bills', where: 'id = ?', whereArgs: [id]);
    await _emitRecurringBills();
  }

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------

  Future<void> addTransaction({
    required bool isExpense,
    required int amount,
    required String wallet,
    required String category,
    required DateTime transactionDate,
    required bool isCleared,
    String note = '',
    String receiptPath = '',
    String currency = '',
  }) async {
    _validateTransactionInput(
      amount: amount,
      wallet: wallet,
      category: category,
      transactionDate: transactionDate,
    );
    final record = TransactionRecord(
      isExpense: isExpense,
      amount: amount,
      wallet: wallet.trim(),
      category: category.trim(),
      transactionDate: transactionDate,
      isCleared: isCleared,
      note: _sanitizeNote(note),
      receiptPath: _sanitizePath(receiptPath),
      currency: await _resolveCurrency(currency),
      createdAt: DateTime.now(),
    );
    final id = await _database.insert('transactions', _txToRow(record));
    record.id = id;
    await _emitTransactions();
  }

  Future<List<TransactionRecord>> getAllTransactions() async {
    final rows = await _database.query(
      'transactions',
      orderBy: 'transactionDate DESC, id DESC',
    );
    return rows.map(_txFromRow).toList(growable: false);
  }

  Future<void> updateTransaction({
    required int id,
    required bool isExpense,
    required int amount,
    required String wallet,
    required String category,
    required DateTime transactionDate,
    required bool isCleared,
    String note = '',
    String receiptPath = '',
    String? currency,
  }) async {
    _validateTransactionInput(
      amount: amount,
      wallet: wallet,
      category: category,
      transactionDate: transactionDate,
    );
    final rows = await _database.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Transaksi tidak ditemukan.');
    }
    final existing = _txFromRow(rows.first);
    var resolvedCurrency = existing.currency;
    if (currency != null && currency.trim().isNotEmpty) {
      resolvedCurrency = await _resolveCurrency(currency);
    } else if (resolvedCurrency.trim().isEmpty) {
      resolvedCurrency = await _resolveCurrency('');
    }
    await _database.update(
      'transactions',
      <String, Object?>{
        'isExpense': isExpense ? 1 : 0,
        'amount': amount,
        'wallet': wallet.trim(),
        'category': category.trim(),
        'transactionDate': transactionDate.millisecondsSinceEpoch,
        'isCleared': isCleared ? 1 : 0,
        'note': _sanitizeNote(note),
        'receiptPath': _sanitizePath(receiptPath),
        'currency': resolvedCurrency,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _emitTransactions();
  }

  Future<void> addTransfer({
    required int amount,
    required String sourceWallet,
    required String destWallet,
    required DateTime transactionDate,
    String note = '',
  }) async {
    if (sourceWallet.trim().isEmpty || destWallet.trim().isEmpty) {
      throw ArgumentError('Dompet asal dan tujuan tidak boleh kosong.');
    }
    if (sourceWallet.trim().toLowerCase() == destWallet.trim().toLowerCase()) {
      throw ArgumentError('Dompet asal dan tujuan tidak boleh sama.');
    }
    if (amount <= 0) {
      throw ArgumentError('Nominal transfer harus lebih dari 0.');
    }
    if (amount > maxAmount) {
      throw ArgumentError('Nominal transfer terlalu besar.');
    }
    final now = DateTime.now();
    final groupId = _newTransferGroupId();
    final currency = await _resolveCurrency('');
    final outRecord = TransactionRecord(
      isExpense: true,
      amount: amount,
      wallet: sourceWallet.trim(),
      category: 'transfer_out',
      transactionDate: transactionDate,
      isCleared: true,
      note: _sanitizeNote(note),
      transferGroupId: groupId,
      currency: currency,
      createdAt: now,
    );
    final inRecord = TransactionRecord(
      isExpense: false,
      amount: amount,
      wallet: destWallet.trim(),
      category: 'transfer_in',
      transactionDate: transactionDate,
      isCleared: true,
      note: _sanitizeNote(note),
      transferGroupId: groupId,
      currency: currency,
      createdAt: now,
    );
    await _database.transaction((txn) async {
      await txn.insert('transactions', _txToRow(outRecord));
      await txn.insert('transactions', _txToRow(inRecord));
    });
    await _emitTransactions();
  }

  Future<void> addSplitTransaction({
    required bool isExpense,
    required String wallet,
    required DateTime transactionDate,
    required List<SplitPart> parts,
    String currency = '',
  }) async {
    if (wallet.trim().isEmpty) {
      throw ArgumentError('Dompet tidak boleh kosong.');
    }
    if (transactionDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      throw ArgumentError('Tanggal transaksi tidak valid.');
    }
    final validParts = parts
        .where((part) => part.amount > 0 && part.category.trim().isNotEmpty)
        .toList(growable: false);
    if (validParts.length < 2) {
      throw ArgumentError('Transaksi terbagi membutuhkan minimal 2 kategori.');
    }
    var total = 0;
    for (final part in validParts) {
      total += part.amount;
    }
    if (total > maxAmount) {
      throw ArgumentError('Total nominal terlalu besar.');
    }

    final groupId = _newSplitGroupId();
    final now = DateTime.now();
    final resolvedCurrency = await _resolveCurrency(currency);
    final records = validParts
        .map(
          (part) => TransactionRecord(
            isExpense: isExpense,
            amount: part.amount,
            wallet: wallet.trim(),
            category: part.category.trim(),
            transactionDate: transactionDate,
            isCleared: true,
            note: _sanitizeNote(part.note),
            splitGroupId: groupId,
            currency: resolvedCurrency,
            createdAt: now,
          ),
        )
        .toList(growable: false);

    await _database.transaction((txn) async {
      for (final record in records) {
        await txn.insert('transactions', _txToRow(record));
      }
    });
    await _emitTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await _database.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await _emitTransactions();
  }

  Future<void> deleteTransactionWithPair(TransactionRecord tx) async {
    if (!isTransferCategory(tx.category)) {
      await deleteTransaction(tx.id);
      return;
    }
    final all = await getAllTransactions();
    final ids = <int>{tx.id};
    for (final candidate in all) {
      if (isTransferCounterpart(tx, candidate)) {
        ids.add(candidate.id);
      }
    }
    await _deleteTransactionIds(ids);
  }

  Future<void> deleteTransactionDeep(TransactionRecord tx) async {
    final splitGroup = tx.splitGroupId.trim();
    if (splitGroup.isNotEmpty) {
      final all = await getAllTransactions();
      final ids = all
          .where((e) => e.splitGroupId.trim() == splitGroup)
          .map((e) => e.id)
          .toSet();
      await _deleteTransactionIds(ids);
      return;
    }
    await deleteTransactionWithPair(tx);
  }

  Future<void> _deleteTransactionIds(Set<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _database.delete(
      'transactions',
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(growable: false),
    );
    await _emitTransactions();
  }

  /// Assigns explicit group ids to legacy transfer legs. Runs once per install.
  Future<void> backfillTransferGroupsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_transferBackfillKey) ?? false) return;
    await _backfillTransferGroups();
    await prefs.setBool(_transferBackfillKey, true);
  }

  Future<int> _backfillTransferGroups() async {
    final all = await getAllTransactions();
    final pending = all
        .where(
          (e) =>
              isTransferCategory(e.category) &&
              e.transferGroupId.trim().isEmpty,
        )
        .toList(growable: false);
    if (pending.isEmpty) return 0;

    final assigned = <int>{};
    var groups = 0;
    for (final tx in pending) {
      if (assigned.contains(tx.id)) continue;
      final legs = <TransactionRecord>[tx];
      for (final candidate in pending) {
        if (candidate.id == tx.id) continue;
        if (assigned.contains(candidate.id)) continue;
        if (_legacyTransferMatch(tx, candidate)) {
          legs.add(candidate);
        }
      }
      final groupId = _newTransferGroupId();
      await _database.transaction((txn) async {
        for (final leg in legs) {
          await txn.update(
            'transactions',
            <String, Object?>{'transferGroupId': groupId},
            where: 'id = ?',
            whereArgs: [leg.id],
          );
          assigned.add(leg.id);
        }
      });
      groups += 1;
    }
    if (groups > 0) {
      await _emitTransactions();
    }
    return groups;
  }

  // ---------------------------------------------------------------------------
  // Debts
  // ---------------------------------------------------------------------------

  Future<List<DebtRecord>> getAllDebts() async {
    final rows = await _database.query(
      'debts',
      orderBy: 'isSettled ASC, createdAt DESC, id DESC',
    );
    return rows.map(_debtFromRow).toList(growable: false);
  }

  Future<void> addDebt({
    required String name,
    required bool isReceivable,
    required int amount,
    DateTime? dueDate,
    String note = '',
    double interestRatePercent = 0,
  }) async {
    _validateDebtInput(name: name, amount: amount);
    final record = DebtRecord(
      name: name.trim(),
      isReceivable: isReceivable,
      principal: amount,
      remaining: amount,
      dueDate: dueDate,
      note: _sanitizeNote(note),
      interestRatePercent: interestRatePercent < 0 ? 0 : interestRatePercent,
      isSettled: false,
      createdAt: DateTime.now(),
    );
    await _database.insert('debts', _debtToRow(record));
    await _emitDebts();
  }

  Future<void> updateDebt({
    required int id,
    required String name,
    required bool isReceivable,
    required int amount,
    required int remaining,
    DateTime? dueDate,
    String note = '',
    double interestRatePercent = 0,
  }) async {
    _validateDebtInput(name: name, amount: amount);
    final safeRemaining = remaining.clamp(0, amount);
    final count = await _database.update(
      'debts',
      <String, Object?>{
        'name': name.trim(),
        'isReceivable': isReceivable ? 1 : 0,
        'principal': amount,
        'remaining': safeRemaining,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'note': _sanitizeNote(note),
        'interestRatePercent': interestRatePercent < 0
            ? 0
            : interestRatePercent,
        'isSettled': safeRemaining <= 0 ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Data utang/piutang tidak ditemukan.');
    }
    await _emitDebts();
  }

  Future<void> deleteDebt(int id) async {
    await _database.delete('debts', where: 'id = ?', whereArgs: [id]);
    await _emitDebts();
  }

  Future<void> applyDebtPayment({
    required int debtId,
    required int amount,
    required String wallet,
    required String category,
    required DateTime transactionDate,
    bool createTransaction = true,
    String note = '',
  }) async {
    if (amount <= 0 || amount > maxAmount) {
      throw ArgumentError('Nominal pembayaran tidak valid.');
    }
    final rows = await _database.query(
      'debts',
      where: 'id = ?',
      whereArgs: [debtId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Data utang/piutang tidak ditemukan.');
    }
    final debt = _debtFromRow(rows.first);
    final applied = amount.clamp(0, debt.remaining);
    final currency = await _resolveCurrency('');
    await _database.transaction((txn) async {
      final nextRemaining = (debt.remaining - applied).clamp(0, debt.principal);
      await txn.update(
        'debts',
        <String, Object?>{
          'remaining': nextRemaining,
          'isSettled': nextRemaining <= 0 ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [debt.id],
      );
      if (createTransaction && applied > 0) {
        _validateTransactionInput(
          amount: applied,
          wallet: wallet,
          category: category,
          transactionDate: transactionDate,
        );
        final txNote = note.trim().isEmpty
            ? '${debt.isReceivable ? 'Piutang' : 'Utang'}: ${debt.name}'
            : note;
        final record = TransactionRecord(
          isExpense: !debt.isReceivable,
          amount: applied,
          wallet: wallet.trim(),
          category: category.trim(),
          transactionDate: transactionDate,
          isCleared: true,
          note: _sanitizeNote(txNote),
          currency: currency,
          createdAt: DateTime.now(),
        );
        await txn.insert('transactions', _txToRow(record));
      }
    });
    await _emitDebts();
    if (createTransaction && applied > 0) {
      await _emitTransactions();
    }
  }

  // ---------------------------------------------------------------------------
  // Backup payload
  // ---------------------------------------------------------------------------

  Future<void> clearAllData() async {
    await _database.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('recurring_bills');
      await txn.delete('debts');
    });
    await _emitTransactions();
    await _emitRecurringBills();
    await _emitDebts();
  }

  Future<Map<String, dynamic>> exportBackupPayload() async {
    final transactions = await getAllTransactions();
    final recurringBills = await getAllRecurringBills();
    final debts = await getAllDebts();
    return {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'transactions': transactions
          .map(
            (e) => {
              'isExpense': e.isExpense,
              'amount': e.amount,
              'wallet': e.wallet,
              'category': e.category,
              'transactionDate': e.transactionDate.toIso8601String(),
              'isCleared': e.isCleared,
              'note': e.note,
              'receiptPath': e.receiptPath,
              'transferGroupId': e.transferGroupId,
              'splitGroupId': e.splitGroupId,
              'currency': e.currency,
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      'recurringBills': recurringBills
          .map(
            (e) => {
              'name': e.name,
              'amount': e.amount,
              'dueDay': e.dueDay,
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      'debts': debts
          .map(
            (e) => {
              'name': e.name,
              'isReceivable': e.isReceivable,
              'principal': e.principal,
              'remaining': e.remaining,
              'dueDate': e.dueDate?.toIso8601String(),
              'note': e.note,
              'interestRatePercent': e.interestRatePercent,
              'isSettled': e.isSettled,
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(growable: false),
    };
  }

  Future<void> restoreBackupPayload(Map<String, dynamic> payload) async {
    final trxRaw = (payload['transactions'] as List<dynamic>? ?? const []);
    final billsRaw = (payload['recurringBills'] as List<dynamic>? ?? const []);
    final debtsRaw = (payload['debts'] as List<dynamic>? ?? const []);

    final transactions = trxRaw.whereType<Map>().map((item) {
      return TransactionRecord(
        isExpense: (item['isExpense'] as bool?) ?? true,
        amount: (item['amount'] as num?)?.toInt() ?? 0,
        wallet: (item['wallet'] as String?) ?? 'Cash',
        category: (item['category'] as String?) ?? 'Others',
        transactionDate:
            DateTime.tryParse((item['transactionDate'] as String?) ?? '') ??
            DateTime.now(),
        isCleared: (item['isCleared'] as bool?) ?? false,
        note: (item['note'] as String?) ?? '',
        receiptPath: (item['receiptPath'] as String?) ?? '',
        transferGroupId: (item['transferGroupId'] as String?) ?? '',
        splitGroupId: (item['splitGroupId'] as String?) ?? '',
        currency: (item['currency'] as String?) ?? '',
        createdAt:
            DateTime.tryParse((item['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
    }).toList(growable: false);

    final recurringBills = billsRaw.whereType<Map>().map((item) {
      return RecurringBillRecord(
        name: (item['name'] as String?) ?? 'Tagihan',
        amount: (item['amount'] as num?)?.toInt() ?? 0,
        dueDay: ((item['dueDay'] as num?)?.toInt() ?? 1).clamp(1, 31),
        createdAt:
            DateTime.tryParse((item['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
    }).toList(growable: false);

    final debts = debtsRaw.whereType<Map>().map((item) {
      final principal = (item['principal'] as num?)?.toInt() ?? 0;
      return DebtRecord(
        name: (item['name'] as String?) ?? 'Utang',
        isReceivable: (item['isReceivable'] as bool?) ?? false,
        principal: principal,
        remaining: ((item['remaining'] as num?)?.toInt() ?? principal).clamp(
          0,
          principal,
        ),
        dueDate: DateTime.tryParse((item['dueDate'] as String?) ?? ''),
        note: (item['note'] as String?) ?? '',
        interestRatePercent:
            (item['interestRatePercent'] as num?)?.toDouble() ?? 0,
        isSettled: (item['isSettled'] as bool?) ?? false,
        createdAt:
            DateTime.tryParse((item['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
    }).toList(growable: false);

    await _database.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('recurring_bills');
      await txn.delete('debts');
      for (final record in transactions) {
        await txn.insert('transactions', _txToRow(record));
      }
      for (final record in recurringBills) {
        await txn.insert('recurring_bills', _billToRow(record));
      }
      for (final record in debts) {
        await txn.insert('debts', _debtToRow(record));
      }
    });
    await _emitTransactions();
    await _emitRecurringBills();
    await _emitDebts();
  }

  // ---------------------------------------------------------------------------
  // Aggregation
  // ---------------------------------------------------------------------------

  Future<int> getMonthlyExpenseTotal(DateTime date) async {
    return getCycleExpenseTotal(date, 1);
  }

  Future<int> getCycleExpenseTotal(DateTime date, int cycleStartDay) async {
    final normalizedDay = cycleStartDay.clamp(1, 31);
    final currentMonthStartDay = _safeDayInMonth(
      date.year,
      date.month,
      normalizedDay,
    );
    late DateTime start;
    late DateTime end;
    if (date.day >= currentMonthStartDay) {
      start = DateTime(date.year, date.month, currentMonthStartDay);
      final nextMonth = DateTime(date.year, date.month + 1, 1);
      final nextStartDay = _safeDayInMonth(
        nextMonth.year,
        nextMonth.month,
        normalizedDay,
      );
      end = DateTime(nextMonth.year, nextMonth.month, nextStartDay);
    } else {
      final prevMonth = DateTime(date.year, date.month - 1, 1);
      final prevStartDay = _safeDayInMonth(
        prevMonth.year,
        prevMonth.month,
        normalizedDay,
      );
      start = DateTime(prevMonth.year, prevMonth.month, prevStartDay);
      end = DateTime(date.year, date.month, currentMonthStartDay);
    }
    final rows = await _database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE isExpense = 1
        AND category NOT IN ('transfer_out', 'transfer_in')
        AND transactionDate >= ?
        AND transactionDate < ?
      ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  int _safeDayInMonth(int year, int month, int requestedDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return requestedDay.clamp(1, lastDay);
  }

  // ---------------------------------------------------------------------------
  // Validation & sanitization
  // ---------------------------------------------------------------------------

  void _validateTransactionInput({
    required int amount,
    required String wallet,
    required String category,
    required DateTime transactionDate,
  }) {
    if (amount <= 0) {
      throw ArgumentError('Nominal transaksi harus lebih dari 0.');
    }
    if (amount > maxAmount) {
      throw ArgumentError('Nominal transaksi terlalu besar.');
    }
    if (wallet.trim().isEmpty) {
      throw ArgumentError('Dompet tidak boleh kosong.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError('Kategori tidak boleh kosong.');
    }
    if (transactionDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      throw ArgumentError('Tanggal transaksi tidak valid.');
    }
  }

  void _validateRecurringBillInput({
    required String name,
    required int amount,
    required int dueDay,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Nama tagihan tidak boleh kosong.');
    }
    if (amount <= 0) {
      throw ArgumentError('Nominal tagihan harus lebih dari 0.');
    }
    if (amount > maxAmount) {
      throw ArgumentError('Nominal tagihan terlalu besar.');
    }
    if (dueDay < 1 || dueDay > 31) {
      throw ArgumentError('Tanggal jatuh tempo harus 1-31.');
    }
  }

  void _validateDebtInput({required String name, required int amount}) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Nama pihak tidak boleh kosong.');
    }
    if (amount <= 0) {
      throw ArgumentError('Nominal harus lebih dari 0.');
    }
    if (amount > maxAmount) {
      throw ArgumentError('Nominal terlalu besar.');
    }
  }

  String _sanitizeNote(String note) {
    final trimmed = note.trim();
    if (trimmed.length <= 140) return trimmed;
    return trimmed.substring(0, 140);
  }

  String _sanitizePath(String input) {
    return input.replaceAll('\u0000', '').trim();
  }
}
