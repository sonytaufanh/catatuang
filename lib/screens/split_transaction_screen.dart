import 'package:flutter/material.dart';

import '../data/database_service.dart';
import '../data/transaction_store.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/error_log_service.dart';
import '../services/master_data_service.dart';
import '../services/thousand_separator_formatter.dart';

class SplitTransactionScreen extends StatefulWidget {
  const SplitTransactionScreen({super.key});

  @override
  State<SplitTransactionScreen> createState() => _SplitTransactionScreenState();
}

class _PartDraft {
  _PartDraft(this.category);

  String category;
  final TextEditingController amount = TextEditingController();
  final TextEditingController note = TextEditingController();

  void dispose() {
    amount.dispose();
    note.dispose();
  }
}

class _SplitTransactionScreenState extends State<SplitTransactionScreen> {
  static const int _maxAmount = 1000000000;

  bool _isExpense = true;
  String _wallet = 'cash';
  DateTime _date = DateTime.now();
  List<String> _wallets = const [];
  List<String> _categories = const [];
  final List<_PartDraft> _parts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parts.add(_PartDraft('food'));
    _parts.add(_PartDraft('shopping'));
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    final wallets = await MasterDataService.instance.wallets();
    final categories = _isExpense
        ? await MasterDataService.instance.expenseCategories()
        : await MasterDataService.instance.incomeCategories();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _categories = categories;
      if (!_wallets.contains(_wallet) && _wallets.isNotEmpty) {
        _wallet = _wallets.first;
      }
      for (final part in _parts) {
        if (!_categories.contains(part.category) && _categories.isNotEmpty) {
          part.category = _categories.first;
        }
      }
    });
  }

  @override
  void dispose() {
    for (final part in _parts) {
      part.dispose();
    }
    super.dispose();
  }

  int get _total {
    var total = 0;
    for (final part in _parts) {
      total += _parse(part.amount.text);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('split_transaction'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => _setType(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isExpense
                        ? AppUiTokens.brandBlueLight
                        : null,
                  ),
                  child: Text(t.t('expense_tab')),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => _setType(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: !_isExpense
                        ? AppUiTokens.brandBlueLight
                        : null,
                  ),
                  child: Text(t.t('income_tab')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded, size: 16),
            label: Text(
              '${_date.day}/${_date.month}/${_date.year}',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            t.t('category'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          ...List.generate(_parts.length, _buildPartRow),
          TextButton.icon(
            onPressed: () => setState(
              () => _parts.add(
                _PartDraft(_categories.isEmpty ? 'others' : _categories.first),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(t.t('split_add_part')),
          ),
          const Divider(),
          Row(
            children: [
              Text(
                t.t('total'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                s.formatCurrency(_total),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppUiTokens.brandBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(t.t('save_data')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartRow(int index) {
    final t = AppLocalizations.of(context);
    final s = AppSettingsScope.of(context);
    final part = _parts[index];
    final options = _categories.contains(part.category)
        ? _categories
        : [part.category, ..._categories];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiTokens.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: part.category,
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
              ),
              items: options
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => part.category = value);
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: TextField(
              controller: part.amount,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandSeparatorFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '${s.currencySymbol} ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: _parts.length <= 2
                ? null
                : () => setState(() {
                    part.dispose();
                    _parts.removeAt(index);
                  }),
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: t.t('delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _setType(bool expense) async {
    if (_isExpense == expense) return;
    final categories = expense
        ? await MasterDataService.instance.expenseCategories()
        : await MasterDataService.instance.incomeCategories();
    if (!mounted) return;
    setState(() {
      _isExpense = expense;
      _categories = categories;
      for (final part in _parts) {
        if (!_categories.contains(part.category) && _categories.isNotEmpty) {
          part.category = _categories.first;
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final settings = AppSettingsScope.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    if (!settings.txIncludeTime) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null || !mounted) return;
    setState(
      () => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final s = AppSettingsScope.of(context);
    final parts = <SplitPart>[];
    for (final part in _parts) {
      final amount = _parse(part.amount.text);
      if (amount <= 0 || part.category.trim().isEmpty) continue;
      parts.add(
        SplitPart(category: part.category, amount: amount, note: part.note.text),
      );
    }
    if (parts.length < 2) {
      _snack(t.t('split_min_parts'));
      return;
    }
    if (_total > _maxAmount) {
      _snack(t.t('max_amount_error'));
      return;
    }
    final txDate = s.txIncludeTime
        ? _date
        : DateTime(_date.year, _date.month, _date.day);
    setState(() => _saving = true);
    try {
      await MasterDataService.instance.ensureMasterContains(
        wallet: _wallet,
        category: parts.first.category,
        isExpense: _isExpense,
      );
      await DatabaseService.instance.addSplitTransaction(
        isExpense: _isExpense,
        wallet: _wallet,
        transactionDate: txDate,
        parts: parts,
        currency: s.currencyCode,
      );
      await refreshTransactions();
      if (!mounted) return;
      _snack(t.t('split_saved'));
      Navigator.pop(context, true);
    } catch (e) {
      await ErrorLogService.instance.log(source: 'split_save', error: e);
      _snack('${t.t('failed_to_save')}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _parse(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
