import 'transaction_import_service.dart';

/// Parses bank/ewallet SMS notifications into a candidate transaction.
///
/// Pure and platform-agnostic so it can be unit tested; the Android SMS
/// listener that feeds it is documented in `docs/sms_import.md`.
class SmsImportService {
  SmsImportService._();

  static final SmsImportService instance = SmsImportService._();

  static const List<String> _expenseKeywords = [
    'debit',
    'debet',
    'pembayaran',
    'pembelian',
    'tarik',
    'penarikan',
    'keluar',
    'transfer ke',
    'qris',
    'belanja',
    'potong',
  ];

  static const List<String> _incomeKeywords = [
    'kredit',
    'masuk',
    'gaji',
    'top up',
    'topup',
    'terima',
    'transfer dari',
    'cashback',
    'bunga',
    'bonus',
  ];

  ImportedTransaction? parse(String body, {DateTime? now}) {
    final text = body.trim();
    if (text.isEmpty) return null;

    final amount = _extractAmount(text);
    if (amount == null || amount <= 0) return null;

    final lower = text.toLowerCase();
    final isExpense = _isExpense(lower);
    final description = _extractDescription(text);
    return ImportedTransaction(
      date: _extractDate(text) ?? (now ?? DateTime.now()),
      description: description,
      amount: amount,
      isExpense: isExpense,
      category: TransactionImportService.instance.guessCategory(
        description,
        isExpense,
      ),
    );
  }

  bool _isExpense(String lower) {
    final hasExpense = _expenseKeywords.any(lower.contains);
    final hasIncome = _incomeKeywords.any(lower.contains);
    if (hasExpense && !hasIncome) return true;
    if (hasIncome && !hasExpense) return false;
    // Ambiguous: default to expense (most bank alerts are debits).
    return !hasIncome;
  }

  int? _extractAmount(String text) {
    // Strip dates/times so their digits are not mistaken for amounts.
    var sanitized = text.replaceAll(
      RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'),
      ' ',
    );
    sanitized = sanitized.replaceAll(RegExp(r'\d{1,2}:\d{2}(?::\d{2})?'), ' ');
    final saldoIndex = sanitized.toLowerCase().indexOf('saldo');

    final matches = RegExp(
      r'((?:rp|idr)\s*)?([0-9]{1,3}(?:[.,][0-9]{3})+|[0-9]{4,})',
      caseSensitive: false,
    ).allMatches(sanitized);
    int? prefixedFirst;
    int? numericFirst;
    for (final match in matches) {
      final raw = match.group(2);
      if (raw == null) continue;
      final value = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
      if (value == null || value <= 0) continue;
      final isBeforeSaldo = saldoIndex < 0 || match.start < saldoIndex;
      if (!isBeforeSaldo) continue;
      final hasPrefix = (match.group(1) ?? '').trim().isNotEmpty;
      if (hasPrefix) prefixedFirst ??= value;
      numericFirst ??= value;
    }
    return prefixedFirst ?? numericFirst;
  }

  DateTime? _extractDate(String text) {
    final dmy = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})').firstMatch(
      text,
    );
    if (dmy != null) {
      var year = int.parse(dmy.group(3)!);
      if (year < 100) year += 2000;
      final month = int.parse(dmy.group(2)!);
      final day = int.parse(dmy.group(1)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  String _extractDescription(String text) {
    final firstLine = text.split(RegExp(r'[\r\n]')).first.trim();
    if (firstLine.length <= 80) return firstLine;
    return '${firstLine.substring(0, 77)}...';
  }
}
