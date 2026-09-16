class ImportedTransaction {
  ImportedTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.isExpense,
    required this.category,
    this.selected = true,
  });

  final DateTime date;
  final String description;
  final int amount;
  final bool isExpense;
  String category;
  bool selected;
}

/// Parses bank-statement style CSV text and guesses categories from the
/// transaction description using a lightweight offline rule engine.
class TransactionImportService {
  TransactionImportService._();

  static final TransactionImportService instance = TransactionImportService._();

  static const List<(List<String>, String)> _expenseRules = [
    (
      ['indomaret', 'alfamart', 'supermarket', 'superindo', 'groceries', 'belanja'],
      'shopping',
    ),
    (
      ['resto', 'restoran', 'cafe', 'kopi', 'coffee', 'makan', 'nasi', 'kfc', 'mcd', 'starbucks', 'bakery'],
      'food',
    ),
    (
      ['gojek', 'grab', 'ojek', 'taksi', 'taxi', 'bensin', 'pertamina', 'toll', 'tol', 'parkir', 'krl', 'mrt', 'transjakarta'],
      'transport',
    ),
    (
      ['pln', 'listrik', 'pdam', 'air', 'internet', 'indihome', 'telkom', 'pulsa', 'netflix', 'spotify', 'langganan', 'iuran'],
      'bills',
    ),
    (
      ['apotek', 'klinik', 'rumah sakit', 'rs ', 'obat', 'dokter', 'vitamin'],
      'health',
    ),
    (
      ['bioskop', 'cinema', 'cgv', 'game', 'steam', 'hiburan', 'karaoke'],
      'entertainment',
    ),
    (
      ['buku', 'kursus', 'udemy', 'sekolah', 'kuliah', 'pendidikan'],
      'education',
    ),
  ];

  static const List<(List<String>, String)> _incomeRules = [
    (['gaji', 'payroll', 'salary', 'upah'], 'salary'),
    (['freelance', 'proyek', 'invoice', 'jasa'], 'freelance'),
    (['bonus', 'thr', 'insentif'], 'bonus'),
    (['dividen', 'bunga', 'investasi', 'reksadana', 'saham'], 'investment'),
    (['hadiah', 'gift', 'cashback', 'refund'], 'gift'),
  ];

  String guessCategory(String description, bool isExpense) {
    final text = description.toLowerCase();
    final rules = isExpense ? _expenseRules : _incomeRules;
    for (final (keywords, category) in rules) {
      for (final keyword in keywords) {
        if (text.contains(keyword)) return category;
      }
    }
    return isExpense ? 'others' : 'salary';
  }

  List<ImportedTransaction> parse(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return const [];

    final delimiter = _detectDelimiter(lines.first);
    final result = <ImportedTransaction>[];

    for (var i = 0; i < lines.length; i++) {
      final cells = lines[i]
          .split(delimiter)
          .map((cell) => cell.replaceAll('"', '').trim())
          .toList(growable: false);
      if (cells.isEmpty) continue;

      DateTime? date;
      int? signedAmount;
      var description = '';
      for (final cell in cells) {
        if (date == null) {
          final parsedDate = _parseDate(cell);
          if (parsedDate != null) {
            date = parsedDate;
            continue;
          }
        }
        if (signedAmount == null) {
          final parsedAmount = _parseAmount(cell);
          if (parsedAmount != null) {
            signedAmount = parsedAmount;
            continue;
          }
        }
        if (_looksLikeDescription(cell) && cell.length > description.length) {
          description = cell;
        }
      }

      // Skip header rows and unparseable lines.
      if (date == null || signedAmount == null) continue;
      if (description.isEmpty) description = 'Import';

      final isExpense = signedAmount < 0;
      final amount = signedAmount.abs();
      if (amount <= 0) continue;
      result.add(
        ImportedTransaction(
          date: date,
          description: description,
          amount: amount,
          isExpense: isExpense,
          category: guessCategory(description, isExpense),
        ),
      );
    }
    return result;
  }

  bool _looksLikeDescription(String cell) {
    if (cell.isEmpty) return false;
    final lower = cell.toLowerCase();
    if (_parseDate(cell) != null) return false;
    if (RegExp(r'^-?\d[\d.,\s]*$').hasMatch(lower)) return false;
    return RegExp(r'[a-zA-Z]').hasMatch(cell);
  }

  String _detectDelimiter(String line) {
    const candidates = [';', '\t', ','];
    for (final candidate in candidates) {
      if (line.contains(candidate)) return candidate;
    }
    return ',';
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$').firstMatch(
      trimmed,
    );
    if (dmy != null) {
      final day = int.parse(dmy.group(1)!);
      final month = int.parse(dmy.group(2)!);
      var year = int.parse(dmy.group(3)!);
      if (year < 100) year += 2000;
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      return DateTime(year, month, day);
    }

    final ymd = RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})$').firstMatch(
      trimmed,
    );
    if (ymd != null) {
      final year = int.parse(ymd.group(1)!);
      final month = int.parse(ymd.group(2)!);
      final day = int.parse(ymd.group(3)!);
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      return DateTime(year, month, day);
    }
    return null;
  }

  int? _parseAmount(String value) {
    var text = value.trim();
    if (text.isEmpty) return null;
    text = text
        .replaceAll(
          RegExp(r'(rp|idr|usd|sgd|myr)', caseSensitive: false),
          '',
        )
        .replaceAll(r'$', '')
        .trim();
    // Reject cells that still contain letters (e.g. descriptions).
    if (RegExp(r'[a-zA-Z]').hasMatch(text)) return null;
    var negative = false;
    if (text.startsWith('(') && text.endsWith(')')) {
      negative = true;
      text = text.substring(1, text.length - 1);
    }
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }
    text = text.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final amount = int.tryParse(digits);
    if (amount == null) return null;
    return negative ? -amount : amount;
  }
}
