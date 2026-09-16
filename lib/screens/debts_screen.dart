import 'package:flutter/material.dart';

import '../data/debt_store.dart';
import '../data/models/debt_record.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/debt_plan_service.dart';
import '../services/master_data_service.dart';
import '../services/thousand_separator_formatter.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  List<String> _wallets = const [];
  List<String> _expenseCategories = const [];
  List<String> _incomeCategories = const [];

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('debts')),
        actions: [
          IconButton(
            tooltip: t.t('debt_plan'),
            onPressed: _showPlanSheet,
            icon: const Icon(Icons.auto_graph_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(t.t('add_debt')),
      ),
      body: ValueListenableBuilder<List<DebtRecord>>(
        valueListenable: debtsNotifier,
        builder: (context, debts, _) {
          if (debts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.t('debts_desc'),
                  style: const TextStyle(color: AppUiTokens.textMuted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: debts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final debt = debts[index];
              return _DebtTile(
                debt: debt,
                settings: settings,
                t: t,
                onPay: () => _showPaySheet(debt),
                onEdit: () => _showForm(context, initial: debt),
                onDelete: () => _confirmDelete(debt),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context, {
    DebtRecord? initial,
  }) async {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    final nameController = TextEditingController(text: initial?.name ?? '');
    final amountController = TextEditingController(
      text: initial == null
          ? ''
          : ThousandSeparatorFormatter.format(initial.principal),
    );
    final remainingController = TextEditingController(
      text: initial == null
          ? ''
          : ThousandSeparatorFormatter.format(initial.remaining),
    );
    final interestController = TextEditingController(
      text: initial == null || initial.interestRatePercent == 0
          ? ''
          : initial.interestRatePercent.toString(),
    );
    var isReceivable = initial?.isReceivable ?? false;
    var dueDate = initial?.dueDate;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      initial == null ? t.t('add_debt') : t.t('edit'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(t.t('payable')),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(t.t('receivable')),
                        ),
                      ],
                      selected: {isReceivable},
                      onSelectionChanged: (value) =>
                          setSheetState(() => isReceivable = value.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: t.t('debt_name'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandSeparatorFormatter()],
                      decoration: InputDecoration(
                        labelText: t.t('amount'),
                        prefixText: '${settings.currencySymbol} ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: interestController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: t.t('debt_interest_rate'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (initial != null) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: remainingController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandSeparatorFormatter()],
                        decoration: InputDecoration(
                          labelText: t.t('debt_remaining'),
                          prefixText: '${settings.currencySymbol} ',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate ?? now,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (picked == null) return;
                        setSheetState(() => dueDate = picked);
                      },
                      icon: const Icon(Icons.event_rounded, size: 16),
                      label: Text(
                        dueDate == null
                            ? t.t('debt_no_due')
                            : '${t.t('debt_due')}: '
                                  '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            child: Text(t.t('cancel')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(sheetContext, true),
                            child: Text(t.t('save')),
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
    if (saved != true) return;
    final name = nameController.text.trim();
    final amount = _parse(amountController.text);
    final interest =
        double.tryParse(interestController.text.replaceAll(',', '.')) ?? 0;
    if (name.isEmpty || amount <= 0) {
      _snack(t.t('invalid_amount'));
      return;
    }
    try {
      if (initial == null) {
        await addDebt(
          name: name,
          isReceivable: isReceivable,
          amount: amount,
          dueDate: dueDate,
          interestRatePercent: interest,
        );
      } else {
        final remaining = initial.remaining > amount
            ? amount
            : (remainingController.text.isEmpty
                  ? initial.remaining
                  : _parse(remainingController.text));
        await updateDebt(
          DebtRecord()
            ..id = initial.id
            ..name = name
            ..isReceivable = isReceivable
            ..principal = amount
            ..remaining = remaining
            ..dueDate = dueDate
            ..note = initial.note
            ..interestRatePercent = interest
            ..isSettled = remaining <= 0
            ..createdAt = initial.createdAt,
        );
      }
    } catch (e) {
      _snack('${t.t('failed_to_save')}: $e');
    }
  }

  Future<void> _showPlanSheet() async {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    final paymentController = TextEditingController();
    var strategy = DebtStrategy.avalanche;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final payment = _parse(paymentController.text);
            final plan = DebtPlanService.instance.build(
              debts: debtsNotifier.value,
              monthlyPayment: payment,
              strategy: strategy,
            );
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.t('debt_plan'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<DebtStrategy>(
                      segments: [
                        ButtonSegment(
                          value: DebtStrategy.snowball,
                          label: Text(t.t('debt_snowball')),
                        ),
                        ButtonSegment(
                          value: DebtStrategy.avalanche,
                          label: Text(t.t('debt_avalanche')),
                        ),
                      ],
                      selected: {strategy},
                      onSelectionChanged: (value) =>
                          setSheetState(() => strategy = value.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: paymentController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandSeparatorFormatter()],
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        labelText: t.t('debt_monthly_payment'),
                        prefixText: '${settings.currencySymbol} ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (payment <= 0)
                      const SizedBox.shrink()
                    else if (!plan.feasible)
                      Text(
                        t.t('debt_not_feasible'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppUiTokens.dangerDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _planStat(
                              t.t('debt_months_to_free'),
                              '${plan.monthsToDebtFree}',
                            ),
                          ),
                          Expanded(
                            child: _planStat(
                              t.t('debt_interest_total'),
                              settings.formatCurrency(plan.totalInterest),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...plan.steps.map(
                        (step) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  step.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${step.months} bln • '
                                '${settings.formatCurrency(step.interestPaid)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppUiTokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _planStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppUiTokens.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Future<void> _showPaySheet(DebtRecord debt) async {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    final amountController = TextEditingController(
      text: ThousandSeparatorFormatter.format(debt.remaining),
    );
    final categories = debt.isReceivable
        ? _incomeCategories
        : _expenseCategories;
    var wallet = _wallets.isNotEmpty ? _wallets.first : 'cash';
    var category = categories.isNotEmpty ? categories.first : 'others';
    var createTransaction = true;

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.t('debt_settle')} - ${debt.name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandSeparatorFormatter()],
                      decoration: InputDecoration(
                        labelText: t.t('debt_payment_amount'),
                        prefixText: '${settings.currencySymbol} ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: wallet,
                      decoration: InputDecoration(
                        labelText: t.t('wallet_field'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _wallets
                          .map(
                            (w) => DropdownMenuItem(value: w, child: Text(w)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setSheetState(() => wallet = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: t.t('category'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setSheetState(() => category = value);
                      },
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        t.t('add_note'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: createTransaction,
                      onChanged: (value) =>
                          setSheetState(() => createTransaction = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            child: Text(t.t('cancel')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(sheetContext, true),
                            child: Text(t.t('debt_settle')),
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
    if (paid != true) return;
    final amount = _parse(amountController.text);
    if (amount <= 0) {
      _snack(t.t('invalid_amount'));
      return;
    }
    try {
      await payDebt(
        debtId: debt.id,
        amount: amount,
        wallet: wallet,
        category: category,
        transactionDate: DateTime.now(),
        createTransaction: createTransaction,
      );
      _snack(t.t('save_data'));
    } catch (e) {
      _snack('${t.t('failed_to_save')}: $e');
    }
  }

  Future<void> _confirmDelete(DebtRecord debt) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.t('delete')),
        content: Text(debt.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await deleteDebt(debt.id);
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

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.debt,
    required this.settings,
    required this.t,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final DebtRecord debt;
  final AppSettings settings;
  final AppLocalizations t;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = debt.principal <= 0
        ? 0.0
        : (1 - debt.remaining / debt.principal).clamp(0.0, 1.0);
    final accent = debt.isReceivable
        ? AppUiTokens.successDeep
        : AppUiTokens.dangerDeep;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppUiTokens.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  debt.isReceivable ? t.t('receivable') : t.t('payable'),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  debt.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (debt.isSettled)
                Text(
                  t.t('debt_settled'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppUiTokens.successDeep,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t.t('debt_remaining')}: ${settings.formatCurrency(debt.remaining)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: debt.isSettled ? AppUiTokens.successDeep : accent,
                  ),
                ),
              ),
              Text(
                '${t.t('amount')}: ${settings.formatCurrency(debt.principal)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppUiTokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppUiTokens.borderSoft,
              color: accent,
            ),
          ),
          if (debt.dueDate != null) ...[
            const SizedBox(height: 4),
            Text(
              '${t.t('debt_due')}: '
              '${debt.dueDate!.day}/${debt.dueDate!.month}/${debt.dueDate!.year}',
              style: const TextStyle(
                fontSize: 10,
                color: AppUiTokens.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              if (!debt.isSettled)
                TextButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payments_rounded, size: 16),
                  label: Text(t.t('debt_settle')),
                ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppUiTokens.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
