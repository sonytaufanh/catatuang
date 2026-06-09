import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../data/models/transaction_record.dart';

class ExportReportService {
  ExportReportService._();

  static final ExportReportService instance = ExportReportService._();

  Future<String> exportCsv({
    required List<TransactionRecord> transactions,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final filtered = _filterByPeriod(transactions, start, endExclusive);
    final rows = <String>[
      'date,type,amount,wallet,category,note',
      ...filtered.map((tx) {
        final type = tx.isExpense ? 'expense' : 'income';
        final date = tx.transactionDate.toIso8601String();
        final note = _csvEscape(tx.note);
        return '$date,$type,${tx.amount},${_csvEscape(tx.wallet)},${_csvEscape(tx.category)},$note';
      }),
    ];
    final file = await _reportFile('.csv');
    await file.parent.create(recursive: true);
    await file.writeAsString(rows.join('\n'));
    return file.path;
  }

  Future<String> exportPdf({
    required List<TransactionRecord> transactions,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final filtered = _filterByPeriod(transactions, start, endExclusive);
    final totalIncome = filtered
        .where((tx) => !tx.isExpense)
        .fold<int>(0, (sum, tx) => sum + tx.amount);
    final totalExpense = filtered
        .where((tx) => tx.isExpense)
        .fold<int>(0, (sum, tx) => sum + tx.amount);

    final pdfBytes = _buildProfessionalPdf(
      transactions: filtered,
      start: start,
      endExclusive: endExclusive,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
    final file = await _reportFile('.pdf');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pdfBytes, flush: true);
    return file.path;
  }

  List<TransactionRecord> _filterByPeriod(
    List<TransactionRecord> source,
    DateTime start,
    DateTime endExclusive,
  ) {
    final result = source.where((tx) {
      return !tx.transactionDate.isBefore(start) && tx.transactionDate.isBefore(endExclusive);
    }).toList(growable: false);
    result.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return result;
  }

  Future<File> _reportFile(String extension) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return File('${dir.path}/reports/catatuang_report_$stamp$extension');
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Uint8List _buildProfessionalPdf({
    required List<TransactionRecord> transactions,
    required DateTime start,
    required DateTime endExclusive,
    required int totalIncome,
    required int totalExpense,
  }) {
    String esc(String input) {
      return input.replaceAll('\\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
    }

    String text(double x, double y, String value, {int size = 10}) {
      return 'BT /F1 $size Tf $x $y Td (${esc(value)}) Tj ET\n';
    }
    String line(double x1, double y1, double x2, double y2) {
      return '$x1 $y1 m $x2 $y2 l S\n';
    }
    String rect(double x, double y, double w, double h) {
      return '$x $y $w $h re S\n';
    }

    final net = totalIncome - totalExpense;
    final categories = <String, int>{};
    for (final tx in transactions.where((tx) => tx.isExpense)) {
      categories[tx.category] = (categories[tx.category] ?? 0) + tx.amount;
    }
    final topCategories = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final content = StringBuffer()
      ..writeln('0.4 w')
      ..writeln('0 0 0 RG')
      ..write(text(42, 807, 'CatatUang Financial Report', size: 17))
      ..write(text(42, 789, 'Period: ${_fmtDate(start)} - ${_fmtDate(endExclusive.subtract(const Duration(days: 1)))}', size: 9))
      ..write(text(42, 777, 'Generated: ${_fmtDateTime(DateTime.now())}', size: 9))
      ..write(rect(40, 724, 515, 44))
      ..write(text(48, 751, 'Income: ${_fmtCurrency(totalIncome)}', size: 10))
      ..write(text(220, 751, 'Expense: ${_fmtCurrency(totalExpense)}', size: 10))
      ..write(text(410, 751, 'Net: ${_fmtCurrency(net)}', size: 10))
      ..write(text(48, 735, 'Transactions: ${transactions.length}', size: 9))
      ..write(text(220, 735, 'Expense Categories: ${categories.length}', size: 9))
      ..write(text(410, 735, 'Top: ${topCategories.isEmpty ? '-' : topCategories.first.key}', size: 9))
      ..write(rect(40, 325, 515, 388))
      ..write(text(46, 700, 'Date', size: 10))
      ..write(text(120, 700, 'Type', size: 10))
      ..write(text(176, 700, 'Amount', size: 10))
      ..write(text(270, 700, 'Wallet', size: 10))
      ..write(text(360, 700, 'Category', size: 10))
      ..write(text(452, 700, 'Note', size: 10))
      ..write(line(40, 694, 555, 694));

    var y = 681.0;
    for (final tx in transactions.take(20)) {
      final type = tx.isExpense ? 'Expense' : 'Income';
      final amount = '${tx.isExpense ? '-' : '+'}${_fmtCurrency(tx.amount)}';
      final note = tx.note.trim().isEmpty ? '-' : _truncate(tx.note.trim(), 18);
      content
        ..write(text(46, y, _fmtDate(tx.transactionDate), size: 9))
        ..write(text(120, y, type, size: 9))
        ..write(text(176, y, amount, size: 9))
        ..write(text(270, y, _truncate(tx.wallet, 12), size: 9))
        ..write(text(360, y, _truncate(tx.category, 13), size: 9))
        ..write(text(452, y, note, size: 9))
        ..write(line(40, y - 4, 555, y - 4));
      y -= 17;
    }

    content
      ..write(rect(40, 220, 515, 90))
      ..write(text(46, 295, 'Top Expense Categories', size: 10));
    var catY = 279.0;
    for (final entry in topCategories.take(4)) {
      content.write(text(50, catY, '${entry.key}: ${_fmtCurrency(entry.value)}', size: 9));
      catY -= 14;
    }
    if (topCategories.isEmpty) {
      content.write(text(50, 279, 'No expense categories in this period.', size: 9));
    }
    content.write(text(40, 204, 'Generated by CatatUang - Daily finance tracker', size: 8));

    final streamData = utf8.encode(content.toString());

    final objects = <String>[
      '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n',
      '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n',
      '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj\n',
      '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n',
      '5 0 obj << /Length ${streamData.length} >> stream\n${utf8.decode(streamData)}endstream endobj\n',
    ];

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    var current = buffer.toString().length;
    for (final obj in objects) {
      offsets.add(current);
      buffer.write(obj);
      current += obj.length;
    }
    final xrefStart = current;
    buffer.writeln('xref');
    buffer.writeln('0 ${objects.length + 1}');
    buffer.writeln('0000000000 65535 f ');
    for (var i = 1; i < offsets.length; i += 1) {
      buffer.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
    }
    buffer.writeln('trailer << /Size ${objects.length + 1} /Root 1 0 R >>');
    buffer.writeln('startxref');
    buffer.writeln(xrefStart);
    buffer.write('%%EOF');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 1)}.';
  }

  String _fmtDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  String _fmtDateTime(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '${_fmtDate(date)} $hh:$min';
  }

  String _fmtCurrency(int value) {
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return 'Rp $text';
  }
}
