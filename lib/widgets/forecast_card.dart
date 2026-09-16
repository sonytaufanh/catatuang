import 'package:flutter/material.dart';

import '../data/recurring_bill_store.dart';
import '../data/transaction_store.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/forecast_service.dart';
import '../services/master_data_service.dart';

/// Compact cashflow forecast card: daily safe-to-spend allowance and a
/// projection for the end of the current billing cycle.
class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        transactionsNotifier,
        recurringBillsNotifier,
        MasterDataService.instance,
      ]),
      builder: (context, _) {
        final transactions = transactionsNotifier.value;
        final bills = recurringBillsNotifier.value;
        var balance = MasterDataService.instance.openingBalanceTotal;
        for (final tx in transactions) {
          balance += tx.isExpense ? -tx.amount : tx.amount;
        }
        final forecast = ForecastService.instance.compute(
          transactions: transactions,
          bills: bills,
          totalBalance: balance,
          cycleStartDay: settings.billingCycleStart,
          now: DateTime.now(),
        );
        if (!forecast.hasData) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppUiTokens.brandBlue.withValues(alpha: 0.10),
                AppUiTokens.successDark.withValues(alpha: 0.08),
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
                  const Icon(
                    Icons.insights_rounded,
                    size: 14,
                    color: AppUiTokens.brandBlue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.t('safe_to_spend_today'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    settings.formatCurrency(forecast.safeToSpendToday),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppUiTokens.successDeep,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 6 : 8),
              Row(
                children: [
                  Expanded(
                    child: _mini(
                      t.t('forecast_projection'),
                      settings.formatCurrency(forecast.projectedCycleEndBalance),
                    ),
                  ),
                  Expanded(
                    child: _mini(
                      t.t('forecast_days_left'),
                      '${forecast.daysLeftInCycle}',
                    ),
                  ),
                  Expanded(
                    child: _mini(
                      t.t('forecast_upcoming_bills'),
                      settings.formatCurrency(forecast.upcomingBillsAmount),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: AppUiTokens.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
