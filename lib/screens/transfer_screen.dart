import 'package:flutter/material.dart';

import '../data/database_service.dart';
import '../data/transaction_store.dart';
import '../services/app_animations.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/error_log_service.dart';
import '../services/master_data_service.dart';
import '../services/thousand_separator_formatter.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  static const int _maxAmount = 1000000000;
  static const double _sectionTitleSize = AppUiTokens.textLg;
  static const double _fieldTextSize = 11.5;
  static const double _actionTextSize = AppUiTokens.textSm;

  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();

  DateTime _date = DateTime.now();
  String _sourceWallet = '';
  String _destWallet = '';
  List<String> _wallets = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets = await MasterDataService.instance.wallets();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      if (_wallets.isNotEmpty) {
        _sourceWallet = _wallets.first;
        _destWallet = _wallets.length > 1 ? _wallets[1] : _wallets.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppSettingsScope.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.height < 840 || screenSize.width < 420;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('transfer_between_wallets')),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            compact ? 8 : 10,
            compact ? 10 : 12,
            compact ? 10 : 12,
          ),
          child: Column(
            children: [
              // Transfer header badge
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 12 : 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppUiTokens.brandBlueSoft, AppUiTokens.brandBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppUiTokens.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: AppUiTokens.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.t('transfer'),
                            style: const TextStyle(
                              color: AppUiTokens.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.t('transfer_between_wallets'),
                            style: TextStyle(
                              color: AppUiTokens.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              // Amount input
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
                  border: Border.all(color: AppUiTokens.borderSoft),
                ),
                child: TextField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandSeparatorFormatter()],
                  style: TextStyle(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    labelText: t.t('amount'),
                    prefixText: '${s.currencySymbol} ',
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWalletSelector(
                        title: t.t('source_wallet'),
                        selected: _sourceWallet,
                        onTap: (value) => setState(() => _sourceWallet = value),
                        compact: compact,
                        t: t,
                      ),
                      SizedBox(height: compact ? 6 : 8),
                      // Swap button
                      Center(
                        child: PressableScale(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _swapWallets,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppUiTokens.brandBlue.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppUiTokens.brandBlueBorder,
                              ),
                            ),
                            child: const Icon(
                              Icons.swap_vert_rounded,
                              size: 20,
                              color: AppUiTokens.brandBlue,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 6 : 8),
                      _buildWalletSelector(
                        title: t.t('destination_wallet'),
                        selected: _destWallet,
                        onTap: (value) => setState(() => _destWallet = value),
                        compact: compact,
                        t: t,
                      ),
                      SizedBox(height: compact ? 8 : 10),
                      _buildDateTile(t, s.txIncludeTime, compact: compact),
                      SizedBox(height: compact ? 8 : 10),
                      TextField(
                        controller: _note,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: t.t('add_note'),
                          hintText: t.t('add_note'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppUiTokens.radiusMd,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              SizedBox(
                width: double.infinity,
                height: compact ? 48 : 52,
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
        ),
      ),
    );
  }

  Widget _buildWalletSelector({
    required String title,
    required String selected,
    required ValueChanged<String> onTap,
    required bool compact,
    required AppLocalizations t,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
        border: Border.all(color: AppUiTokens.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: _sectionTitleSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Wrap(
            spacing: compact ? 4 : 6,
            runSpacing: compact ? 4 : 6,
            children: _wallets
                .map(
                  (value) => _buildOptionChip(
                    label: _walletLabel(t, value),
                    selected: selected == value,
                    compact: compact,
                    onTap: () => onTap(value),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool selected,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: compact ? 8 : 9,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppUiTokens.surfaceBlueSoft, AppUiTokens.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : AppUiTokens.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppUiTokens.brandBlueBorder : AppUiTokens.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                Icons.check_rounded,
                size: compact ? 13 : 14,
                color: AppUiTokens.brandBlue,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: _fieldTextSize,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppUiTokens.textNavyStrong
                    : AppUiTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile(
    AppLocalizations t,
    bool includeTime, {
    required bool compact,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      onTap: _pickDateTime,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppUiTokens.surfaceGradientStart,
              AppUiTokens.surfaceGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: AppUiTokens.brandBlueBorder),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            compact ? 8 : 10,
            compact ? 10 : 12,
            compact ? 8 : 10,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  gradient: AppUiTokens.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: AppUiTokens.white,
                  size: compact ? 18 : 20,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      includeTime ? t.t('date_time') : t.t('date_label'),
                      style: const TextStyle(
                        fontSize: _actionTextSize,
                        fontWeight: FontWeight.w700,
                        color: AppUiTokens.textSecondary,
                      ),
                    ),
                    SizedBox(height: compact ? 1 : 2),
                    Text(
                      _formatDate(_date, includeTime: includeTime),
                      style: const TextStyle(
                        fontSize: _sectionTitleSize,
                        fontWeight: FontWeight.w800,
                        color: AppUiTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 8,
                  vertical: compact ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: AppUiTokens.brandBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: compact ? 12.5 : 14,
                      color: AppUiTokens.brandBlue,
                    ),
                    SizedBox(width: compact ? 3 : 4),
                    Text(
                      t.t('change_btn'),
                      style: TextStyle(
                        color: AppUiTokens.brandBlue,
                        fontSize: _actionTextSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _swapWallets() {
    setState(() {
      final temp = _sourceWallet;
      _sourceWallet = _destWallet;
      _destWallet = temp;
    });
  }

  Future<void> _pickDateTime() async {
    final settings = AppSettingsScope.of(context);
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (d == null || !mounted) return;
    if (!settings.txIncludeTime) {
      setState(() => _date = DateTime(d.year, d.month, d.day));
      return;
    }
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (tm == null || !mounted) return;
    setState(
      () => _date = DateTime(d.year, d.month, d.day, tm.hour, tm.minute),
    );
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    if (_saving) return;

    final amount =
        int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) {
      _snack(t.t('invalid_amount'));
      return;
    }
    if (amount > _maxAmount) {
      _snack(t.t('max_amount_error'));
      return;
    }
    if (_sourceWallet == _destWallet) {
      _snack(t.t('same_wallet_error'));
      return;
    }

    final txDate = settings.txIncludeTime
        ? _date
        : DateTime(_date.year, _date.month, _date.day);
    if (txDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      _snack(t.t('invalid_tx_date'));
      return;
    }

    final sourceLabel = _walletLabel(t, _sourceWallet);
    final destLabel = _walletLabel(t, _destWallet);
    final transferNote = _note.text.trim().isNotEmpty
        ? '${t.t('transfer')}: $sourceLabel → $destLabel | ${_note.text.trim()}'
        : '${t.t('transfer')}: $sourceLabel → $destLabel';

    setState(() => _saving = true);
    try {
      await DatabaseService.instance.addTransfer(
        amount: amount,
        sourceWallet: _sourceWallet,
        destWallet: _destWallet,
        transactionDate: txDate,
        note: transferNote,
      );

      await refreshTransactions();
      if (!mounted) return;
      _snack(t.t('transfer_success'));
      Navigator.pop(context, true);
    } catch (e) {
      await ErrorLogService.instance.log(
        source: 'transfer_save',
        error: e,
      );
      _snack('${t.t('failed_to_save')}: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDate(DateTime d, {required bool includeTime}) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    if (!includeTime) return '$day/$month/${d.year}';
    return '$day/$month/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _walletLabel(AppLocalizations t, String value) {
    switch (value.toLowerCase()) {
      case 'cash':
        return t.t('wallet_cash');
      case 'bank':
        return t.t('wallet_bank');
      case 'ewallet':
      case 'e-wallet':
      case 'e_wallet':
        return t.t('wallet_ewallet');
      case 'card':
        return t.t('wallet_card');
      default:
        return value;
    }
  }

  ThemeData _pickerTheme(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme;
    return base.copyWith(
      colorScheme: scheme.copyWith(
        primary: AppUiTokens.brandBlue,
        onPrimary: AppUiTokens.white,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        headerBackgroundColor: AppUiTokens.brandBlue,
        headerForegroundColor: AppUiTokens.white,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        dialHandColor: AppUiTokens.brandBlue,
      ),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }
}
