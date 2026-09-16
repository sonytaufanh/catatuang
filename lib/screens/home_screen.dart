import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/transaction_record.dart';
import '../data/recurring_bill_store.dart';
import '../data/transaction_store.dart';
import '../services/app_localizations.dart';
import '../services/app_animations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/ai_insight_engine.dart';
import '../services/analytics_service.dart';
import '../services/due_date_service.dart';
import '../services/master_data_service.dart';
import '../services/notification_service.dart';
import '../services/savings_goal_service.dart';
import '../services/thousand_separator_formatter.dart';
import '../services/user_profile_service.dart';
import 'add_transaction_screen.dart';
import 'ai_chat_screen.dart';
import '../widgets/forecast_card.dart';
import 'home/home_formatters.dart';
import 'home/home_models.dart';
import 'home/transaction_search_delegate.dart';

bool _homeOnboardingCompletionTrackQueued = false;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final compact = screenHeight < 980;
    final veryCompact = screenHeight < 860;
    final ultraCompact = screenHeight < 760;

    return AnimatedBuilder(
      animation: Listenable.merge([
        transactionsNotifier,
        recurringBillsNotifier,
        UserProfileService.instance,
        MasterDataService.instance,
        SavingsGoalService.instance.notifier,
      ]),
      builder: (context, _) {
        SavingsGoalService.instance.ensureLoaded();
        final profile = UserProfileService.instance;
        final transactions = transactionsNotifier.value;
        final bills = recurringBillsNotifier.value;
        final now = DateTime.now();
        final summary = _buildSummary(
          transactions: transactions,
          cycleStartDay: settings.billingCycleStart,
          now: now,
        );
        final topCategories = _topCategories(summary.cycleExpensesByCategory);
        if (transactions.isNotEmpty &&
            bills.isNotEmpty &&
            !_homeOnboardingCompletionTrackQueued &&
            _currentStreakDays(transactions) >= 3) {
          _homeOnboardingCompletionTrackQueued = true;
          Future<void>.microtask(() async {
            await AnalyticsService.instance.trackOnce(
              onceKey: 'onboarding_complete_v1',
              name: 'onboarding_complete',
            );
          });
        }
        final dueSoonCount = bills.where((bill) {
          final dayDiff = DueDateService.daysUntilDueDate(
            from: now,
            dueDay: bill.dueDay,
          );
          return dayDiff <= 3;
        }).length;

        final greeting = settings.languageCode == 'en'
            ? 'Hi, ${profile.displayName}'
            : 'Halo, ${profile.displayName}';

        return SafeArea(
          child: AnimatedFadeSlide(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 11.0 : AppUiTokens.space8,
                vertical: compact ? AppUiTokens.space3 : AppUiTokens.space6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedTabReveal(
                    tabIndex: 0,
                    delay: const Duration(milliseconds: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppUiTokens.brandBlueSoft,
                              child: Text(
                                _profileInitials(
                                  profile.displayName,
                                  profile.email,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppUiTokens.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppUiTokens.space5),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  greeting,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: AppUiTokens.textXl,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  t.t('financial_dashboard'),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: AppUiTokens.textXs,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            PressableScale(
                              borderRadius: BorderRadius.circular(99),
                              pressedScale: 0.9,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AiChatScreen(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    gradient: AppUiTokens.brandGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppUiTokens.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PressableScale(
                              borderRadius: BorderRadius.circular(99),
                              pressedScale: 0.9,
                              onTap: () {
                                showSearch<void>(
                                  context: context,
                                  delegate: TransactionSearchDelegate(
                                    transactions: transactions,
                                    settings: settings,
                                    t: t,
                                    categoryLabel: homeCategoryLabel,
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.search,
                                  color: AppUiTokens.black54,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            PressableScale(
                              borderRadius: BorderRadius.circular(99),
                              pressedScale: 0.9,
                              onTap: () => _showNotificationCenter(
                                context: context,
                                transactions: transactions,
                                bills: bills,
                                settings: settings,
                                t: t,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Badge(
                                  isLabelVisible: dueSoonCount > 0,
                                  smallSize: 8,
                                  backgroundColor: AppUiTokens.danger,
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: AppUiTokens.black54,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: compact ? AppUiTokens.space4 : AppUiTokens.space8,
                  ),
                  AnimatedTabReveal(
                    tabIndex: 0,
                    delay: const Duration(milliseconds: 70),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 12 : 16),
                      decoration: BoxDecoration(
                        gradient: AppUiTokens.brandGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppUiTokens.brandBlue.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
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
                                t.t('total_balance'),
                                style: const TextStyle(
                                  color: AppUiTokens.white70,
                                  fontSize: AppUiTokens.textMd,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.auto_graph_rounded,
                                color: AppUiTokens.white.withValues(alpha: 0.8),
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppUiTokens.space2),
                          Text(
                            settings.formatBalanceCurrency(
                              summary.totalBalance,
                            ),
                            style: TextStyle(
                              color: AppUiTokens.white,
                              fontSize: compact ? AppUiTokens.textDisplay : 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(
                            height: compact
                                ? AppUiTokens.space5
                                : AppUiTokens.space8,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniStat(
                                  Icons.arrow_downward,
                                  t.t('income_this_cycle'),
                                  settings.formatCurrency(
                                    summary.incomeThisCycle,
                                  ),
                                  AppUiTokens.success,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 24,
                                color: AppUiTokens.white.withValues(alpha: 0.2),
                              ),
                              Expanded(
                                child: _buildMiniStat(
                                  Icons.arrow_upward,
                                  t.t('expense_this_cycle'),
                                  settings.formatCurrency(
                                    summary.expenseThisCycle,
                                  ),
                                  AppUiTokens.danger,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: compact ? AppUiTokens.space3 : AppUiTokens.space5,
                  ),
                  _buildSavingsGoalCard(
                    context: context,
                    settings: settings,
                    t: t,
                    totalBalance: summary.totalBalance,
                    compact: compact,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: compact ? AppUiTokens.space3 : AppUiTokens.space4,
                    ),
                    child: ForecastCard(compact: compact),
                  ),
                  _buildAiInsightsCard(
                    context: context,
                    transactions: transactions,
                    totalBalance: summary.totalBalance,
                    settings: settings,
                    t: t,
                    compact: compact,
                  ),
                  AnimatedTabReveal(
                    tabIndex: 0,
                    delay: const Duration(milliseconds: 120),
                    child: _buildQuickAddBar(
                      context,
                      compact: compact || ultraCompact,
                    ),
                  ),
                  SizedBox(
                    height: compact ? AppUiTokens.space3 : AppUiTokens.space6,
                  ),
                  AnimatedTabReveal(
                    tabIndex: 0,
                    delay: const Duration(milliseconds: 160),
                    child: _buildRecurringBillsCard(context),
                  ),
                  SizedBox(
                    height: veryCompact
                        ? 0
                        : (ultraCompact
                              ? AppUiTokens.space2
                              : AppUiTokens.space4),
                  ),
                  Expanded(
                    child: AnimatedTabReveal(
                      tabIndex: 0,
                      delay: const Duration(milliseconds: 210),
                      child: _buildAdvancedAnalytics(
                        context: context,
                        summary: summary,
                        topCategories: topCategories,
                        transactions: transactions,
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

  Widget _buildMiniStat(
    IconData icon,
    String label,
    String amount,
    Color iconColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppUiTokens.white.withValues(alpha: 0.6),
                fontSize: AppUiTokens.textXs,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                color: AppUiTokens.white,
                fontSize: AppUiTokens.textLg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecurringBillsCard(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    return ValueListenableBuilder<List<RecurringBill>>(
      valueListenable: recurringBillsNotifier,
      builder: (context, bills, _) {
        final now = DateTime.now();
        final sorted = [...bills]
          ..sort((a, b) {
            final aDelta = DueDateService.daysUntilDueDate(
              from: now,
              dueDay: a.dueDay,
            );
            final bDelta = DueDateService.daysUntilDueDate(
              from: now,
              dueDay: b.dueDay,
            );
            return aDelta.compareTo(bDelta);
          });
        final visible = sorted.take(2).toList();
        final hiddenCount = sorted.length - visible.length;

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
              AnimatedTabReveal(
                tabIndex: 0,
                delay: const Duration(milliseconds: 180),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.t('monthly_bills'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${sorted.length} ${t.t('item_count')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppUiTokens.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: () => _showRecurringBillForm(context: context),
                          child: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 17,
                            color: AppUiTokens.brandBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                AnimatedTabReveal(
                  tabIndex: 0,
                  delay: const Duration(milliseconds: 220),
                  child: Text(
                    t.t('no_bills'),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppUiTokens.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ...visible.asMap().entries.map((entry) {
                  final bill = entry.value;
                  final dayDiff = DueDateService.daysUntilDueDate(
                    from: now,
                    dueDay: bill.dueDay,
                  );
                  final dueLabel = dayDiff == 0
                      ? t.t('due_today')
                      : '$dayDiff ${t.t('due_in_days')}';
                  return AnimatedTabReveal(
                    tabIndex: 0,
                    delay: Duration(milliseconds: 220 + (entry.key * 45)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppUiTokens.brandBlueTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              size: 14,
                              color: AppUiTokens.brandBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${t.t('due_date')} ${bill.dueDay} ($dueLabel)',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppUiTokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            settings.formatCurrency(bill.amount),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppUiTokens.dangerDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (hiddenCount > 0)
                AnimatedTabReveal(
                  tabIndex: 0,
                  delay: Duration(milliseconds: 240 + (visible.length * 45)),
                  child: GestureDetector(
                    onTap: () => _showAllBillsSheet(context: context),
                    child: Text(
                      '+$hiddenCount ${t.t('more_bills')}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppUiTokens.brandBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavingsGoalCard({
    required BuildContext context,
    required AppSettings settings,
    required AppLocalizations t,
    required int totalBalance,
    required bool compact,
  }) {
    final goal = SavingsGoalService.instance.notifier.value;
    if (!goal.enabled) return const SizedBox.shrink();
    final progress = (totalBalance / goal.targetAmount).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    return AnimatedTabReveal(
      tabIndex: 0,
      delay: const Duration(milliseconds: 95),
      child: Padding(
        padding: EdgeInsets.only(bottom: compact ? AppUiTokens.space3 : AppUiTokens.space5),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppUiTokens.successDark.withValues(alpha: 0.08),
                AppUiTokens.brandBlueSoft.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppUiTokens.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.savings_rounded, size: 14, color: AppUiTokens.successDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      goal.label.isNotEmpty ? goal.label : t.t('savings_goal'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: percent >= 100 ? AppUiTokens.successDark : AppUiTokens.brandBlueDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppUiTokens.borderSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percent >= 100 ? AppUiTokens.successDark : AppUiTokens.brandBlue,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${settings.formatCurrency(totalBalance)} / ${settings.formatCurrency(goal.targetAmount)}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppUiTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiInsightsCard({
    required BuildContext context,
    required List<TransactionRecord> transactions,
    required int totalBalance,
    required AppSettings settings,
    required AppLocalizations t,
    required bool compact,
  }) {
    if (transactions.length < 5) return const SizedBox.shrink();

    final insights = AiInsightEngine.instance.generateInsights(
      transactions: transactions,
      totalBalance: totalBalance,
      cycleStartDay: settings.billingCycleStart,
      languageCode: settings.languageCode,
      currencySymbol: settings.currencySymbol,
    );

    if (insights.isEmpty) return const SizedBox.shrink();

    final insight = insights.first;
    final insightColor = switch (insight.type) {
      InsightType.positive => AppUiTokens.successDark,
      InsightType.warning => AppUiTokens.warningDark,
      InsightType.info => AppUiTokens.brandBlue,
      InsightType.tip => AppUiTokens.infoSoft,
    };
    final bgColor = switch (insight.type) {
      InsightType.positive => AppUiTokens.successSoft,
      InsightType.warning => AppUiTokens.warningSoft,
      InsightType.info => AppUiTokens.surfaceBlueSoft,
      InsightType.tip => AppUiTokens.surfaceTintBlue,
    };
    final borderColor = switch (insight.type) {
      InsightType.positive => AppUiTokens.successSoftBorder,
      InsightType.warning => AppUiTokens.warningSoftBorder,
      InsightType.info => AppUiTokens.brandBlueBorder,
      InsightType.tip => AppUiTokens.brandBlueBorder,
    };

    return AnimatedTabReveal(
      tabIndex: 0,
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: EdgeInsets.only(bottom: compact ? 6.0 : 8.0),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AiChatScreen(),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: insightColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: insightColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: insightColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        insight.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppUiTokens.textBody,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: insightColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddBar(BuildContext context, {required bool compact}) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () =>
                _openQuickAdd(context, isExpense: true, category: 'food'),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 14),
            label: Text(
              compact ? t.t('expense') : '${t.t('expense')} Cepat',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(34),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () =>
                _openQuickAdd(context, isExpense: false, category: 'salary'),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
            label: Text(
              compact ? t.t('income') : '${t.t('income')} Cepat',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(34),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openQuickAdd(
    BuildContext context, {
    required bool isExpense,
    required String category,
    String? wallet,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute<Object?>(
        builder: (_) => AddTransactionScreen(
          initialIsExpense: isExpense,
          initialCategory: category,
          initialWallet: wallet,
        ),
      ),
    );
    if (!context.mounted) return;
    showTransactionSaveResultSnack(
      context,
      result,
      fallbackIsExpense: isExpense,
    );
  }

  String _profileInitials(String displayName, String email) {
    final source = displayName.trim().isNotEmpty
        ? displayName.trim()
        : email.trim();
    if (source.isEmpty) return 'CU';
    final words = source
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'CU';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }

  Widget _buildAdvancedAnalytics({
    required BuildContext context,
    required HomeDashboardSummary summary,
    required List<MapEntry<String, int>> topCategories,
    required List<TransactionRecord> transactions,
  }) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final weeklyLabels = homeWeeklyLabels(t, now);
    final savingRatePercent = summary.incomeThisCycle <= 0
        ? 0
        : (((summary.incomeThisCycle - summary.expenseThisCycle) /
                      summary.incomeThisCycle) *
                  100)
              .round();
    final cycleDays = summary.cycleRange.duration.inDays;
    final elapsedDays = now.difference(summary.cycleRange.start).inDays + 1;
    final safeElapsedDays = elapsedDays.clamp(1, cycleDays);
    final burnRate = summary.expenseThisCycle ~/ safeElapsedDays;
    final runwayMonths = burnRate <= 0
        ? 0.0
        : (summary.totalBalance / burnRate) / 30.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppUiTokens.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedTabReveal(
            tabIndex: 0,
            delay: const Duration(milliseconds: 230),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.t('financial_analytics'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppUiTokens.surfaceTintBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.t('days_30'),
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: AppUiTokens.labelBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AnimatedTabReveal(
            tabIndex: 0,
            delay: const Duration(milliseconds: 270),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    t.t('saving_rate'),
                    '$savingRatePercent%',
                    Icons.savings_rounded,
                    AppUiTokens.successDark,
                    infoTitle: t.t('saving_rate'),
                    infoMessage: t.t('saving_rate_info'),
                    infoExample: t.t('saving_rate_example'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    t.t('burn_rate'),
                    '${settings.formatCurrencyCompact(burnRate)}/${t.t('per_day')}',
                    Icons.local_fire_department_rounded,
                    AppUiTokens.warningDark,
                    infoTitle: t.t('burn_rate'),
                    infoMessage: t.t('burn_rate_info'),
                    infoExample: t.t('burn_rate_example'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    t.t('runway'),
                    '${runwayMonths.toStringAsFixed(1)} ${t.t('month_short')}',
                    Icons.rocket_launch_rounded,
                    AppUiTokens.brandBlue,
                    infoTitle: t.t('runway'),
                    infoMessage: t.t('runway_info'),
                    infoExample: t.t('runway_example'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedTabReveal(
            tabIndex: 0,
            delay: const Duration(milliseconds: 310),
            child: _buildQuickEditStrip(
              context: context,
              settings: settings,
              transactions: transactions,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: AnimatedTabReveal(
                    tabIndex: 0,
                    delay: const Duration(milliseconds: 350),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppUiTokens.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppUiTokens.borderSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.t('trend_7_days'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(
                                summary.weeklyExpenses.length,
                                (index) => Expanded(
                                  child: _buildWeekBar(
                                    t: t,
                                    label: weeklyLabels[index],
                                    value: summary.weeklyExpenses[index],
                                    maxValue: summary.weeklyExpenseMax,
                                    category:
                                        summary.weeklyExpenseCategories[index],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: AnimatedTabReveal(
                    tabIndex: 0,
                    delay: const Duration(milliseconds: 390),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppUiTokens.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppUiTokens.borderSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.t('top_categories'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.t('top_categories_info'),
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: AppUiTokens.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (topCategories.isEmpty)
                            Text(
                              t.t('no_data'),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppUiTokens.textMuted,
                              ),
                            )
                          else
                            ...topCategories.map((entry) {
                              final color = homeCategoryColor(entry.key);
                              final share = summary.expenseThisCycle <= 0
                                  ? 0.0
                                  : entry.value / summary.expenseThisCycle;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: GestureDetector(
                                  onTap: () => _showCategoryBreakdown(
                                    context: context,
                                    categoryKey: entry.key,
                                    transactions: transactions,
                                    settings: settings,
                                    t: t,
                                    range: summary.cycleRange,
                                  ),
                                  child: _buildCompactCategory(
                                    homeCategoryLabel(t, entry.key),
                                    settings.formatCurrency(entry.value),
                                    share.clamp(0.0, 1.0),
                                    color,
                                  ),
                                ),
                              );
                            }),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showAllCategoriesBreakdown(
                              context: context,
                              summary: summary,
                              transactions: transactions,
                              settings: settings,
                              t: t,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppUiTokens.surfaceTintBlue,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppUiTokens.brandBlueBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.pie_chart_outline_rounded,
                                    size: 11,
                                    color: AppUiTokens.labelBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.t('see_all_breakdown'),
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: AppUiTokens.labelBlue,
                                      fontWeight: FontWeight.w700,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? infoTitle,
    String? infoMessage,
    String? infoExample,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AppUiTokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (infoMessage != null) ...[
                const SizedBox(width: 3),
                InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => _showMetricInfoSheet(
                    context: context,
                    title: infoTitle ?? title,
                    message: infoMessage,
                    example: infoExample,
                    color: color,
                  ),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 11,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEditStrip({
    required BuildContext context,
    required AppSettings settings,
    required List<TransactionRecord> transactions,
  }) {
    final t = AppLocalizations.of(context);
    final sorted = [...transactions]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final latest = sorted
        .where(
          (tx) =>
              tx.category != 'transfer_out' &&
              tx.category != 'transfer_in',
        )
        .take(2)
        .toList(growable: false);
    if (latest.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiTokens.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('recent_activity_title'),
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          ...latest.map((tx) {
            final isExpense = tx.isExpense;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
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
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isExpense
                          ? Icons.north_east_rounded
                          : Icons.south_west_rounded,
                      size: 15,
                      color: isExpense
                          ? AppUiTokens.dangerDark
                          : AppUiTokens.successDeep,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${homeCategoryLabel(t, tx.category)} - ${settings.formatCurrency(tx.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      t.t('tap_to_edit'),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: AppUiTokens.brandBlueDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeekBar({
    required AppLocalizations t,
    required String label,
    required double value,
    required double maxValue,
    required String? category,
  }) {
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final ratio = (value / safeMax).clamp(0.0, 1.0);
    final hasValue = value > 0;
    final barColor = category == null
        ? AppUiTokens.textTertiary
        : homeCategoryColor(category);
    final barHeight = hasValue ? 44 * ratio.clamp(0.12, 1.0) : 5.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _humanizeExpenseValue(t: t, value: value),
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              fontSize: 8,
              color: AppUiTokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 13,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: hasValue ? barColor : AppUiTokens.borderUltraSoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: AppUiTokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryBreakdown({
    required BuildContext context,
    required String categoryKey,
    required List<TransactionRecord> transactions,
    required AppSettings settings,
    required AppLocalizations t,
    required DateTimeRange range,
  }) {
    final categoryTxs = transactions
        .where(
          (tx) =>
              tx.isExpense &&
              tx.category == categoryKey &&
              !tx.transactionDate.isBefore(range.start) &&
              tx.transactionDate.isBefore(range.end),
        )
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final label = homeCategoryLabel(t, categoryKey);
    final color = homeCategoryColor(categoryKey);
    final total = categoryTxs.fold<int>(0, (sum, tx) => sum + tx.amount);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        settings.formatCurrency(total),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${categoryTxs.length} ${t.t('transactions_count')}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppUiTokens.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  if (categoryTxs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          t.t('no_data'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppUiTokens.textMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: categoryTxs.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 44),
                        itemBuilder: (context, index) {
                          final tx = categoryTxs[index];
                          final dateStr =
                              '${tx.transactionDate.day}/${tx.transactionDate.month}/${tx.transactionDate.year}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.call_made_rounded,
                                    size: 14,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.note.isNotEmpty
                                            ? tx.note
                                            : label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$dateStr • ${tx.wallet}',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: AppUiTokens.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '-${settings.formatCurrency(tx.amount)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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

  void _showAllCategoriesBreakdown({
    required BuildContext context,
    required HomeDashboardSummary summary,
    required List<TransactionRecord> transactions,
    required AppSettings settings,
    required AppLocalizations t,
  }) {
    final allCategories = summary.cycleExpensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                    t.t('expense_by_category'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t.t('total')}: ${settings.formatCurrency(summary.expenseThisCycle)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppUiTokens.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  if (allCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          t.t('no_data'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppUiTokens.textMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allCategories.length,
                        itemBuilder: (ctx, index) {
                          final entry = allCategories[index];
                          final color = homeCategoryColor(entry.key);
                          final share = summary.expenseThisCycle <= 0
                              ? 0.0
                              : entry.value / summary.expenseThisCycle;
                          final txCount = transactions
                              .where(
                                (tx) =>
                                    tx.isExpense &&
                                    tx.category == entry.key &&
                                    !tx.transactionDate.isBefore(
                                      summary.cycleRange.start,
                                    ) &&
                                    tx.transactionDate.isBefore(
                                      summary.cycleRange.end,
                                    ),
                              )
                              .length;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _showCategoryBreakdown(
                                context: context,
                                categoryKey: entry.key,
                                transactions: transactions,
                                settings: settings,
                                t: t,
                                range: summary.cycleRange,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          homeCategoryLabel(t, entry.key),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            settings.formatCurrency(entry.value),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: color,
                                            ),
                                          ),
                                          Text(
                                            '$txCount trx • ${(share * 100).toInt()}%',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: AppUiTokens.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: AppUiTokens.textMuted,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: share.clamp(0.0, 1.0),
                                      minHeight: 4,
                                      backgroundColor: AppUiTokens.borderSoft,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

  Widget _buildCompactCategory(
    String name,
    String amount,
    double share,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$amount (${(share * 100).toInt()}%)',
              style: TextStyle(
                fontSize: 9.5,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 5,
            backgroundColor: AppUiTokens.borderSoft,
            color: color,
          ),
        ),
      ],
    );
  }

  HomeDashboardSummary _buildSummary({
    required List<TransactionRecord> transactions,
    required int cycleStartDay,
    required DateTime now,
  }) {
    final cycleRange = _cycleRange(now, cycleStartDay);
    var totalBalance = MasterDataService.instance.openingBalanceTotal;
    var incomeThisCycle = 0;
    var expenseThisCycle = 0;
    final weeklyExpenses = List<double>.filled(7, 0);
    final weeklyExpenseCategoryTotals = List.generate(
      7,
      (_) => <String, int>{},
    );
    final cycleExpensesByCategory = <String, int>{};

    for (final tx in transactions) {
      final signed = tx.isExpense ? -tx.amount : tx.amount;
      totalBalance += signed;
      final txDate = tx.transactionDate;

      if (!txDate.isBefore(cycleRange.start) &&
          txDate.isBefore(cycleRange.end)) {
        if (tx.category == 'transfer_out' || tx.category == 'transfer_in') {
          // Transfers are internal movements, not real income/expense.
        } else if (tx.isExpense) {
          expenseThisCycle += tx.amount;
          final key = tx.category;
          cycleExpensesByCategory[key] =
              (cycleExpensesByCategory[key] ?? 0) + tx.amount;
        } else {
          incomeThisCycle += tx.amount;
        }
      }

      final dayIndex = _dayIndexInLast7(txDate, now);
      if (dayIndex >= 0 && tx.isExpense && tx.category != 'transfer_out') {
        weeklyExpenses[dayIndex] += tx.amount.toDouble();
        final categoryTotals = weeklyExpenseCategoryTotals[dayIndex];
        categoryTotals[tx.category] =
            (categoryTotals[tx.category] ?? 0) + tx.amount;
      }
    }

    final weeklyExpenseCategories = weeklyExpenseCategoryTotals
        .map(_dominantCategory)
        .toList(growable: false);

    var weeklyExpenseMax = 1.0;
    for (final value in weeklyExpenses) {
      if (value > weeklyExpenseMax) {
        weeklyExpenseMax = value;
      }
    }

    return HomeDashboardSummary(
      totalBalance: totalBalance,
      incomeThisCycle: incomeThisCycle,
      expenseThisCycle: expenseThisCycle,
      weeklyExpenses: weeklyExpenses,
      weeklyExpenseMax: weeklyExpenseMax,
      weeklyExpenseCategories: weeklyExpenseCategories,
      cycleRange: cycleRange,
      cycleExpensesByCategory: cycleExpensesByCategory,
    );
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

  int _dayIndexInLast7(DateTime txDate, DateTime now) {
    final today = DateUtils.dateOnly(now);
    final txDay = DateUtils.dateOnly(txDate);
    final diff = today.difference(txDay).inDays;
    if (diff < 0 || diff > 6) {
      return -1;
    }
    return 6 - diff;
  }

  int _currentStreakDays(List<TransactionRecord> transactions) {
    if (transactions.isEmpty) return 0;
    final today = DateUtils.dateOnly(DateTime.now());
    final days = <DateTime>{};
    for (final tx in transactions) {
      days.add(DateUtils.dateOnly(tx.transactionDate));
    }
    var cursor = today;
    var streak = 0;
    while (days.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    if (streak == 0 && days.contains(today.subtract(const Duration(days: 1)))) {
      cursor = today.subtract(const Duration(days: 1));
      while (days.contains(cursor)) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }
    return streak;
  }

  List<MapEntry<String, int>> _topCategories(Map<String, int> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  String _humanizeExpenseValue({
    required AppLocalizations t,
    required double value,
  }) {
    final rounded = value.round();
    if (rounded == 0) {
      return t.t('no_tx_short');
    }
    return _formatChartAmount(rounded);
  }

  String _formatChartAmount(int value) {
    final absValue = value.abs();
    if (absValue >= 1000000000) {
      return '${_formatChartUnit(absValue / 1000000000)}b';
    }
    if (absValue >= 1000000) {
      return '${_formatChartUnit(absValue / 1000000)}m';
    }
    if (absValue >= 1000) {
      return '${_formatChartUnit(absValue / 1000)}k';
    }
    return absValue.toString();
  }

  String _formatChartUnit(double value) {
    if (value >= 10 || value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  String? _dominantCategory(Map<String, int> totals) {
    if (totals.isEmpty) return null;
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  void _showNotificationCenter({
    required BuildContext context,
    required List<TransactionRecord> transactions,
    required List<RecurringBill> bills,
    required AppSettings settings,
    required AppLocalizations t,
  }) {
    final items = _buildNotificationItems(
      transactions: transactions,
      bills: bills,
      t: t,
      settings: settings,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.t('notif_center_title'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  Text(
                    t.t('notif_center_empty'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppUiTokens.textMuted,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _handleInboxAction(context, sheetContext, item),
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(item.icon, size: 16, color: item.color),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            item.subtitle,
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: item.actionLabel == null
                              ? Text(
                                  item.timeLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppUiTokens.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : TextButton(
                                  onPressed: () =>
                                      _handleInboxAction(context, sheetContext, item),
                                  child: Text(
                                    item.actionLabel!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<HomeInboxItem> _buildNotificationItems({
    required List<TransactionRecord> transactions,
    required List<RecurringBill> bills,
    required AppLocalizations t,
    required AppSettings settings,
  }) {
    final now = DateTime.now();
    final items = <HomeInboxItem>[];

    for (final bill in bills) {
      final dayDiff = DueDateService.daysUntilDueDate(
        from: now,
        dueDay: bill.dueDay,
      );
      if (dayDiff <= 3) {
        final dueLabel = dayDiff == 0
            ? t.t('due_today')
            : '$dayDiff ${t.t('due_in_days')}';
        items.add(
          HomeInboxItem(
            title: t.t('notif_bill_due_title'),
            subtitle:
                '${bill.name} - ${settings.formatCurrency(bill.amount)} ($dueLabel)',
            timeLabel: t.t('notif_upcoming'),
            icon: Icons.receipt_long_rounded,
            color: AppUiTokens.brandBlue,
            sortValue: now.millisecondsSinceEpoch + (1000 - dayDiff),
            actionLabel: t.t('action_pay'),
            actionType: 'open_bills',
          ),
        );
      }
    }

    final recentTransactions = transactions
        .where(
          (tx) =>
              tx.category != 'transfer_out' &&
              tx.category != 'transfer_in',
        )
        .take(8);
    for (final tx in recentTransactions) {
      final title = tx.isExpense
          ? t.t('notif_expense_added')
          : t.t('notif_income_added');
      items.add(
        HomeInboxItem(
          title: title,
          subtitle:
              '${homeCategoryLabel(t, tx.category)} - ${settings.formatCurrency(tx.amount)}',
          timeLabel: _relativeTimeLabel(tx.transactionDate, t),
          icon: tx.isExpense
              ? Icons.north_east_rounded
              : Icons.south_west_rounded,
          color: tx.isExpense
              ? AppUiTokens.dangerDark
              : AppUiTokens.successDeep,
          sortValue: tx.transactionDate.millisecondsSinceEpoch,
          actionLabel: t.t('action_add_more'),
          actionType: 'repeat_tx',
          isExpense: tx.isExpense,
          category: tx.category,
          wallet: tx.wallet,
        ),
      );
    }

    items.sort((a, b) => b.sortValue.compareTo(a.sortValue));
    return items.take(15).toList();
  }

  String _relativeTimeLabel(DateTime date, AppLocalizations t) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return t.t('notif_just_now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _handleInboxAction(
    BuildContext rootContext,
    BuildContext sheetContext,
    HomeInboxItem item,
  ) async {
    if (item.actionType == 'open_bills') {
      Navigator.pop(sheetContext);
      _showAllBillsSheet(context: rootContext);
      return;
    }
    if (item.actionType == 'repeat_tx') {
      Navigator.pop(sheetContext);
      final result = await Navigator.push(
        rootContext,
        MaterialPageRoute<Object?>(
          builder: (_) => AddTransactionScreen(
            initialIsExpense: item.isExpense,
            initialCategory: item.category,
            initialWallet: item.wallet,
          ),
        ),
      );
      if (!rootContext.mounted) return;
      showTransactionSaveResultSnack(
        rootContext,
        result,
        fallbackIsExpense: item.isExpense,
      );
    }
  }

  void _showAllBillsSheet({required BuildContext context}) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      t.t('monthly_bills'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _showRecurringBillForm(context: sheetContext),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(t.t('add_recurring_bill')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<List<RecurringBill>>(
                  valueListenable: recurringBillsNotifier,
                  builder: (context, bills, _) {
                    if (bills.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            t.t('no_data'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppUiTokens.textMuted,
                            ),
                          ),
                        ),
                      );
                    }
                    final now = DateTime.now();
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: bills.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final bill = bills[index];
                          final dayDiff = DueDateService.daysUntilDueDate(
                            from: now,
                            dueDay: bill.dueDay,
                          );
                          final dueLabel = dayDiff == 0
                              ? t.t('due_today')
                              : '$dayDiff ${t.t('due_in_days')}';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppUiTokens.brandBlue,
                              size: 18,
                            ),
                            title: Text(
                              bill.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${t.t('due_date')} ${bill.dueDay} ($dueLabel)',
                              style: const TextStyle(fontSize: 10),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  settings.formatCurrency(bill.amount),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppUiTokens.dangerDark,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _showRecurringBillForm(
                                        context: sheetContext,
                                        initial: bill,
                                      );
                                    } else if (value == 'delete') {
                                      await _confirmDeleteRecurringBill(
                                        context: sheetContext,
                                        bill: bill,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Text(t.t('edit')),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text(t.t('delete')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRecurringBillForm({
    required BuildContext context,
    RecurringBill? initial,
  }) async {
    const maxAmount = 1000000000;
    final t = AppLocalizations.of(context);
    final isEdit = initial != null;
    final nameController = TextEditingController(text: initial?.name ?? '');
    final amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toString(),
    );
    final dueDayController = TextEditingController(
      text: initial == null ? '' : initial.dueDay.toString(),
    );
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppUiTokens.surfaceGradientStart, AppUiTokens.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppUiTokens.borderUltraSoft),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppUiTokens.brandBlueLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 18,
                        color: AppUiTokens.brandBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit
                          ? t.t('edit_recurring_bill')
                          : t.t('add_recurring_bill'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: _sheetInputDecoration(
                    label: t.t('bill_name'),
                    hint: t.t('bill_name_hint'),
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandSeparatorFormatter()],
                  decoration: _sheetInputDecoration(
                    label: t.t('amount'),
                    hint: t.t('amount_hint'),
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dueDayController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _sheetInputDecoration(
                    label: t.t('due_day'),
                    hint: t.t('due_day_hint'),
                    icon: Icons.event_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(t.t('cancel')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
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
    if (save != true) return;
    if (!context.mounted) return;
    final name = nameController.text.trim();
    final amount =
        int.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final dueDay = int.tryParse(dueDayController.text) ?? 0;
    if (name.length < 2 ||
        name.length > 40 ||
        amount <= 0 ||
        amount > maxAmount ||
        dueDay < 1 ||
        dueDay > 31) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.t('invalid_recurring_bill'))));
      return;
    }
    try {
      if (isEdit) {
        await updateRecurringBill(
          RecurringBill(
            id: initial.id,
            name: name,
            amount: amount,
            dueDay: dueDay,
          ),
        );
      } else {
        await addRecurringBill(
          RecurringBill(id: 0, name: name, amount: amount, dueDay: dueDay),
        );
      }
      await NotificationService.instance.syncFromPreferences();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t.t('save_failed')}: $e')));
    }
  }

  Future<void> _confirmDeleteRecurringBill({
    required BuildContext context,
    required RecurringBill bill,
  }) async {
    final t = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppUiTokens.borderSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t.t('delete_recurring_bill'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${t.t('delete_recurring_bill_confirm')} "${bill.name}"?',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppUiTokens.textMutedDeep,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(t.t('cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(t.t('delete')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (yes != true) return;
    try {
      await deleteRecurringBill(bill.id);
      await NotificationService.instance.syncFromPreferences();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t.t('delete_failed')}: $e')));
    }
  }

  void _showMetricInfoSheet({
    required BuildContext context,
    required String title,
    required String message,
    required Color color,
    String? example,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppUiTokens.textBody,
                  ),
                ),
                if (example != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      example,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: color,
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
  }

  InputDecoration _sheetInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      filled: true,
      fillColor: AppUiTokens.white,
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
        borderSide: const BorderSide(color: AppUiTokens.brandBlue, width: 1.35),
      ),
    );
  }
}
