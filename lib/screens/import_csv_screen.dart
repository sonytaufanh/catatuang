import 'package:flutter/material.dart';

import '../data/database_service.dart';
import '../data/transaction_store.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/master_data_service.dart';
import '../services/transaction_import_service.dart';

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  final TextEditingController _input = TextEditingController();
  List<ImportedTransaction> _rows = const [];
  List<String> _wallets = const [];
  List<String> _expenseCategories = const [];
  List<String> _incomeCategories = const [];
  String _wallet = 'cash';
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    final wallets = await MasterDataService.instance.wallets();
    final expense = await MasterDataService.instance.expenseCategories();
    final income = await MasterDataService.instance.incomeCategories();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _expenseCategories = expense;
      _incomeCategories = income;
      if (wallets.isNotEmpty && !wallets.contains(_wallet)) {
        _wallet = wallets.first;
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('import_csv'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Text(
            t.t('import_csv_desc'),
            style: const TextStyle(fontSize: 12, color: AppUiTokens.textMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _input,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: t.t('import_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _parse,
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                  label: Text(t.t('import_parse')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _rows.isEmpty || _importing ? null : _import,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text('${t.t('import_action')} (${_selectedCount()})'),
                ),
              ),
            ],
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _wallet,
              decoration: InputDecoration(
                labelText: t.t('wallet_field'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: _wallets
                  .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _wallet = value);
              },
            ),
            const SizedBox(height: 6),
            Text(
              '${_rows.length} ${t.t('import_rows_found')}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...List.generate(_rows.length, (index) {
              final row = _rows[index];
              return _ImportRowTile(
                row: row,
                settings: settings,
                categories: row.isExpense
                    ? _expenseCategories
                    : _incomeCategories,
                onToggle: (value) => setState(() => row.selected = value),
                onCategoryChanged: (value) => setState(() => row.category = value),
              );
            }),
          ] else if (_input.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              t.t('import_none'),
              style: const TextStyle(fontSize: 11, color: AppUiTokens.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  int _selectedCount() => _rows.where((row) => row.selected).length;

  void _parse() {
    final rows = TransactionImportService.instance.parse(_input.text);
    setState(() => _rows = rows);
  }

  Future<void> _import() async {
    final t = AppLocalizations.of(context);
    setState(() => _importing = true);
    var imported = 0;
    try {
      for (final row in _rows) {
        if (!row.selected) continue;
        await DatabaseService.instance.addTransaction(
          isExpense: row.isExpense,
          amount: row.amount,
          wallet: _wallet,
          category: row.category,
          transactionDate: row.date,
          isCleared: true,
          note: row.description,
        );
        imported += 1;
      }
      await refreshTransactions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.t('import_success')}: $imported')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t.t('failed_to_save')}: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

class _ImportRowTile extends StatelessWidget {
  const _ImportRowTile({
    required this.row,
    required this.settings,
    required this.categories,
    required this.onToggle,
    required this.onCategoryChanged,
  });

  final ImportedTransaction row;
  final AppSettings settings;
  final List<String> categories;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final amountText =
        '${row.isExpense ? '-' : '+'}${settings.formatCurrency(row.amount)}';
    final options = categories.contains(row.category)
        ? categories
        : [row.category, ...categories];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiTokens.borderSoft),
      ),
      child: Row(
        children: [
          Checkbox(value: row.selected, onChanged: (v) => onToggle(v ?? false)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${row.date.day}/${row.date.month}/${row.date.year}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppUiTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<String>(
              initialValue: row.category,
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              items: options
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value != null) onCategoryChanged(value);
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            amountText,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: row.isExpense
                  ? AppUiTokens.dangerDeep
                  : AppUiTokens.successDeep,
            ),
          ),
        ],
      ),
    );
  }
}
