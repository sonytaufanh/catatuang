import 'package:flutter/material.dart';

import '../data/transaction_store.dart';
import '../services/app_animations.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/master_data_service.dart';
import '../services/net_worth_service.dart';

class NetWorthScreen extends StatelessWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('net_worth'))),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          transactionsNotifier,
          MasterDataService.instance,
        ]),
        builder: (context, _) {
          final summary = NetWorthService.instance.compute(
            transactions: transactionsNotifier.value,
            openingBalance: MasterDataService.instance.openingBalanceTotal,
          );
          return AnimatedFadeSlide(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppUiTokens.brandBlueSoft,
                        AppUiTokens.brandBlue,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.t('net_worth'),
                        style: const TextStyle(
                          color: AppUiTokens.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        settings.formatBalanceCurrency(summary.netWorth),
                        style: const TextStyle(
                          color: AppUiTokens.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.t('assets_minus_liabilities'),
                        style: const TextStyle(
                          color: AppUiTokens.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t.t('cashflow_report'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...summary.months.reversed.map(
                  (month) => _MonthRow(month: month, settings: settings),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.month, required this.settings});

  final MonthlyCashflow month;
  final AppSettings settings;

  static const List<String> _idMonths = [
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
  static const List<String> _enMonths = [
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
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isEn = settings.languageCode == 'en';
    final names = isEn ? _enMonths : _idMonths;
    final label = '${names[month.month.month - 1]} ${month.month.year}';
    final netColor = month.net >= 0
        ? AppUiTokens.successDeep
        : AppUiTokens.dangerDeep;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                settings.formatSignedCurrency(month.net),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: netColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _pill(
                  t.t('income'),
                  settings.formatCurrency(month.income),
                  AppUiTokens.successDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pill(
                  t.t('expense'),
                  settings.formatCurrency(month.expense),
                  AppUiTokens.dangerDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pill(
                  t.t('closing_balance'),
                  settings.formatCurrency(month.closingBalance),
                  AppUiTokens.brandBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value, Color color) {
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
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
