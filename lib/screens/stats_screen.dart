import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/transaction_record.dart';
import '../data/recurring_bill_store.dart';
import '../data/transaction_store.dart';
import '../services/app_localizations.dart';
import '../services/app_animations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/due_date_service.dart';
import '../services/master_data_service.dart';
import '../services/notification_service.dart';
import '../widgets/category_budget_card.dart';
import 'home/home_formatters.dart';
import 'net_worth_screen.dart';
import 'home/transaction_search_delegate.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int selectedRangeIndex = 1;
  int budgetLimit = 1000000;
  int budgetThreshold = 80;
  bool _hasBudgetConfigured = false;
  DateTime? customStartDate;
  DateTime? customEndDate;

  @override
  void initState() {
    super.initState();
    _loadBudgetSettings();
    NotificationService.budgetSettingsVersion.addListener(_loadBudgetSettings);
  }

  @override
  void dispose() {
    NotificationService.budgetSettingsVersion.removeListener(
      _loadBudgetSettings,
    );
    super.dispose();
  }

  Future<void> _loadBudgetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hasBudgetConfigured = prefs.containsKey(
        NotificationService.keyBudgetLimit,
      );
      budgetLimit =
          prefs.getInt(NotificationService.keyBudgetLimit) ?? budgetLimit;
      budgetThreshold =
          prefs.getInt(NotificationService.keyBudgetThreshold) ??
          budgetThreshold;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    final ranges = [
      t.t('this_week'),
      t.t('this_month'),
      t.t('this_year'),
      t.t('custom'),
    ];

    return AnimatedBuilder(
      animation: Listenable.merge([
        transactionsNotifier,
        recurringBillsNotifier,
        NotificationService.budgetSettingsVersion,
        MasterDataService.instance,
      ]),
      builder: (context, _) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final compact = screenHeight < 760;
        final veryCompact = screenHeight < 700;
        final ultraCompact = screenHeight < 640;
        final narrowPhone = screenWidth < 420;
        final basePadding = ultraCompact
            ? AppUiTokens.space3
            : (compact ? 9.0 : AppUiTokens.space6);
        final gap = ultraCompact
            ? AppUiTokens.space2
            : (compact ? AppUiTokens.space3 : AppUiTokens.space4);
        final txs = transactionsNotifier.value;
        final bills = recurringBillsNotifier.value;
        final now = DateTime.now();
        final period = _buildPeriod(
          now: now,
          rangeIndex: selectedRangeIndex,
          customStartDate: customStartDate,
          customEndDate: customEndDate,
        );
        final summary = _summarize(txs, period);
        final trend = _build7DayTrend(txs, now);
        final topCategories = _topCategories(summary.expenseByCategory);
        final upcoming14 = _upcomingBillsAmount(bills, now, 14);
        final upcoming14Count = _upcomingBillsCount(bills, now, 14);
        final totalBalance =
            MasterDataService.instance.openingBalanceTotal + _totalBalance(txs);
        final riskRatio = _riskRatio(
          totalBalance: totalBalance,
          upcomingBillsAmount: upcoming14,
        );
        final drift = _categoryDrift(
          summary.expenseByCategory,
          summary.previousExpenseByCategory,
        );
        final maxTrend = _maxTrendValue(trend);

        final elapsedDays = now.difference(period.start).inDays + 1;
        final safeElapsedDays = elapsedDays.clamp(
          1,
          period.end.difference(period.start).inDays,
        );
        final burnRate = summary.expense ~/ safeElapsedDays;
        final runwayMonths = burnRate <= 0
            ? 0.0
            : (totalBalance / burnRate) / 30.0;
        final budgetSpent = _currentMonthExpense(txs, now);
        final budgetRawRatio = !_hasBudgetConfigured || budgetLimit <= 0
            ? 0.0
            : budgetSpent / budgetLimit;
        final budgetRatio = budgetRawRatio.clamp(0.0, 1.0);
        final txDeltaLabel = _deltaLabel(
          summary.totalTxCount,
          summary.previousTotalTxCount,
        );

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              t.t('finance_analytics'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 16 : AppUiTokens.textTitle,
              ),
            ),
            actions: [
              IconButton(
                tooltip: t.t('net_worth'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<Object?>(
                      builder: (_) => const NetWorthScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.insights_rounded),
              ),
              IconButton(
                onPressed: () {
                  showSearch<void>(
                    context: context,
                    delegate: TransactionSearchDelegate(
                      transactions: txs,
                      settings: settings,
                      t: t,
                      categoryLabel: homeCategoryLabel,
                    ),
                  );
                },
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          body: AnimatedFadeSlide(
            child: Padding(
              padding: EdgeInsets.all(basePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedTabReveal(
                    tabIndex: 1,
                    delay: const Duration(milliseconds: 20),
                    child: Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: List.generate(ranges.length, (index) {
                        final isSelected = selectedRangeIndex == index;
                        return PressableScale(
                          borderRadius: BorderRadius.circular(18),
                          pressedScale: 0.98,
                          onTap: () => _onRangeTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 10 : 12,
                              vertical: compact ? 6 : 7,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        AppUiTokens.brandBlueSoft,
                                        AppUiTokens.brandBlue,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSelected ? null : AppUiTokens.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? AppUiTokens.brandBlue
                                    : AppUiTokens.borderSoft,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppUiTokens.brandBlue.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              ranges[index],
                              style: TextStyle(
                                color: isSelected
                                    ? AppUiTokens.white
                                    : AppUiTokens.textBody,
                                fontSize: compact
                                    ? AppUiTokens.textXs
                                    : AppUiTokens.textSm,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  if (!ultraCompact &&
                      selectedRangeIndex == 3 &&
                      customStartDate != null &&
                      customEndDate != null) ...[
                    SizedBox(
                      height: compact ? AppUiTokens.space2 : AppUiTokens.space3,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 12,
                        vertical: compact ? 6 : 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppUiTokens.surfaceBlueSoft,
                            AppUiTokens.white,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppUiTokens.brandBlueBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            size: 14,
                            color: AppUiTokens.brandBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_formatDate(customStartDate!, t)} - ${_formatDate(customEndDate!, t)}',
                            style: TextStyle(
                              fontSize: compact
                                  ? AppUiTokens.textXs
                                  : AppUiTokens.textSm,
                              color: AppUiTokens.textNavy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: veryCompact ? 4 : gap),
                  AnimatedTabReveal(
                    tabIndex: 1,
                    delay: const Duration(milliseconds: 80),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            compact: compact,
                            title: t.t('total_expense'),
                            value: settings.formatCurrency(summary.expense),
                            delta: _deltaLabel(
                              summary.expense,
                              summary.previousExpense,
                            ),
                            icon: Icons.south_west_rounded,
                            color: AppUiTokens.danger,
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: _buildKpiCard(
                            compact: compact,
                            title: t.t('total_income'),
                            value: settings.formatCurrency(summary.income),
                            delta: _deltaLabel(
                              summary.income,
                              summary.previousIncome,
                            ),
                            icon: Icons.north_east_rounded,
                            color: AppUiTokens.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!veryCompact) ...[
                    SizedBox(
                      height: compact ? AppUiTokens.space2 : AppUiTokens.space3,
                    ),
                    AnimatedTabReveal(
                      tabIndex: 1,
                      delay: const Duration(milliseconds: 130),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMiniKpi(
                              t.t('net_balance'),
                              settings.formatBalanceCurrency(
                                summary.income - summary.expense,
                              ),
                              AppUiTokens.brandBlue,
                              compact: compact,
                            ),
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            child: _buildMiniKpi(
                              t.t('transactions'),
                              '${summary.totalTxCount} trx',
                              AppUiTokens.successDark,
                              compact: compact,
                            ),
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            child: _buildMiniKpi(
                              t.t('runway'),
                              '${runwayMonths.toStringAsFixed(1)} ${t.t('month_short')}',
                              AppUiTokens.brandBlue,
                              compact: compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    height: ultraCompact
                        ? 2
                        : (veryCompact ? 4 : (compact ? 4 : 6)),
                  ),
                  Expanded(
                    child: AnimatedTabReveal(
                      tabIndex: 1,
                      delay: const Duration(milliseconds: 190),
                      child: narrowPhone
                          ? Column(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Container(
                                    padding: EdgeInsets.all(compact ? 7 : 9),
                                    decoration: _cardDecoration(context),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            _buildLegendDot(
                                              AppUiTokens.danger,
                                              t.t('out'),
                                            ),
                                            SizedBox(width: gap),
                                            _buildLegendDot(
                                              AppUiTokens.success,
                                              t.t('in'),
                                            ),
                                            const Spacer(),
                                            Text(
                                              t.t('days_7'),
                                              style: TextStyle(
                                                fontSize: compact ? 9 : 10,
                                                color: AppUiTokens.textMuted,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: compact ? 5 : 7),
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: List.generate(
                                              trend.income.length,
                                              (index) {
                                                return Expanded(
                                                  child: _buildTrendBar(
                                                    compact: compact,
                                                    day: _dayLabel(index, t, now),
                                                    expense: trend
                                                        .expense[index]
                                                        .toDouble(),
                                                    income: trend.income[index]
                                                        .toDouble(),
                                                    maxValue: maxTrend
                                                        .toDouble(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: gap),
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            compact ? 7 : 9,
                                          ),
                                          decoration: _cardDecoration(context),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _txt(
                                                  t,
                                                  id: 'Top Kategori',
                                                  en: 'Top Categories',
                                                ),
                                                style: TextStyle(
                                                  fontSize: compact
                                                      ? 10.5
                                                      : 11.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              SizedBox(height: compact ? 5 : 7),
                                              Expanded(
                                                child: topCategories.isEmpty
                                                    ? Text(
                                                        _txt(
                                                          t,
                                                          id: 'Belum ada data kategori',
                                                          en: 'No category data yet',
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: compact
                                                              ? 9.5
                                                              : 10.5,
                                                          color: AppUiTokens
                                                              .textMuted,
                                                        ),
                                                      )
                                                    : Column(
                                                        children: topCategories.take(2).map((
                                                          item,
                                                        ) {
                                                          final ratio =
                                                              summary.expense <=
                                                                  0
                                                              ? 0.0
                                                              : item.value /
                                                                    summary
                                                                        .expense;
                                                          return Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                  bottom:
                                                                      compact
                                                                      ? 5
                                                                      : 7,
                                                                ),
                                                            child: _buildStatRow(
                                                              compact: compact,
                                                              label:
                                                                  _categoryLabel(
                                                                    item.key,
                                                                    t,
                                                                  ),
                                                              amount: settings
                                                                  .formatCurrency(
                                                                    item.value,
                                                                  ),
                                                              percentage: ratio
                                                                  .clamp(
                                                                    0.0,
                                                                    1.0,
                                                                  ),
                                                              color:
                                                                  _categoryColor(
                                                                    item.key,
                                                                  ),
                                                              trxCount:
                                                                  '${_categoryCount(summary.expenseByCategoryCount[item.key] ?? 0)} trx',
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: gap),
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            compact ? 7 : 9,
                                          ),
                                          decoration: _cardDecoration(context),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (_hasBudgetConfigured) ...[
                                                Text(
                                                  '${t.t('budget_limit')} ${settings.formatCurrency(budgetLimit)}',
                                                  style: TextStyle(
                                                    fontSize: compact ? 10 : 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: compact ? 5 : 7,
                                                ),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: LinearProgressIndicator(
                                                    value: budgetRatio,
                                                    minHeight: compact ? 6 : 7,
                                                    backgroundColor:
                                                        AppUiTokens.borderSoft,
                                                    color:
                                                        budgetRatio >=
                                                            (budgetThreshold /
                                                                100)
                                                        ? AppUiTokens.danger
                                                        : AppUiTokens.success,
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: compact ? 5 : 7,
                                                ),
                                              ],
                                              Text(
                                                '${_txt(t, id: 'Tagihan 14 hari', en: 'Bills in 14 days')}: $upcoming14Count',
                                                style: TextStyle(
                                                  fontSize: compact ? 9 : 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: compact ? 2 : 3),
                                              Text(
                                                settings.formatCurrency(
                                                  upcoming14,
                                                ),
                                                style: TextStyle(
                                                  fontSize: compact ? 10 : 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppUiTokens.textNavy,
                                                ),
                                              ),
                                              SizedBox(height: compact ? 2 : 3),
                                              Text(
                                                'Tx trend: $txDeltaLabel',
                                                style: TextStyle(
                                                  fontSize: compact ? 8.8 : 9.8,
                                                  color: AppUiTokens.textNavy,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: compact ? 2 : 3),
                                              Text(
                                                _riskLabel(riskRatio),
                                                style: TextStyle(
                                                  fontSize: compact ? 8.5 : 9.5,
                                                  color: _riskColor(riskRatio),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const Spacer(),
                                              GestureDetector(
                                                onTap: () => showCategoryBudgetSheet(context),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppUiTokens.surfaceBlueSoft,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppUiTokens.brandBlueBorder),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.pie_chart_rounded, size: 10, color: AppUiTokens.brandBlue),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        t.t('category_budget'),
                                                        style: TextStyle(
                                                          fontSize: compact ? 8 : 9,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppUiTokens.brandBlue,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Container(
                                    padding: EdgeInsets.all(compact ? 6 : 8),
                                    decoration: _cardDecoration(context),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            _buildLegendDot(
                                              AppUiTokens.danger,
                                              t.t('out'),
                                            ),
                                            SizedBox(width: gap),
                                            _buildLegendDot(
                                              AppUiTokens.success,
                                              t.t('in'),
                                            ),
                                            const Spacer(),
                                            Text(
                                              t.t('days_7'),
                                              style: TextStyle(
                                                fontSize: compact ? 8 : 9,
                                                color: AppUiTokens.textMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: compact ? 4 : 6),
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: List.generate(
                                              trend.income.length,
                                              (index) {
                                                return Expanded(
                                                  child: _buildTrendBar(
                                                    compact: compact,
                                                    day: _dayLabel(index, t, now),
                                                    expense: trend
                                                        .expense[index]
                                                        .toDouble(),
                                                    income: trend.income[index]
                                                        .toDouble(),
                                                    maxValue: maxTrend
                                                        .toDouble(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: gap),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            compact ? 6 : 8,
                                          ),
                                          decoration: _cardDecoration(context),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _txt(
                                                  t,
                                                  id: 'Top Kategori',
                                                  en: 'Top Categories',
                                                ),
                                                style: TextStyle(
                                                  fontSize: compact
                                                      ? 9.5
                                                      : 10.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: compact ? 4 : 6),
                                              Expanded(
                                                child: topCategories.isEmpty
                                                    ? Text(
                                                        _txt(
                                                          t,
                                                          id: 'Belum ada data kategori',
                                                          en: 'No category data yet',
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: compact
                                                              ? 9
                                                              : 10,
                                                          color: AppUiTokens
                                                              .textMuted,
                                                        ),
                                                      )
                                                    : Column(
                                                        children: topCategories.take(compact ? 2 : 3).map((
                                                          item,
                                                        ) {
                                                          final ratio =
                                                              summary.expense <=
                                                                  0
                                                              ? 0.0
                                                              : item.value /
                                                                    summary
                                                                        .expense;
                                                          return Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                  bottom:
                                                                      compact
                                                                      ? 4
                                                                      : 6,
                                                                ),
                                                            child: _buildStatRow(
                                                              compact: compact,
                                                              label:
                                                                  _categoryLabel(
                                                                    item.key,
                                                                    t,
                                                                  ),
                                                              amount: settings
                                                                  .formatCurrency(
                                                                    item.value,
                                                                  ),
                                                              percentage: ratio
                                                                  .clamp(
                                                                    0.0,
                                                                    1.0,
                                                                  ),
                                                              color:
                                                                  _categoryColor(
                                                                    item.key,
                                                                  ),
                                                              trxCount:
                                                                  '${_categoryCount(summary.expenseByCategoryCount[item.key] ?? 0)} trx',
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                              ),
                                              Text(
                                                drift == null
                                                    ? _txt(
                                                        t,
                                                        id: 'Belum ada perubahan kategori',
                                                        en: 'No category drift yet',
                                                      )
                                                    : '${_categoryLabel(drift.key, t)} +${settings.formatCurrency(drift.value)}',
                                                style: TextStyle(
                                                  fontSize: compact ? 8.5 : 9.5,
                                                  color: AppUiTokens.textNavy,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: gap),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(
                                            compact ? 6 : 8,
                                          ),
                                          decoration: _cardDecoration(context),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (_hasBudgetConfigured) ...[
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      '${t.t('budget_limit')} ${settings.formatCurrency(budgetLimit)}',
                                                      style: TextStyle(
                                                        fontSize: compact
                                                            ? 9
                                                            : 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${(budgetRawRatio * 100).toStringAsFixed(0)}%',
                                                      style: TextStyle(
                                                        fontSize: compact
                                                            ? 9
                                                            : 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            budgetRatio >=
                                                                (budgetThreshold /
                                                                    100)
                                                            ? AppUiTokens
                                                                  .dangerDeep
                                                            : AppUiTokens
                                                                  .successDeep,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(
                                                  height: compact ? 4 : 5,
                                                ),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: LinearProgressIndicator(
                                                    value: budgetRatio,
                                                    minHeight: compact ? 5 : 6,
                                                    backgroundColor:
                                                        AppUiTokens.borderSoft,
                                                    color:
                                                        budgetRatio >=
                                                            (budgetThreshold /
                                                                100)
                                                        ? AppUiTokens.danger
                                                        : AppUiTokens.success,
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: compact ? 4 : 5,
                                                ),
                                              ],
                                              Text(
                                                '${_txt(t, id: 'Tagihan 14 hari', en: 'Bills in 14 days')}: $upcoming14Count (${settings.formatCurrency(upcoming14)})',
                                                style: TextStyle(
                                                  fontSize: compact ? 8.5 : 9.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: compact ? 1 : 2),
                                              Text(
                                                'Tx trend: $txDeltaLabel',
                                                style: TextStyle(
                                                  fontSize: compact ? 8.5 : 9.5,
                                                  color: AppUiTokens.textNavy,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: compact ? 1 : 2),
                                              Text(
                                                _riskLabel(riskRatio),
                                                style: TextStyle(
                                                  fontSize: compact ? 8.5 : 9.5,
                                                  color: _riskColor(riskRatio),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: compact ? 1 : 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const Spacer(),
                                              GestureDetector(
                                                onTap: () => showCategoryBudgetSheet(context),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppUiTokens.surfaceBlueSoft,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppUiTokens.brandBlueBorder),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.pie_chart_rounded, size: 10, color: AppUiTokens.brandBlue),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        t.t('category_budget'),
                                                        style: TextStyle(
                                                          fontSize: compact ? 8 : 9,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppUiTokens.brandBlue,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onRangeTap(int index) async {
    if (index != 3) {
      setState(() => selectedRangeIndex = index);
      return;
    }

    final now = DateTime.now();
    final initialStart =
        customStartDate ?? DateTime(now.year, now.month, now.day - 29);
    final initialEnd = customEndDate ?? DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: AppUiTokens.brandBlue),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      selectedRangeIndex = 3;
      customStartDate = DateUtils.dateOnly(picked.start);
      customEndDate = DateUtils.dateOnly(picked.end);
    });
  }

  _Period _buildPeriod({
    required DateTime now,
    required int rangeIndex,
    required DateTime? customStartDate,
    required DateTime? customEndDate,
  }) {
    final today = DateTime(now.year, now.month, now.day + 1);
    switch (rangeIndex) {
      case 0:
        final weekStart = DateUtils.dateOnly(
          now,
        ).subtract(Duration(days: now.weekday - 1));
        final start = weekStart;
        final end = weekStart.add(const Duration(days: 7));
        final prevStart = weekStart.subtract(const Duration(days: 7));
        return _Period(
          start: start,
          end: end,
          previousStart: prevStart,
          previousEnd: _sameElapsedPreviousEnd(
            start: start,
            end: end,
            previousStart: prevStart,
            now: now,
          ),
        );
      case 1:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        final previousStart = DateTime(now.year, now.month - 1, 1);
        return _Period(
          start: start,
          end: end,
          previousStart: previousStart,
          previousEnd: _sameElapsedPreviousEnd(
            start: start,
            end: end,
            previousStart: previousStart,
            now: now,
          ),
        );
      case 2:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1);
        final previousStart = DateTime(now.year - 1, 1, 1);
        return _Period(
          start: start,
          end: end,
          previousStart: previousStart,
          previousEnd: _sameElapsedPreviousEnd(
            start: start,
            end: end,
            previousStart: previousStart,
            now: now,
          ),
        );
      default:
        final customStart =
            customStartDate ?? today.subtract(const Duration(days: 30));
        final customEndExclusive = (customEndDate ?? DateUtils.dateOnly(now))
            .add(const Duration(days: 1));
        final rangeDays = customEndExclusive
            .difference(customStart)
            .inDays
            .clamp(1, 3650);
        final previousStart = customStart.subtract(Duration(days: rangeDays));
        return _Period(
          start: customStart,
          end: customEndExclusive,
          previousStart: previousStart,
          previousEnd: customStart,
        );
    }
  }

  /// Aligns the previous comparison window to the elapsed length of the
  /// current period so a partial month is never compared to a full one.
  DateTime _sameElapsedPreviousEnd({
    required DateTime start,
    required DateTime end,
    required DateTime previousStart,
    required DateTime now,
  }) {
    final reference = now.isBefore(end) ? now : end;
    var elapsed = reference.difference(start);
    if (elapsed.isNegative) elapsed = Duration.zero;
    final candidate = previousStart.add(elapsed);
    return candidate.isAfter(start) ? start : candidate;
  }

  _Summary _summarize(List<TransactionRecord> txs, _Period period) {
    var income = 0;
    var expense = 0;
    var previousIncome = 0;
    var previousExpense = 0;
    var incomeTxCount = 0;
    var expenseTxCount = 0;
    var previousIncomeTxCount = 0;
    var previousExpenseTxCount = 0;
    final expenseByCategory = <String, int>{};
    final previousExpenseByCategory = <String, int>{};
    final expenseByCategoryCount = <String, int>{};

    for (final tx in txs) {
      final date = tx.transactionDate;
      final isTransfer =
          tx.category == 'transfer_out' || tx.category == 'transfer_in';
      if (!date.isBefore(period.start) && date.isBefore(period.end)) {
        if (isTransfer) {
          // Transfers are internal movements, not real income/expense.
        } else if (tx.isExpense) {
          expense += tx.amount;
          expenseTxCount += 1;
          expenseByCategory[tx.category] =
              (expenseByCategory[tx.category] ?? 0) + tx.amount;
          expenseByCategoryCount[tx.category] =
              (expenseByCategoryCount[tx.category] ?? 0) + 1;
        } else {
          income += tx.amount;
          incomeTxCount += 1;
        }
      } else if (!date.isBefore(period.previousStart) &&
          date.isBefore(period.previousEnd)) {
        if (isTransfer) {
          // Skip transfers in previous period too.
        } else if (tx.isExpense) {
          previousExpense += tx.amount;
          previousExpenseTxCount += 1;
          previousExpenseByCategory[tx.category] =
              (previousExpenseByCategory[tx.category] ?? 0) + tx.amount;
        } else {
          previousIncome += tx.amount;
          previousIncomeTxCount += 1;
        }
      }
    }

    return _Summary(
      income: income,
      expense: expense,
      previousIncome: previousIncome,
      previousExpense: previousExpense,
      incomeTxCount: incomeTxCount,
      expenseTxCount: expenseTxCount,
      previousIncomeTxCount: previousIncomeTxCount,
      previousExpenseTxCount: previousExpenseTxCount,
      expenseByCategory: expenseByCategory,
      previousExpenseByCategory: previousExpenseByCategory,
      expenseByCategoryCount: expenseByCategoryCount,
    );
  }

  _Trend _build7DayTrend(List<TransactionRecord> txs, DateTime now) {
    final income = List<int>.filled(7, 0);
    final expense = List<int>.filled(7, 0);
    final today = DateUtils.dateOnly(now);
    for (final tx in txs) {
      final day = DateUtils.dateOnly(tx.transactionDate);
      final diff = today.difference(day).inDays;
      if (diff < 0 || diff > 6) continue;
      if (tx.category == 'transfer_out' || tx.category == 'transfer_in') {
        continue;
      }
      final idx = 6 - diff;
      if (tx.isExpense) {
        expense[idx] += tx.amount;
      } else {
        income[idx] += tx.amount;
      }
    }
    return _Trend(income: income, expense: expense);
  }

  int _upcomingBillsAmount(List<RecurringBill> bills, DateTime now, int days) {
    var total = 0;
    for (final bill in bills) {
      final diff = DueDateService.daysUntilDueDate(
        from: now,
        dueDay: bill.dueDay,
      );
      if (diff <= days) {
        total += bill.amount;
      }
    }
    return total;
  }

  int _upcomingBillsCount(List<RecurringBill> bills, DateTime now, int days) {
    var total = 0;
    for (final bill in bills) {
      final diff = DueDateService.daysUntilDueDate(
        from: now,
        dueDay: bill.dueDay,
      );
      if (diff <= days) {
        total += 1;
      }
    }
    return total;
  }

  int _totalBalance(List<TransactionRecord> txs) {
    var total = 0;
    for (final tx in txs) {
      total += tx.isExpense ? -tx.amount : tx.amount;
    }
    return total;
  }

  int _currentMonthExpense(List<TransactionRecord> txs, DateTime now) {
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    var total = 0;
    for (final tx in txs) {
      if (!tx.isExpense) continue;
      if (tx.category == 'transfer_out' || tx.category == 'transfer_in') {
        continue;
      }
      final date = tx.transactionDate;
      if (date.isBefore(start) || !date.isBefore(end)) continue;
      total += tx.amount;
    }
    return total;
  }

  List<MapEntry<String, int>> _topCategories(Map<String, int> map) {
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(4).toList();
  }

  MapEntry<String, int>? _categoryDrift(
    Map<String, int> current,
    Map<String, int> previous,
  ) {
    String? bestKey;
    var bestIncrease = 0;
    for (final entry in current.entries) {
      final prev = previous[entry.key] ?? 0;
      final increase = entry.value - prev;
      if (increase > bestIncrease) {
        bestIncrease = increase;
        bestKey = entry.key;
      }
    }
    if (bestKey == null || bestIncrease <= 0) return null;
    return MapEntry(bestKey, bestIncrease);
  }

  String _deltaLabel(int current, int previous) {
    if (previous <= 0) return current <= 0 ? '0%' : '—';
    final delta = ((current - previous) / previous) * 100;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(0)}%';
  }

  double _riskRatio({
    required int totalBalance,
    required int upcomingBillsAmount,
  }) {
    if (upcomingBillsAmount <= 0) return 0.0;
    if (totalBalance <= 0) return 1.0;
    return upcomingBillsAmount / totalBalance;
  }

  String _riskLabel(double ratio) {
    final t = AppLocalizations.of(context);
    if (ratio >= 0.6) {
      return _txt(
        t,
        id: 'Tagihan 14 hari ke depan sudah memakai lebih dari 60% saldo',
        en: 'Bills in the next 14 days already use more than 60% of balance',
      );
    }
    if (ratio >= 0.3) {
      return _txt(
        t,
        id: 'Tagihan 14 hari ke depan sudah memakai lebih dari 30% saldo',
        en: 'Bills in the next 14 days already use more than 30% of balance',
      );
    }
    return _txt(
      t,
      id: 'Tagihan 14 hari ke depan masih aman terhadap saldo',
      en: 'Bills in the next 14 days are still safe relative to balance',
    );
  }

  Color _riskColor(double ratio) {
    if (ratio >= 0.6) return AppUiTokens.dangerDeep;
    if (ratio >= 0.3) return AppUiTokens.warningMedium;
    return AppUiTokens.successDeep;
  }

  String _categoryLabel(String key, AppLocalizations t) {
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
      case 'others':
        return t.t('category_others');
      case 'salary':
        return t.t('category_salary');
      case 'freelance':
        return t.t('category_freelance');
      case 'bonus':
        return t.t('category_bonus');
      case 'business':
        return t.t('category_business');
      case 'investment':
        return t.t('category_investment');
      case 'gift':
        return t.t('category_gift');
      default:
        return key;
    }
  }

  Color _categoryColor(String key) {
    final normalized = key.trim().toLowerCase();
    switch (normalized) {
      case 'food':
      case 'makanan':
      case 'kuliner':
        return AppUiTokens.warning;
      case 'transport':
      case 'transportasi':
        return AppUiTokens.blueAccent;
      case 'bills':
      case 'tagihan':
        return AppUiTokens.brandBlueSoft;
      case 'shopping':
      case 'belanja':
        return AppUiTokens.pinkAccent;
      default:
        return AppUiTokens.textHint;
    }
  }

  String _categoryCount(int value) => value.toString();

  String _formatDate(DateTime date, AppLocalizations t) {
    final monthNames = t.locale.languageCode == 'en'
        ? const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ]
        : const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'Mei',
            'Jun',
            'Jul',
            'Agu',
            'Sep',
            'Okt',
            'Nov',
            'Des',
          ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppUiTokens.borderSoft),
      boxShadow: [
        BoxShadow(
          color: AppUiTokens.black.withValues(alpha: 0.035),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  String _dayLabel(int i, AppLocalizations t, DateTime now) {
    final days = t.locale.languageCode == 'en'
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final day = DateUtils.dateOnly(now).subtract(Duration(days: 6 - i));
    return days[(day.weekday - 1) % days.length];
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppUiTokens.textDarkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required bool compact,
    required String title,
    required String value,
    required String delta,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 9 : 12),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  delta,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 11.5 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 1 : 2),
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              color: AppUiTokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpi(
    String title,
    String value,
    Color color, {
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    color: AppUiTokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: compact ? 1 : 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBar({
    required bool compact,
    required String day,
    required double expense,
    required double income,
    required double maxValue,
  }) {
    final expenseRatio = (expense / maxValue).clamp(0.0, 1.0);
    final incomeRatio = (income / maxValue).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: compact ? 7 : 8,
                    height: (compact ? 70 : 90) * expenseRatio,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppUiTokens.danger, AppUiTokens.dangerDeep],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: compact ? 7 : 8,
                    height: (compact ? 70 : 90) * incomeRatio,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppUiTokens.success, AppUiTokens.successDeep],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            day,
            style: TextStyle(
              fontSize: compact ? 7.5 : 8.5,
              color: AppUiTokens.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required bool compact,
    required String label,
    required String amount,
    required double percentage,
    required Color color,
    required String trxCount,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 10 : 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  trxCount,
                  style: TextStyle(
                    fontSize: compact ? 7.5 : 8.5,
                    color: AppUiTokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: compact ? 4 : 5,
            backgroundColor: AppUiTokens.borderSoft,
            color: color,
          ),
        ),
        SizedBox(height: compact ? 3 : 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${(percentage * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              color: AppUiTokens.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  int _maxTrendValue(_Trend trend) {
    var maxVal = 1;
    for (final value in trend.income) {
      if (value > maxVal) maxVal = value;
    }
    for (final value in trend.expense) {
      if (value > maxVal) maxVal = value;
    }
    return maxVal;
  }

  String _txt(AppLocalizations t, {required String id, required String en}) {
    if (t.locale.languageCode == 'en') return en;
    return id;
  }
}

class _Period {
  const _Period({
    required this.start,
    required this.end,
    required this.previousStart,
    required this.previousEnd,
  });

  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final DateTime previousEnd;
}

class _Summary {
  const _Summary({
    required this.income,
    required this.expense,
    required this.previousIncome,
    required this.previousExpense,
    required this.incomeTxCount,
    required this.expenseTxCount,
    required this.previousIncomeTxCount,
    required this.previousExpenseTxCount,
    required this.expenseByCategory,
    required this.previousExpenseByCategory,
    required this.expenseByCategoryCount,
  });

  final int income;
  final int expense;
  final int previousIncome;
  final int previousExpense;
  final int incomeTxCount;
  final int expenseTxCount;
  final int previousIncomeTxCount;
  final int previousExpenseTxCount;
  final Map<String, int> expenseByCategory;
  final Map<String, int> previousExpenseByCategory;
  final Map<String, int> expenseByCategoryCount;

  int get totalTxCount => incomeTxCount + expenseTxCount;
  int get previousTotalTxCount =>
      previousIncomeTxCount + previousExpenseTxCount;
}

class _Trend {
  const _Trend({required this.income, required this.expense});

  final List<int> income;
  final List<int> expense;
}
