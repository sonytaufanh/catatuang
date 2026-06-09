import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/recurring_bill_record.dart';
import 'models/transaction_record.dart';

class DatabaseService {
  DatabaseService._();
  static const int maxAmount = 1000000000;

  static final DatabaseService instance = DatabaseService._();
  Isar? _isar;

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
      [RecurringBillRecordSchema, TransactionRecordSchema],
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
      ..wallet = wallet
      ..category = category
      ..transactionDate = transactionDate
      ..isCleared = isCleared
      ..note = _sanitizeNote(note)
      ..receiptPath = _sanitizePath(receiptPath)
      ..createdAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.transactionRecords.put(record);
    });
  }

  Future<List<TransactionRecord>> getAllTransactions() async {
    return isar.transactionRecords.where().sortByTransactionDateDesc().findAll();
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
    await isar.writeTxn(() async {
      await isar.transactionRecords.put(existing);
    });
  }

  Future<void> deleteTransaction(int id) async {
    await isar.writeTxn(() async {
      await isar.transactionRecords.delete(id);
    });
  }

  Future<Map<String, dynamic>> exportBackupPayload() async {
    final transactions = await getAllTransactions();
    final recurringBills = await getAllRecurringBills();
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
    };
  }

  Future<void> restoreBackupPayload(Map<String, dynamic> payload) async {
    final trxRaw = (payload['transactions'] as List<dynamic>? ?? const []);
    final billsRaw = (payload['recurringBills'] as List<dynamic>? ?? const []);

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

    await isar.writeTxn(() async {
      await isar.transactionRecords.clear();
      await isar.recurringBillRecords.clear();
      if (transactions.isNotEmpty) {
        await isar.transactionRecords.putAll(transactions);
      }
      if (recurringBills.isNotEmpty) {
        await isar.recurringBillRecords.putAll(recurringBills);
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
