import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/transaction_record.dart';
import '../data/transaction_store.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/category_budget_service.dart';
import '../services/master_data_service.dart';
import '../services/thousand_separator_formatter.dart';

class CategoryBudgetCard extends StatefulWidget {
  const CategoryBudgetCard({super.key, this.compact = false});

  final bool compact;

  @override
  State<CategoryBudgetCard> createState() => _CategoryBudgetCardState();
}

class _CategoryBudgetCardState extends State<CategoryBudgetCard> {
  Map<String, int> _budgets = {};

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    CategoryBudgetService.instance.addListener(_loadBudgets);
  }

  @override
  void dispose() {
    CategoryBudgetService.instance.removeListener(_loadBudgets);
    super.dispose();
  }

  Future<void> _loadBudgets() async {
    final budgets = await CategoryBudgetService.instance.getAllBudgets();
    if (!mounted) return;
    setState(() => _budgets = budgets);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);

    if (_budgets.isEmpty) return const SizedBox.shrink();

    final txs = transactionsNotifier.value;
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month, 1);
    final periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final period = DateTimeRange(start: periodStart, end: periodEnd);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppUiTokens.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppUiTokens.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart_rounded,
                size: 14,
                color: AppUiTokens.brandBlue,
              ),
              const SizedBox(width: 6),
              Text(
                t.t('budget_per_category'),
                style: TextStyle(
                  fontSize: widget.compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => showCategoryBudgetSheet(context),
                child: const Icon(
                  Icons.settings_rounded,
                  size: 14,
                  color: AppUiTokens.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 6 : 8),
          ..._budgets.entries.map((entry) {
            final spent = CategoryBudgetService.instance.getSpentForCategory(
              entry.key,
              txs,
              period,
            );
            final limit = entry.value;
            final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.5) : 0.0;
            final displayRatio = ratio.clamp(0.0, 1.0);
            final color = ratio >= 1.0
                ? AppUiTokens.danger
                : ratio >= 0.8
                    ? AppUiTokens.warning
                    : AppUiTokens.success;

            return Padding(
              padding: EdgeInsets.only(bottom: widget.compact ? 6 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categoryLabel(entry.key),
                          style: TextStyle(
                            fontSize: widget.compact ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            color: AppUiTokens.textBody,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${settings.formatCurrency(spent)} / ${settings.formatCurrency(limit)}',
                        style: TextStyle(
                          fontSize: widget.compact ? 9 : 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: displayRatio,
                      minHeight: widget.compact ? 5 : 6,
                      backgroundColor: AppUiTokens.borderSoft,
                      color: color,
                    ),
                  ),
                  if (ratio >= 1.0) ...[
                    const SizedBox(height: 2),
                    Text(
                      t.t('over_budget'),
                      style: TextStyle(
                        fontSize: widget.compact ? 8.5 : 9,
                        fontWeight: FontWeight.w600,
                        color: AppUiTokens.danger,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _categoryLabel(String key) {
    // Capitalize first letter
    if (key.isEmpty) return key;
    return key[0].toUpperCase() + key.substring(1);
  }
}

/// Shows the bottom sheet for managing per-category budgets.
Future<void> showCategoryBudgetSheet(BuildContext context) async {
  final t = AppLocalizations.of(context);
  final settings = AppSettingsScope.of(context);
  final categories = await MasterDataService.instance.expenseCategories();

  if (!context.mounted) return;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            bottomInset > 0 ? bottomInset + 12 : 12,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppUiTokens.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: _CategoryBudgetSheetContent(
                categories: categories,
                t: t,
                settings: settings,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CategoryBudgetSheetContent extends StatefulWidget {
  const _CategoryBudgetSheetContent({
    required this.categories,
    required this.t,
    required this.settings,
  });

  final List<String> categories;
  final AppLocalizations t;
  final AppSettings settings;

  @override
  State<_CategoryBudgetSheetContent> createState() =>
      _CategoryBudgetSheetContentState();
}

class _CategoryBudgetSheetContentState
    extends State<_CategoryBudgetSheetContent> {
  Map<String, int> _budgets = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budgets = await CategoryBudgetService.instance.getAllBudgets();
    if (!mounted) return;
    setState(() => _budgets = budgets);
  }

  @override
  Widget build(BuildContext context) {
    final txs = transactionsNotifier.value;
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month, 1);
    final periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final period = DateTimeRange(start: periodStart, end: periodEnd);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppUiTokens.borderSoft,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.t.t('budget_per_category'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          widget.t.t('set_budget'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppUiTokens.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.categories.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: AppUiTokens.borderSoft,
            ),
            itemBuilder: (context, index) {
              final category = widget.categories[index];
              final budget = _budgets[category] ?? 0;
              final spent =
                  CategoryBudgetService.instance.getSpentForCategory(
                category,
                txs,
                period,
              );
              final hasBudget = budget > 0;
              final ratio = hasBudget
                  ? (spent / budget).clamp(0.0, 1.5)
                  : 0.0;
              final color = ratio >= 1.0
                  ? AppUiTokens.danger
                  : ratio >= 0.8
                      ? AppUiTokens.warning
                      : AppUiTokens.success;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                title: Text(
                  _categoryLabel(category),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: hasBudget
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: AppUiTokens.borderSoft,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.settings.formatCurrency(spent)} / ${widget.settings.formatCurrency(budget)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        widget.t.t('no_budget_set'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppUiTokens.textMuted,
                        ),
                      ),
                trailing: IconButton(
                  icon: Icon(
                    hasBudget ? Icons.edit_rounded : Icons.add_rounded,
                    size: 18,
                    color: AppUiTokens.brandBlue,
                  ),
                  onPressed: () => _showEditBudget(category, budget),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEditBudget(String category, int currentBudget) async {
    final controller = TextEditingController(
      text: currentBudget > 0
          ? ThousandSeparatorFormatter.format(currentBudget)
          : '',
    );

    final result = await showDialog<int?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            '${widget.t.t('set_budget')} - ${_categoryLabel(category)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              ThousandSeparatorFormatter(),
            ],
            decoration: InputDecoration(
              labelText: widget.t.t('budget_limit'),
              hintText: '500.000',
              prefixIcon:
                  const Icon(Icons.payments_rounded, size: 18),
              filled: true,
              fillColor: AppUiTokens.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppUiTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppUiTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppUiTokens.brandBlue,
                  width: 1.35,
                ),
              ),
            ),
          ),
          actions: [
            if (currentBudget > 0)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, -1),
                child: Text(
                  widget.t.t('delete'),
                  style: const TextStyle(color: AppUiTokens.danger),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text(widget.t.t('cancel')),
            ),
            FilledButton(
              onPressed: () {
                final raw =
                    controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                final value = int.tryParse(raw) ?? 0;
                Navigator.pop(dialogContext, value);
              },
              child: Text(widget.t.t('save')),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    if (result == -1) {
      await CategoryBudgetService.instance.removeBudget(category);
    } else if (result > 0) {
      await CategoryBudgetService.instance.setBudget(category, result);
    }
    await _load();
  }

  String _categoryLabel(String key) {
    if (key.isEmpty) return key;
    return key[0].toUpperCase() + key.substring(1);
  }
}
