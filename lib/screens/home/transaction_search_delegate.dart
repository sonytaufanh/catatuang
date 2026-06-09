import 'package:flutter/material.dart';

import '../../data/models/transaction_record.dart';
import '../../services/app_localizations.dart';
import '../../services/app_settings.dart';
import '../../services/app_ui_tokens.dart';

class TransactionSearchDelegate extends SearchDelegate<void> {
  TransactionSearchDelegate({
    required this.transactions,
    required this.settings,
    required this.t,
    required this.categoryLabel,
  });

  final List<TransactionRecord> transactions;
  final AppSettings settings;
  final AppLocalizations t;
  final String Function(AppLocalizations t, String key) categoryLabel;
  String _typeFilter = 'all';
  bool _recent30DaysOnly = false;

  @override
  String get searchFieldLabel => t.t('search_hint');

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => _showFilterSheet(context),
        icon: const Icon(Icons.tune_rounded),
      ),
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.trim().toLowerCase();
    final now = DateTime.now();
    final minDate = now.subtract(const Duration(days: 30));
    final filtered = transactions.where((tx) {
      if (_typeFilter == 'income' && tx.isExpense) return false;
      if (_typeFilter == 'expense' && !tx.isExpense) return false;
      if (_recent30DaysOnly && tx.transactionDate.isBefore(minDate)) return false;
      if (q.isEmpty) return true;
      final amount = tx.amount.toString();
      final category = categoryLabel(t, tx.category).toLowerCase();
      final note = tx.note.toLowerCase();
      final wallet = tx.wallet.toLowerCase();
      return amount.contains(q) || category.contains(q) || note.contains(q) || wallet.contains(q);
    }).take(30).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          t.t('search_empty'),
          style: const TextStyle(fontSize: 12, color: AppUiTokens.textMuted),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = filtered[index];
        final isExpense = tx.isExpense;
        final amountText = isExpense
            ? '-${settings.formatCurrency(tx.amount)}'
            : '+${settings.formatCurrency(tx.amount)}';
        return ListTile(
          dense: true,
          leading: Icon(
            isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
            size: 18,
            color: isExpense ? AppUiTokens.dangerDark : AppUiTokens.successDeep,
          ),
          title: Text(
            categoryLabel(t, tx.category),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            tx.note.isEmpty ? tx.wallet : tx.note,
            style: const TextStyle(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            amountText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isExpense ? AppUiTokens.dangerDark : AppUiTokens.successDeep,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    var tempType = _typeFilter;
    var tempRecent = _recent30DaysOnly;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _txt(id: 'Filter Pencarian', en: 'Search Filters'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          label: _txt(id: 'Semua Tipe', en: 'All Types'),
                          selected: tempType == 'all',
                          onTap: () => setModalState(() => tempType = 'all'),
                        ),
                        _chip(
                          label: t.t('income'),
                          selected: tempType == 'income',
                          onTap: () => setModalState(() => tempType = 'income'),
                        ),
                        _chip(
                          label: t.t('expense'),
                          selected: tempType == 'expense',
                          onTap: () => setModalState(() => tempType = 'expense'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: tempRecent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _txt(id: '30 hari terakhir', en: 'Last 30 days'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      onChanged: (value) => setModalState(() => tempRecent = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _typeFilter = 'all';
                              _recent30DaysOnly = false;
                              showSuggestions(context);
                              Navigator.pop(context);
                            },
                            child: Text(_txt(id: 'Reset', en: 'Reset')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              _typeFilter = tempType;
                              _recent30DaysOnly = tempRecent;
                              showSuggestions(context);
                              Navigator.pop(context);
                            },
                            child: Text(_txt(id: 'Terapkan', en: 'Apply')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppUiTokens.brandBlueTint : AppUiTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppUiTokens.brandBlueBorderStrong : AppUiTokens.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? AppUiTokens.brandBlueDark : AppUiTokens.textMuted,
          ),
        ),
      ),
    );
  }

  String _txt({required String id, required String en}) {
    if (t.locale.languageCode == 'en') return en;
    return id;
  }
}
