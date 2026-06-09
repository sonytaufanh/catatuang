import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/transaction_record.dart';
import '../data/database_service.dart';
import '../data/transaction_store.dart';
import '../services/app_localizations.dart';
import '../services/app_animations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/biometric_lock_service.dart';
import '../services/master_data_service.dart';
import 'add_transaction_screen.dart';
import 'home/home_formatters.dart';
import 'home/transaction_search_delegate.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String periodFilter = 'all';
  String typeFilter = 'all';
  String walletFilter = 'all';
  String categoryFilter = 'all';
  int? minAmountFilter;
  int? maxAmountFilter;
  DateTime? customStartDate;
  DateTime? customEndDate;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final compact = screenHeight < 960;
    final veryCompact = screenHeight < 820;

    return AnimatedBuilder(
      animation: MasterDataService.instance,
      builder: (context, _) {
        return ValueListenableBuilder<List<TransactionRecord>>(
          valueListenable: transactionsNotifier,
          builder: (context, txs, _) {
            final sorted = [...txs]
              ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
            final filtered = _applyFilters(sorted);
            final totalBalance =
                MasterDataService.instance.openingBalanceTotal +
                _totalBalance(sorted);
            final cashflow = _cashflowTotals(filtered);
            final incomeTotal = cashflow.income;
            final expenseTotal = cashflow.expense;
            final diffTotal = incomeTotal - expenseTotal;

            return SafeArea(
              child: AnimatedFadeSlide(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    compact ? AppUiTokens.space6 : AppUiTokens.space8,
                    compact ? AppUiTokens.space4 : AppUiTokens.space6,
                    compact ? AppUiTokens.space6 : AppUiTokens.space8,
                    veryCompact ? 66 : 80,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedTabReveal(
                        tabIndex: 2,
                        delay: const Duration(milliseconds: 20),
                        child: _buildHeader(
                          context,
                          t,
                          filtered.length,
                          compact: compact,
                        ),
                      ),
                      SizedBox(
                        height: compact
                            ? AppUiTokens.space4
                            : AppUiTokens.space6,
                      ),
                      AnimatedTabReveal(
                        tabIndex: 2,
                        delay: const Duration(milliseconds: 80),
                        child: _buildSummaryCard(
                          context: context,
                          settings: settings,
                          t: t,
                          totalBalance: totalBalance,
                          incomeTotal: incomeTotal,
                          expenseTotal: expenseTotal,
                          diffTotal: diffTotal,
                          compact: compact,
                        ),
                      ),
                      SizedBox(
                        height: compact
                            ? AppUiTokens.space4
                            : AppUiTokens.space5,
                      ),
                      AnimatedTabReveal(
                        tabIndex: 2,
                        delay: const Duration(milliseconds: 130),
                        child: _buildQuickPeriodBar(context, compact: compact),
                      ),
                      SizedBox(
                        height: compact
                            ? AppUiTokens.space3
                            : AppUiTokens.space4,
                      ),
                      AnimatedTabReveal(
                        tabIndex: 2,
                        delay: const Duration(milliseconds: 160),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildFilterChip(
                              label:
                                  '${_i18n(context, id: 'Periode', en: 'Period')}: ${_periodLabel(context, t, periodFilter)}',
                              isActive: periodFilter != 'all',
                            ),
                            _buildFilterChip(
                              label:
                                  '${_i18n(context, id: 'Tipe', en: 'Type')}: ${_typeLabel(context, t, typeFilter)}',
                              isActive: typeFilter != 'all',
                            ),
                            _buildFilterChip(
                              label:
                                  '${_i18n(context, id: 'Dompet', en: 'Wallet')}: ${_walletLabel(t, walletFilter)}',
                              isActive: walletFilter != 'all',
                            ),
                            _buildFilterChip(
                              label:
                                  '${_i18n(context, id: 'Kategori', en: 'Category')}: ${categoryFilter == 'all' ? _i18n(context, id: 'Semua', en: 'All') : _categoryLabel(t, categoryFilter)}',
                              isActive: categoryFilter != 'all',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? AppUiTokens.space5 : 14),
                      AnimatedTabReveal(
                        tabIndex: 2,
                        delay: const Duration(milliseconds: 210),
                        child: _buildHistoryHeader(
                          context,
                          t,
                          filtered.length,
                          compact: compact,
                        ),
                      ),
                      SizedBox(
                        height: compact
                            ? AppUiTokens.space4
                            : AppUiTokens.space5,
                      ),
                      AnimatedTabReveal(
                        tabIndex: 2,
                        delay: const Duration(milliseconds: 260),
                        child: _buildHistoryCard(
                          context: context,
                          settings: settings,
                          t: t,
                          transactions: filtered,
                          compact: compact,
                          veryCompact: veryCompact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations t,
    int count, {
    required bool compact,
  }) {
    final activeFilters = _activeFilterCount();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.t('wallet_title'),
              style: TextStyle(
                fontSize: compact ? 20 : AppUiTokens.textDisplay,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _summaryLabel(context, count),
              style: const TextStyle(
                fontSize: AppUiTokens.textSm,
                fontWeight: FontWeight.w600,
                color: AppUiTokens.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _activeFilterSummary(context),
              style: const TextStyle(
                fontSize: AppUiTokens.textXs,
                fontWeight: FontWeight.w600,
                color: AppUiTokens.textTertiary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            PressableScale(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                showSearch<void>(
                  context: context,
                  delegate: TransactionSearchDelegate(
                    transactions: transactionsNotifier.value,
                    settings: AppSettingsScope.of(context),
                    t: AppLocalizations.of(context),
                    categoryLabel: homeCategoryLabel,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: _panelDecoration(context),
                child: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppUiTokens.brandBlueDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PressableScale(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showFilterSheet(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: _panelDecoration(context),
                child: Badge(
                  isLabelVisible: activeFilters > 0,
                  smallSize: 8,
                  backgroundColor: AppUiTokens.brandBlue,
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: AppUiTokens.brandBlueDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistoryHeader(
    BuildContext context,
    AppLocalizations t,
    int count, {
    required bool compact,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.t('income_expense_history'),
              style: TextStyle(
                fontSize: compact ? AppUiTokens.textMd : AppUiTokens.textLg,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _i18n(
                context,
                id: 'Aktivitas terbaru sesuai filter aktif',
                en: 'Latest activity based on active filters',
              ),
              style: const TextStyle(
                fontSize: AppUiTokens.textXs,
                color: AppUiTokens.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppUiTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppUiTokens.borderSoft),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: AppUiTokens.textSm,
              fontWeight: FontWeight.w700,
              color: AppUiTokens.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required AppSettings settings,
    required AppLocalizations t,
    required int totalBalance,
    required int incomeTotal,
    required int expenseTotal,
    required int diffTotal,
    required bool compact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppUiTokens.brandBlueSoft, AppUiTokens.brandBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: AppUiTokens.brandBlue.withValues(alpha: 0.26),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.t('active_balance'),
                style: const TextStyle(
                  color: AppUiTokens.white70,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppUiTokens.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppUiTokens.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            settings.formatBalanceCurrency(totalBalance),
            style: TextStyle(
              color: AppUiTokens.white,
              fontSize: compact ? 24 : 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _i18n(
              context,
              id: 'Ringkasan saldo dan arus kas terbaru',
              en: 'Latest balance and cashflow snapshot',
            ),
            style: const TextStyle(
              color: AppUiTokens.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniSummary(
                  t.t('income'),
                  settings.formatCurrency(incomeTotal),
                  Icons.south_west_rounded,
                  compact: compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummary(
                  t.t('expense'),
                  settings.formatCurrency(expenseTotal),
                  Icons.north_east_rounded,
                  compact: compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummary(
                  t.t('difference'),
                  settings.formatSignedCurrency(diffTotal),
                  Icons.account_balance_wallet_rounded,
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPeriodBar(BuildContext context, {required bool compact}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSelectableChip(
          _i18n(context, id: 'Semua', en: 'All'),
          periodFilter == 'all',
          () => setState(() {
            periodFilter = 'all';
            customStartDate = null;
            customEndDate = null;
          }),
        ),
        _buildSelectableChip(
          _i18n(context, id: 'Hari Ini', en: 'Today'),
          periodFilter == 'today',
          () => setState(() => periodFilter = 'today'),
        ),
        _buildSelectableChip(
          _i18n(context, id: '7 Hari', en: '7 Days'),
          periodFilter == 'week',
          () => setState(() => periodFilter = 'week'),
        ),
        _buildSelectableChip(
          _i18n(context, id: 'Bulan Ini', en: 'This Month'),
          periodFilter == 'this_month',
          () => setState(() => periodFilter = 'this_month'),
        ),
        _buildSelectableChip(
          _i18n(context, id: 'Siklus', en: 'Cycle'),
          periodFilter == 'cycle',
          () => setState(() => periodFilter = 'cycle'),
        ),
      ],
    );
  }

  Widget _buildMiniSummary(
    String label,
    String amount,
    IconData icon, {
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppUiTokens.white.withValues(alpha: 0.2),
            AppUiTokens.white.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiTokens.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 13 : 14, color: AppUiTokens.white),
          SizedBox(height: compact ? 4 : 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              color: AppUiTokens.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 8 : 8.5,
              color: AppUiTokens.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [AppUiTokens.surfaceBlueSoft, AppUiTokens.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : AppUiTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive ? AppUiTokens.brandBlueBorder : AppUiTokens.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            const Icon(
              Icons.check_circle_rounded,
              size: 12,
              color: AppUiTokens.brandBlueDark,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? AppUiTokens.brandBlueDark
                  : AppUiTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppUiTokens.border),
      boxShadow: [
        BoxShadow(
          color: AppUiTokens.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildHistoryCard({
    required BuildContext context,
    required AppSettings settings,
    required AppLocalizations t,
    required List<TransactionRecord> transactions,
    required bool compact,
    required bool veryCompact,
  }) {
    if (transactions.isEmpty) {
      return AnimatedTabReveal(
        tabIndex: 2,
        delay: const Duration(milliseconds: 260),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppUiTokens.border),
            boxShadow: [
              BoxShadow(
                color: AppUiTokens.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.inbox_rounded,
                color: AppUiTokens.textTertiary,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                _i18n(
                  context,
                  id: 'Belum ada transaksi sesuai filter.',
                  en: 'No transactions match this filter.',
                ),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppUiTokens.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _i18n(
                  context,
                  id: 'Coba ubah filter atau tambah transaksi baru.',
                  en: 'Try adjusting the filter or add a new transaction.',
                ),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppUiTokens.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final limit = veryCompact ? 6 : (compact ? 8 : 10);
    final limited = transactions.take(limit).toList(growable: false);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppUiTokens.border),
        boxShadow: [
          BoxShadow(
            color: AppUiTokens.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < limited.length; i++) ...[
            AnimatedTabReveal(
              tabIndex: 2,
              delay: Duration(milliseconds: 260 + (i * 35)),
              child: _buildActivityRow(
                context: context,
                t: t,
                settings: settings,
                tx: limited[i],
              ),
            ),
            if (i < limited.length - 1)
              Divider(
                height: 1,
                color: AppUiTokens.borderLight,
                indent: 52,
                endIndent: 12,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityRow({
    required BuildContext context,
    required AppLocalizations t,
    required AppSettings settings,
    required TransactionRecord tx,
  }) {
    final color = tx.isExpense ? AppUiTokens.danger : AppUiTokens.success;
    final amount = tx.isExpense
        ? '-${settings.formatCurrency(tx.amount)}'
        : '+${settings.formatCurrency(tx.amount)}';
    final wallet = _walletLabel(t, tx.wallet);
    final date = _formatDate(tx.transactionDate);

    return PressableScale(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _editTransaction(context, tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                tx.isExpense
                    ? Icons.call_made_rounded
                    : Icons.call_received_rounded,
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categoryLabel(t, tx.category),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (tx.note.isNotEmpty)
                    Text(
                      tx.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppUiTokens.textPrimarySoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (tx.note.isNotEmpty) const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _metaPill(wallet, AppUiTokens.brandBlueSoft),
                      _metaPill(date, AppUiTokens.info),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildRowAction(
                        context: context,
                        label: _i18n(context, id: 'Edit', en: 'Edit'),
                        icon: Icons.edit_outlined,
                        onTap: () => _editTransaction(context, tx),
                      ),
                      _buildRowAction(
                        context: context,
                        label: _i18n(context, id: 'Duplikat', en: 'Duplicate'),
                        icon: Icons.copy_all_rounded,
                        onTap: () => _duplicateTransaction(context, tx),
                      ),
                      _buildRowAction(
                        context: context,
                        label: _i18n(context, id: 'Hapus', en: 'Delete'),
                        icon: Icons.delete_outline_rounded,
                        destructive: true,
                        onTap: () => _deleteTransaction(context, tx),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowAction({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? AppUiTokens.danger : AppUiTokens.brandBlueDark;
    return PressableScale(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaPill(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _editTransaction(
    BuildContext context,
    TransactionRecord tx,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute<Object?>(
        builder: (_) => AddTransactionScreen(editTransaction: tx),
      ),
    );
    if (!context.mounted) return;
    showTransactionSaveResultSnack(
      context,
      result,
      fallbackIsExpense: tx.isExpense,
    );
  }

  Future<void> _duplicateTransaction(
    BuildContext context,
    TransactionRecord tx,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute<Object?>(
        builder: (_) => AddTransactionScreen(
          initialIsExpense: tx.isExpense,
          initialWallet: tx.wallet,
          initialCategory: tx.category,
          initialNote: tx.note,
        ),
      ),
    );
    if (!context.mounted) return;
    showTransactionSaveResultSnack(
      context,
      result,
      fallbackIsExpense: tx.isExpense,
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    TransactionRecord tx,
  ) async {
    final allowed = await BiometricLockService.instance
        .authenticateForSensitiveAction(
          reason: 'Verifikasi biometrik untuk menghapus transaksi',
        );
    if (!allowed) return;
    await DatabaseService.instance.deleteTransaction(tx.id);
    await refreshTransactions();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _i18n(context, id: 'Transaksi dihapus', en: 'Transaction deleted'),
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    final t = AppLocalizations.of(context);
    var tempPeriod = periodFilter;
    var tempType = typeFilter;
    var tempWallet = walletFilter;
    var tempCategory = categoryFilter;
    DateTime? tempStart = customStartDate;
    DateTime? tempEnd = customEndDate;
    final minController = TextEditingController(
      text: minAmountFilter?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: maxAmountFilter?.toString() ?? '',
    );
    final wallets = _walletOptions(transactionsNotifier.value);
    final categories = _categoryOptions(transactionsNotifier.value);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                    color: Theme.of(context).colorScheme.surface,
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
                    child: Column(
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
                          _i18n(context, id: 'Filter', en: 'Filter'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _i18n(
                            context,
                            id: 'Persempit riwayat agar lebih mudah dibaca.',
                            en: 'Narrow down history to make it easier to scan.',
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppUiTokens.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFilterSectionTitle(
                          _i18n(context, id: 'Periode', en: 'Period'),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSelectableChip(
                              _i18n(context, id: 'Semua', en: 'All'),
                              tempPeriod == 'all',
                              () => setModalState(() => tempPeriod = 'all'),
                            ),
                            _buildSelectableChip(
                              _i18n(context, id: 'Hari Ini', en: 'Today'),
                              tempPeriod == 'today',
                              () => setModalState(() => tempPeriod = 'today'),
                            ),
                            _buildSelectableChip(
                              _i18n(context, id: '7 Hari', en: '7 Days'),
                              tempPeriod == 'week',
                              () => setModalState(() => tempPeriod = 'week'),
                            ),
                            _buildSelectableChip(
                              _i18n(context, id: 'Bulan Ini', en: 'This Month'),
                              tempPeriod == 'this_month',
                              () => setModalState(
                                () => tempPeriod = 'this_month',
                              ),
                            ),
                            _buildSelectableChip(
                              _i18n(
                                context,
                                id: 'Siklus Tagihan',
                                en: 'Billing Cycle',
                              ),
                              tempPeriod == 'cycle',
                              () => setModalState(() => tempPeriod = 'cycle'),
                            ),
                            _buildSelectableChip(
                              t.t('this_year'),
                              tempPeriod == 'year',
                              () => setModalState(() => tempPeriod = 'year'),
                            ),
                            _buildSelectableChip(
                              _i18n(context, id: 'Kustom', en: 'Custom'),
                              tempPeriod == 'custom',
                              () => setModalState(() => tempPeriod = 'custom'),
                            ),
                          ],
                        ),
                        if (tempPeriod == 'custom') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          tempStart ??
                                          DateTime.now().subtract(
                                            const Duration(days: 30),
                                          ),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setModalState(
                                        () => tempStart = DateUtils.dateOnly(
                                          picked,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    tempStart == null
                                        ? _i18n(
                                            context,
                                            id: 'Mulai',
                                            en: 'Start',
                                          )
                                        : _formatDate(tempStart!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: tempEnd ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setModalState(
                                        () => tempEnd = DateUtils.dateOnly(
                                          picked,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    tempEnd == null
                                        ? _i18n(
                                            context,
                                            id: 'Sampai',
                                            en: 'End',
                                          )
                                        : _formatDate(tempEnd!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        _buildFilterSectionTitle(
                          _i18n(context, id: 'Tipe', en: 'Type'),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSelectableChip(
                              _i18n(context, id: 'Semua', en: 'All'),
                              tempType == 'all',
                              () => setModalState(() => tempType = 'all'),
                            ),
                            _buildSelectableChip(
                              t.t('income'),
                              tempType == 'income',
                              () => setModalState(() => tempType = 'income'),
                            ),
                            _buildSelectableChip(
                              t.t('expense'),
                              tempType == 'expense',
                              () => setModalState(() => tempType = 'expense'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildFilterSectionTitle(
                          _i18n(context, id: 'Dompet', en: 'Wallet'),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: wallets.map((wallet) {
                            return _buildSelectableChip(
                              _walletLabel(t, wallet),
                              tempWallet == wallet,
                              () => setModalState(() => tempWallet = wallet),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        _buildFilterSectionTitle(
                          _i18n(context, id: 'Kategori', en: 'Category'),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((category) {
                            final label = category == 'all'
                                ? _i18n(context, id: 'Semua', en: 'All')
                                : _categoryLabel(t, category);
                            return _buildSelectableChip(
                              label,
                              tempCategory == category,
                              () =>
                                  setModalState(() => tempCategory = category),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        _buildFilterSectionTitle(
                          _i18n(context, id: 'Nominal', en: 'Amount'),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: _i18n(
                                    context,
                                    id: 'Minimum',
                                    en: 'Minimum',
                                  ),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: _i18n(
                                    context,
                                    id: 'Maksimum',
                                    en: 'Maximum',
                                  ),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    periodFilter = 'all';
                                    typeFilter = 'all';
                                    walletFilter = 'all';
                                    categoryFilter = 'all';
                                    minAmountFilter = null;
                                    maxAmountFilter = null;
                                    customStartDate = null;
                                    customEndDate = null;
                                  });
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  _i18n(context, id: 'Reset', en: 'Reset'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final minParsed = int.tryParse(
                                    minController.text.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    ),
                                  );
                                  final maxParsed = int.tryParse(
                                    maxController.text.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    ),
                                  );
                                  if (minParsed != null &&
                                      maxParsed != null &&
                                      minParsed > maxParsed) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _i18n(
                                            context,
                                            id: 'Nominal minimum tidak boleh lebih besar dari maksimum.',
                                            en: 'Minimum amount cannot be greater than maximum.',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    periodFilter = tempPeriod;
                                    typeFilter = tempType;
                                    walletFilter = tempWallet;
                                    categoryFilter = tempCategory;
                                    minAmountFilter = minParsed;
                                    maxAmountFilter = maxParsed;
                                    customStartDate = tempStart;
                                    customEndDate = tempEnd;
                                  });
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  _i18n(context, id: 'Terapkan', en: 'Apply'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppUiTokens.textMuted,
        ),
      ),
    );
  }

  Widget _buildSelectableChip(String text, bool selected, VoidCallback onTap) {
    return PressableScale(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppUiTokens.surfaceBlueSoft, AppUiTokens.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : AppUiTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppUiTokens.brandBlueBorderStrong
                : AppUiTokens.borderSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                size: 12,
                color: AppUiTokens.brandBlueDark,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppUiTokens.brandBlueDark
                    : AppUiTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _activeFilterSummary(BuildContext context) {
    final parts = <String>[];
    if (periodFilter != 'all') {
      parts.add(
        _periodLabel(context, AppLocalizations.of(context), periodFilter),
      );
    }
    if (typeFilter != 'all') {
      parts.add(_typeLabel(context, AppLocalizations.of(context), typeFilter));
    }
    if (walletFilter != 'all') {
      parts.add(_walletLabel(AppLocalizations.of(context), walletFilter));
    }
    if (categoryFilter != 'all') {
      parts.add(_categoryLabel(AppLocalizations.of(context), categoryFilter));
    }
    if (minAmountFilter != null || maxAmountFilter != null) {
      parts.add(_i18n(context, id: 'Nominal', en: 'Amount'));
    }
    if (parts.isEmpty) {
      return _i18n(
        context,
        id: 'Semua filter nonaktif',
        en: 'All filters inactive',
      );
    }
    return parts.take(3).join(' • ');
  }

  List<TransactionRecord> _applyFilters(List<TransactionRecord> input) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
    final cycleRange = _cycleRange(
      now,
      AppSettingsScope.of(context).billingCycleStart,
    );
    return input.where((tx) {
      if (typeFilter == 'income' && tx.isExpense) {
        return false;
      }
      if (typeFilter == 'expense' && !tx.isExpense) {
        return false;
      }
      if (walletFilter != 'all' &&
          tx.wallet.toLowerCase() != walletFilter.toLowerCase()) {
        return false;
      }
      if (categoryFilter != 'all' &&
          tx.category.toLowerCase() != categoryFilter.toLowerCase()) {
        return false;
      }
      if (minAmountFilter != null && tx.amount < minAmountFilter!) {
        return false;
      }
      if (maxAmountFilter != null && tx.amount > maxAmountFilter!) {
        return false;
      }

      if (periodFilter == 'all') {
        return true;
      }
      if (periodFilter == 'today') {
        return DateUtils.dateOnly(tx.transactionDate) == today;
      }
      if (periodFilter == 'week') {
        return tx.transactionDate.isAfter(
          now.subtract(const Duration(days: 7)),
        );
      }
      if (periodFilter == 'this_month') {
        return !tx.transactionDate.isBefore(thisMonthStart) &&
            tx.transactionDate.isBefore(nextMonthStart);
      }
      if (periodFilter == 'cycle') {
        return !tx.transactionDate.isBefore(cycleRange.start) &&
            tx.transactionDate.isBefore(cycleRange.end);
      }
      if (periodFilter == 'year') {
        return tx.transactionDate.year == now.year;
      }
      if (periodFilter == 'custom') {
        if (customStartDate == null || customEndDate == null) {
          return true;
        }
        final start = DateUtils.dateOnly(customStartDate!);
        final end = DateUtils.dateOnly(
          customEndDate!,
        ).add(const Duration(days: 1));
        return !tx.transactionDate.isBefore(start) &&
            tx.transactionDate.isBefore(end);
      }
      return true;
    }).toList();
  }

  List<String> _walletOptions(List<TransactionRecord> txs) {
    final values = <String>{'all'};
    for (final tx in txs) {
      values.add(tx.wallet);
    }
    final items = values.where((e) => e != 'all').toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['all', ...items];
  }

  List<String> _categoryOptions(List<TransactionRecord> txs) {
    final values = <String>{'all'};
    for (final tx in txs) {
      values.add(tx.category);
    }
    final items = values.where((e) => e != 'all').toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['all', ...items];
  }

  String _periodLabel(BuildContext context, AppLocalizations t, String value) {
    switch (value) {
      case 'today':
        return _i18n(context, id: 'Hari Ini', en: 'Today');
      case 'week':
        return _i18n(context, id: '7 Hari', en: '7 Days');
      case 'this_month':
        return _i18n(context, id: 'Bulan Ini', en: 'This Month');
      case 'cycle':
        return _i18n(context, id: 'Siklus', en: 'Cycle');
      case 'year':
        return t.t('this_year');
      case 'custom':
        return _i18n(context, id: 'Kustom', en: 'Custom');
      default:
        return _i18n(context, id: 'Semua', en: 'All');
    }
  }

  String _typeLabel(BuildContext context, AppLocalizations t, String value) {
    switch (value) {
      case 'income':
        return t.t('income');
      case 'expense':
        return t.t('expense');
      default:
        return _i18n(context, id: 'Semua', en: 'All');
    }
  }

  String _walletLabel(AppLocalizations t, String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'all':
        return _i18nFromLocale(t.locale, id: 'Semua', en: 'All');
      case 'cash':
      case 'tunai':
        return t.t('wallet_cash');
      case 'bank':
        return t.t('wallet_bank');
      case 'ewallet':
      case 'e-wallet':
        return t.t('wallet_ewallet');
      case 'card':
      case 'kartu':
      case 'credit card':
      case 'kartu kredit':
        return t.t('wallet_card');
      default:
        return value;
    }
  }

  String _categoryLabel(AppLocalizations t, String key) {
    final normalized = key.trim().toLowerCase();
    switch (normalized) {
      case 'food':
      case 'makanan':
      case 'kuliner':
        return t.t('category_food');
      case 'transport':
      case 'transportasi':
        return t.t('category_transport');
      case 'bills':
      case 'tagihan':
        return t.t('category_bills');
      case 'shopping':
      case 'belanja':
        return t.t('category_shopping');
      case 'health':
      case 'kesehatan':
        return t.t('category_health');
      case 'education':
      case 'pendidikan':
        return t.t('category_education');
      case 'entertainment':
      case 'hiburan':
        return t.t('category_entertainment');
      default:
        return key;
    }
  }

  DateTimeRange _cycleRange(DateTime now, int cycleStartDay) {
    final normalizedDay = cycleStartDay.clamp(1, 31);
    final currentMonthStartDay = _safeDayInMonth(
      now.year,
      now.month,
      normalizedDay,
    );
    late DateTime start;
    late DateTime end;
    if (now.day >= currentMonthStartDay) {
      start = DateTime(now.year, now.month, currentMonthStartDay);
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nextStartDay = _safeDayInMonth(
        nextMonth.year,
        nextMonth.month,
        normalizedDay,
      );
      end = DateTime(nextMonth.year, nextMonth.month, nextStartDay);
    } else {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final prevStartDay = _safeDayInMonth(
        prevMonth.year,
        prevMonth.month,
        normalizedDay,
      );
      start = DateTime(prevMonth.year, prevMonth.month, prevStartDay);
      end = DateTime(now.year, now.month, currentMonthStartDay);
    }
    return DateTimeRange(start: start, end: end);
  }

  int _safeDayInMonth(int year, int month, int requestedDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return requestedDay.clamp(1, lastDay);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  int _totalBalance(List<TransactionRecord> txs) {
    var total = 0;
    for (final tx in txs) {
      total += tx.isExpense ? -tx.amount : tx.amount;
    }
    return total;
  }

  ({int income, int expense}) _cashflowTotals(List<TransactionRecord> txs) {
    var income = 0;
    var expense = 0;
    for (final tx in txs) {
      if (tx.isExpense) {
        expense += tx.amount;
      } else {
        income += tx.amount;
      }
    }
    return (income: income, expense: expense);
  }

  int _activeFilterCount() {
    var count = 0;
    if (periodFilter != 'all') count += 1;
    if (typeFilter != 'all') count += 1;
    if (walletFilter != 'all') count += 1;
    if (categoryFilter != 'all') count += 1;
    if (minAmountFilter != null || maxAmountFilter != null) count += 1;
    return count;
  }

  String _summaryLabel(BuildContext context, int count) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      return '$count transactions shown';
    }
    return '$count transaksi ditampilkan';
  }

  String _i18n(BuildContext context, {required String id, required String en}) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      return en;
    }
    return id;
  }

  String _i18nFromLocale(
    Locale locale, {
    required String id,
    required String en,
  }) {
    if (locale.languageCode == 'en') {
      return en;
    }
    return id;
  }
}
