import 'dart:math';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class DatabaseService {
  DatabaseService._();
  static const int maxAmount = 1000000000;
  static const String _transferBackfillKey = 'transfer_group_backfill_v1';

  static final DatabaseService instance = DatabaseService._();
  final Random _random = Random();
  Isar? _isar;

  static bool isTransferCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return normalized == 'transfer_out' || normalized == 'transfer_in';
  }

  /// Returns true when [candidate] is the opposite leg of the transfer [tx].
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

  /// Heuristic used for transfers recorded before [transferGroupId] existed.
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

  /// True when both records belong to the same split transaction.
  static bool isSameSplitGroup(
    TransactionRecord a,
    TransactionRecord b,
  ) {
    final group = a.splitGroupId.trim();
    return group.isNotEmpty && group == b.splitGroupId.trim();
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

  Isar get isar {
    final db = _isar;
    if (db == null) {
      throw StateError('Database belum diinisialisasi.');
    }
    return db;
  }

  Future<void> init() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [RecurringBillRecordSchema, TransactionRecordSchema, DebtRecordSchema],
      directory: dir.path,
      name: 'catatuang_db',
    );
  }

  Future<List<RecurringBillRecord>> getAllRecurringBills() async {
    return isar.recurringBillRecords.where().sortByDueDay().findAll();
  }

  Future<void> addRecurringBill({
    required String name,
    required int amount,
    required int dueDay,
  }) async {
    _validateRecurringBillInput(name: name, amount: amount, dueDay: dueDay);
    final record = RecurringBillRecord()
      ..name = name.trim()
      ..amount = amount
      ..dueDay = dueDay.clamp(1, 31)
      ..createdAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.recurringBillRecords.put(record);
    });
  }

  Future<void> updateRecurringBill({
    required int id,
    required String name,
    required int amount,
    required int dueDay,
  }) async {
    _validateRecurringBillInput(name: name, amount: amount, dueDay: dueDay);
    final existing = await isar.recurringBillRecords.get(id);
    if (existing == null) {
      throw StateError('Tagihan rutin tidak ditemukan.');
    }
    existing
      ..name = name.trim()
      ..amount = amount
      ..dueDay = dueDay.clamp(1, 31);
    await isar.writeTxn(() async {
      await isar.recurringBillRecords.put(existing);
    });
  }

  Future<void> deleteRecurringBill(int id) async {
    await isar.writeTxn(() async {
      await isar.recurringBillRecords.delete(id);
    });
  }

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
    final record = TransactionRecord()
      ..isExpense = isExpense
      ..amount = amount
      ..wallet = wallet.trim()
      ..category = category.trim()
      ..transactionDate = transactionDate
      ..isCleared = isCleared
      ..note = _sanitizeNote(note)
      ..receiptPath = _sanitizePath(receiptPath)
      ..currency = await _resolveCurrency(currency)
      ..createdAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.transactionRecords.put(record);
    });
  }

  Future<List<TransactionRecord>> getAllTransactions() async {
    return isar.transactionRecords.where().sortByTransactionDateDesc().findAll();
  }

  /// Reactive stream of all transactions, sorted newest first.
  Stream<List<TransactionRecord>> watchTransactions() {
    return isar.transactionRecords
        .where()
        .sortByTransactionDateDesc()
        .watch(fireImmediately: true);
  }

  /// Reactive stream of all recurring bills, sorted by due day.
  Stream<List<RecurringBillRecord>> watchRecurringBills() {
    return isar.recurringBillRecords
        .where()
        .sortByDueDay()
        .watch(fireImmediately: true);
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
    final existing = await isar.transactionRecords.get(id);
    if (existing == null) {
      throw StateError('Transaksi tidak ditemukan.');
    }
    existing
      ..isExpense = isExpense
      ..amount = amount
      ..wallet = wallet.trim()
      ..category = category.trim()
      ..transactionDate = transactionDate
      ..isCleared = isCleared
      ..note = _sanitizeNote(note)
      ..receiptPath = _sanitizePath(receiptPath);
    if (currency != null && currency.trim().isNotEmpty) {
      existing.currency = await _resolveCurrency(currency);
    } else if (existing.currency.trim().isEmpty) {
      existing.currency = await _resolveCurrency('');
    }
    await isar.writeTxn(() async {
      await isar.transactionRecords.put(existing);
    });
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
    if (sourceWallet.trim().toLowerCase == destWallet.trim().toLowerCase) {
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
    final outRecord = TransactionRecord()
      ..isExpense = true
      ..amount = amount
      ..wallet = sourceWallet.trim()
      ..category = 'transfer_out'
      ..transactionDate = transactionDate
      ..isCleared = true
      ..note = _sanitizeNote(note)
      ..receiptPath = ''
      ..transferGroupId = groupId
      ..currency = currency
      ..createdAt = now;
    final inRecord = TransactionRecord()
      ..isExpense = false
      ..amount = amount
      ..wallet = destWallet.trim()
      ..category = 'transfer_in'
      ..transactionDate = transactionDate
      ..isCleared = true
      ..note = _sanitizeNote(note)
      ..receiptPath = ''
      ..transferGroupId = groupId
      ..currency = currency
      ..createdAt = now;
    await isar.writeTxn(() async {
      await isar.transactionRecords.putAll([outRecord, inRecord]);
    });
  }

  Future<void> deleteTransaction(int id) async {
    await isar.writeTxn(() async {
      await isar.transactionRecords.delete(id);
    });
  }

  /// Deletes a transaction and, when it is a transfer leg, its counterpart
  /// leg as well so that transfers never leave an orphaned half.
  Future<void> deleteTransactionWithPair(TransactionRecord tx) async {
    if (!isTransferCategory(tx.category)) {
      await deleteTransaction(tx.id);
      return;
    }
    final all = await getAllTransactions();
    final pair = <TransactionRecord>[];
    for (final candidate in all) {
      if (isTransferCounterpart(tx, candidate)) {
        pair.add(candidate);
      }
    }
    await isar.writeTxn(() async {
      await isar.transactionRecords.delete(tx.id);
      for (final candidate in pair) {
        await isar.transactionRecords.delete(candidate.id);
      }
    });
  }

  /// Creates a split transaction: one row per category sharing a split group.
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
          (part) => TransactionRecord()
            ..isExpense = isExpense
            ..amount = part.amount
            ..wallet = wallet.trim()
            ..category = part.category.trim()
            ..transactionDate = transactionDate
            ..isCleared = true
            ..note = _sanitizeNote(part.note)
            ..receiptPath = ''
            ..splitGroupId = groupId
            ..currency = resolvedCurrency
            ..createdAt = now,
        )
        .toList(growable: false);

    await isar.writeTxn(() async {
      await isar.transactionRecords.putAll(records);
    });
  }

  /// Deletes a transaction along with its transfer pair or split siblings.
  Future<void> deleteTransactionDeep(TransactionRecord tx) async {
    final splitGroup = tx.splitGroupId.trim();
    if (splitGroup.isNotEmpty) {
      final all = await getAllTransactions();
      final ids = all
          .where((e) => e.splitGroupId.trim() == splitGroup)
          .map((e) => e.id)
          .toList(growable: false);
      await isar.writeTxn(() async {
        for (final id in ids) {
          await isar.transactionRecords.delete(id);
        }
      });
      return;
    }
    await deleteTransactionWithPair(tx);
  }

  /// Assigns explicit group ids to legacy transfer legs that predate the
  /// [TransactionRecord.transferGroupId] field. Runs once per install.
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
      for (final leg in legs) {
        leg.transferGroupId = groupId;
        assigned.add(leg.id);
      }
      await isar.writeTxn(() async {
        await isar.transactionRecords.putAll(legs);
      });
      groups += 1;
    }
    return groups;
  }

  Future<List<DebtRecord>> getAllDebts() async {
    return isar.debtRecords
        .where()
        .sortByIsSettled()
        .thenByCreatedAtDesc()
        .findAll();
  }

  Stream<List<DebtRecord>> watchDebts() {
    return isar.debtRecords
        .where()
        .sortByIsSettled()
        .thenByCreatedAtDesc()
        .watch(fireImmediately: true);
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
    final now = DateTime.now();
    final record = DebtRecord()
      ..name = name.trim()
      ..isReceivable = isReceivable
      ..principal = amount
      ..remaining = amount
      ..dueDate = dueDate
      ..note = _sanitizeNote(note)
      ..interestRatePercent = interestRatePercent < 0
          ? 0
          : interestRatePercent
      ..isSettled = false
      ..createdAt = now;
    await isar.writeTxn(() async {
      await isar.debtRecords.put(record);
    });
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
    final existing = await isar.debtRecords.get(id);
    if (existing == null) {
      throw StateError('Data utang/piutang tidak ditemukan.');
    }
    final safeRemaining = remaining.clamp(0, amount);
    existing
      ..name = name.trim()
      ..isReceivable = isReceivable
      ..principal = amount
      ..remaining = safeRemaining
      ..dueDate = dueDate
      ..note = _sanitizeNote(note)
      ..interestRatePercent = interestRatePercent < 0
          ? 0
          : interestRatePercent
      ..isSettled = safeRemaining <= 0;
    await isar.writeTxn(() async {
      await isar.debtRecords.put(existing);
    });
  }

  Future<void> deleteDebt(int id) async {
    await isar.writeTxn(() async {
      await isar.debtRecords.delete(id);
    });
  }

  /// Applies a payment toward a debt and records the matching transaction in
  /// the same atomic write.
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
    final debt = await isar.debtRecords.get(debtId);
    if (debt == null) {
      throw StateError('Data utang/piutang tidak ditemukan.');
    }
    final applied = amount.clamp(0, debt.remaining);
    final currency = await _resolveCurrency('');
    await isar.writeTxn(() async {
      debt.remaining = (debt.remaining - applied).clamp(0, debt.principal);
      debt.isSettled = debt.remaining <= 0;
      await isar.debtRecords.put(debt);
      if (createTransaction && applied > 0) {
        _validateTransactionInput(
          amount: applied,
          wallet: wallet,
          category: category,
          transactionDate: transactionDate,
        );
        final txNote = note.trim().isEmpty
            ? '${debt.isReceivable ? 'Piutang' : 'Utang'}: ${debt.name}'
            : _sanitizeNote(note);
        final record = TransactionRecord()
          ..isExpense = !debt.isReceivable
          ..amount = applied
          ..wallet = wallet.trim()
          ..category = category.trim()
          ..transactionDate = transactionDate
          ..isCleared = true
          ..note = _sanitizeNote(txNote)
          ..receiptPath = ''
          ..currency = currency
          ..createdAt = DateTime.now();
        await isar.transactionRecords.put(record);
      }
    });
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
      final record = TransactionRecord()
        ..isExpense = (item['isExpense'] as bool?) ?? true
        ..amount = (item['amount'] as num?)?.toInt() ?? 0
        ..wallet = (item['wallet'] as String?) ?? 'Cash'
        ..category = (item['category'] as String?) ?? 'Others'
        ..transactionDate =
            DateTime.tryParse((item['transactionDate'] as String?) ?? '') ??
                DateTime.now()
        ..isCleared = (item['isCleared'] as bool?) ?? false
        ..note = (item['note'] as String?) ?? ''
        ..receiptPath = (item['receiptPath'] as String?) ?? ''
        ..transferGroupId = (item['transferGroupId'] as String?) ?? ''
        ..splitGroupId = (item['splitGroupId'] as String?) ?? ''
        ..currency = (item['currency'] as String?) ?? ''
        ..createdAt = DateTime.tryParse((item['createdAt'] as String?) ?? '') ??
            DateTime.now();
      return record;
    }).toList(growable: false);

    final recurringBills = billsRaw.whereType<Map>().map((item) {
      final record = RecurringBillRecord()
        ..name = (item['name'] as String?) ?? 'Tagihan'
        ..amount = (item['amount'] as num?)?.toInt() ?? 0
        ..dueDay = ((item['dueDay'] as num?)?.toInt() ?? 1).clamp(1, 31)
        ..createdAt = DateTime.tryParse((item['createdAt'] as String?) ?? '') ??
            DateTime.now();
      return record;
    }).toList(growable: false);

    final debts = debtsRaw.whereType<Map>().map((item) {
      final principal = (item['principal'] as num?)?.toInt() ?? 0;
      final record = DebtRecord()
        ..name = (item['name'] as String?) ?? 'Utang'
        ..isReceivable = (item['isReceivable'] as bool?) ?? false
        ..principal = principal
        ..remaining = ((item['remaining'] as num?)?.toInt() ?? principal)
            .clamp(0, principal)
        ..dueDate = DateTime.tryParse((item['dueDate'] as String?) ?? '')
        ..note = (item['note'] as String?) ?? ''
        ..interestRatePercent =
            (item['interestRatePercent'] as num?)?.toDouble() ?? 0
        ..isSettled = (item['isSettled'] as bool?) ?? false
        ..createdAt = DateTime.tryParse((item['createdAt'] as String?) ?? '') ??
            DateTime.now();
      return record;
    }).toList(growable: false);

    await isar.writeTxn(() async {
      await isar.transactionRecords.clear();
      await isar.recurringBillRecords.clear();
      await isar.debtRecords.clear();
      if (transactions.isNotEmpty) {
        await isar.transactionRecords.putAll(transactions);
      }
      if (recurringBills.isNotEmpty) {
        await isar.recurringBillRecords.putAll(recurringBills);
      }
      if (debts.isNotEmpty) {
        await isar.debtRecords.putAll(debts);
      }
    });
  }

  Future<int> getMonthlyExpenseTotal(DateTime date) async {
    return getCycleExpenseTotal(date, 1);
  }

  Future<int> getCycleExpenseTotal(DateTime date, int cycleStartDay) async {
    final normalizedDay = cycleStartDay.clamp(1, 31);
    final currentMonthStartDay = _safeDayInMonth(date.year, date.month, normalizedDay);
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
    final records = await isar.transactionRecords
        .filter()
        .isExpenseEqualTo(true)
        .transactionDateGreaterThan(start, include: true)
        .transactionDateLessThan(end, include: false)
        .findAll();
    var total = 0;
    for (final item in records) {
      if (isTransferCategory(item.category)) continue;
      total += item.amount;
    }
    return total;
  }

  int _safeDayInMonth(int year, int month, int requestedDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return requestedDay.clamp(1, lastDay);
  }

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

  String _sanitizeNote(String note) {
    final trimmed = note.trim();
    if (trimmed.length <= 140) return trimmed;
    return trimmed.substring(0, 140);
  }

  String _sanitizePath(String input) {
    return input.replaceAll('\u0000', '').trim();
  }
}
