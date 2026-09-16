import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database_service.dart';
import '../data/models/transaction_record.dart';
import '../data/transaction_store.dart';
import '../services/app_animations.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/analytics_service.dart';
import '../services/attachment_service.dart';
import '../services/error_log_service.dart';
import '../services/master_data_service.dart';
import '../services/thousand_separator_formatter.dart';
import 'split_transaction_screen.dart';

void showTransactionSaveResultSnack(
  BuildContext context,
  Object? result, {
  bool? fallbackIsExpense,
}) {
  if (result is! Map) return;
  if (result['tx_saved'] != true) return;
  final isEdit = result['is_edit'] == true;
  final isExpense =
      (result['is_expense'] == true) || (fallbackIsExpense == true);
  final isEn = AppSettingsScope.of(context).languageCode == 'en';
  final msg = isEdit
      ? (isEn
            ? 'Transaction updated successfully.'
            : 'Transaksi berhasil diperbarui.')
      : isExpense
      ? (isEn
            ? 'Expense saved successfully.'
            : 'Pengeluaran berhasil disimpan.')
      : (isEn ? 'Income saved successfully.' : 'Pemasukan berhasil disimpan.');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.editTransaction,
    this.initialIsExpense,
    this.initialWallet,
    this.initialCategory,
    this.initialNote,
  });

  final TransactionRecord? editTransaction;
  final bool? initialIsExpense;
  final String? initialWallet;
  final String? initialCategory;
  final String? initialNote;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  static const int _maxAmount = 1000000000;
  static const double _sectionTitleSize = AppUiTokens.textLg;
  static const double _fieldTextSize = 11.5;
  static const double _actionTextSize = AppUiTokens.textSm;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  final _picker = ImagePicker();

  bool _isExpense = true;
  DateTime _date = DateTime.now();
  String _wallet = 'cash';
  String _category = 'food';
  XFile? _receipt;
  List<String> _wallets = const [];
  List<String> _categories = const [];
  bool _saving = false;

  bool get _isEdit => widget.editTransaction != null;

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_handleAmountFocusChange);
    final tx = widget.editTransaction;
    if (tx != null) {
      _isExpense = tx.isExpense;
      _wallet = tx.wallet;
      _category = tx.category;
      _date = tx.transactionDate;
      _amount.text = ThousandSeparatorFormatter.format(tx.amount);
      _note.text = tx.note;
      if (tx.receiptPath.isNotEmpty) {
        _receipt = XFile(tx.receiptPath);
      }
    } else {
      if (widget.initialIsExpense != null) {
        _isExpense = widget.initialIsExpense!;
      }
      if (widget.initialWallet != null &&
          widget.initialWallet!.trim().isNotEmpty) {
        _wallet = widget.initialWallet!.trim();
      }
      if (widget.initialCategory != null &&
          widget.initialCategory!.trim().isNotEmpty) {
        _category = widget.initialCategory!.trim();
      }
      if (widget.initialNote != null && widget.initialNote!.trim().isNotEmpty) {
        _note.text = widget.initialNote!.trim();
      }
    }
    _loadMaster();
  }

  void _handleAmountFocusChange() {
    if (!mounted) return;
    setState(() {});
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
      if (!_wallets.contains(_wallet)) _wallet = _wallets.first;
      if (!_categories.contains(_category)) _category = _categories.first;
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
        title: Text(_isEdit ? t.t('edit_transaction') : t.t('transaction_detail')),
        actions: [
          if (!_isEdit)
            IconButton(
              tooltip: t.t('split_transaction'),
              onPressed: () async {
                final saved = await Navigator.push(
                  context,
                  MaterialPageRoute<Object?>(
                    builder: (_) => const SplitTransactionScreen(),
                  ),
                );
                if (saved == true && context.mounted) {
                  Navigator.pop(context, <String, dynamic>{
                    'tx_saved': true,
                    'is_edit': false,
                    'is_expense': true,
                  });
                }
              },
              icon: const Icon(Icons.call_split_rounded),
            ),
        ],
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
              Container(
                padding: EdgeInsets.all(compact ? 3 : 4),
                decoration: BoxDecoration(
                  color: AppUiTokens.brandBlueLight,
                  borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
                ),
                child: Row(
                  children: [
                    Expanded(child: _typeBtn(t.t('expense_tab'), true)),
                    const SizedBox(width: 4),
                    Expanded(child: _typeBtn(t.t('income_tab'), false)),
                  ],
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
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
                    labelText: _isExpense
                        ? t.t('expense_amount')
                        : t.t('income_amount'),
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
                      _buildSimpleSelectorSection(
                        title: t.t('wallet_field'),
                        values: _wallets,
                        selected: _wallet,
                        labelBuilder: (value) => _walletLabel(t, value),
                        onTap: (value) => setState(() => _wallet = value),
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 8 : 10),
                      _buildSimpleSelectorSection(
                        title: t.t('category'),
                        values: _categories,
                        selected: _category,
                        labelBuilder: (value) => _categoryLabel(t, value),
                        onTap: (value) => setState(() => _category = value),
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 8 : 10),
                      _buildDateTimeTile(t, s.txIncludeTime, compact: compact),
                      SizedBox(height: compact ? 8 : 10),
                      TextField(
                        controller: _note,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: t.t('note_field'),
                          hintText: t.t('add_note'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppUiTokens.radiusMd,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 10),
                      _buildInlineAttachmentRow(t, compact: compact),
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
                      : Text(_isEdit ? t.t('save_changes') : t.t('save_data')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBtn(String label, bool expense) {
    final active = _isExpense == expense;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: FilledButton(
        onPressed: () => _setTransactionType(expense),
        style: FilledButton.styleFrom(
          elevation: 0,
          foregroundColor: active
              ? AppUiTokens.textPrimary
              : AppUiTokens.textMutedDeep,
          backgroundColor: active ? AppUiTokens.white : AppUiTokens.transparent,
          overlayColor: AppUiTokens.brandBlueLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Future<void> _setTransactionType(bool expense) async {
    if (_isExpense == expense) return;
    setState(() {
      _isExpense = expense;
      _categories = expense
          ? [...MasterDataService.defaultCategories]
          : [...MasterDataService.defaultIncomeCategories];
      if (!_categories.contains(_category)) {
        _category = _categories.first;
      }
    });
    final nextCategories = expense
        ? await MasterDataService.instance.expenseCategories()
        : await MasterDataService.instance.incomeCategories();
    if (!mounted || _isExpense != expense) return;
    setState(() {
      _categories = nextCategories;
      if (!_categories.contains(_category)) {
        _category = _categories.first;
      }
    });
  }

  Widget _buildSimpleSelectorSection({
    required String title,
    required List<String> values,
    required String selected,
    required String Function(String value) labelBuilder,
    required ValueChanged<String> onTap,
    required bool compact,
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
            children: values
                .map(
                  (value) => _buildOptionChip(
                    label: labelBuilder(value),
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

  Widget _buildInlineAttachmentRow(
    AppLocalizations t, {
    required bool compact,
  }) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined, size: 15),
            label: Text(t.t('camera')),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, compact ? 36 : 40),
              backgroundColor: AppUiTokens.brandBlueLight,
              foregroundColor: AppUiTokens.brandBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 15),
            label: Text(t.t('gallery')),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, compact ? 36 : 40),
              backgroundColor: AppUiTokens.surfaceMuted,
              foregroundColor: AppUiTokens.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildAttachmentStatusChip(t),
      ],
    );
  }

  Widget _buildAttachmentStatusChip(AppLocalizations t) {
    final hasAttachment = _receipt != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasAttachment
            ? AppUiTokens.brandBlueLight
            : AppUiTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hasAttachment ? t.t('attachment_local') : t.t('attachment_empty'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: hasAttachment
              ? AppUiTokens.brandBlue
              : AppUiTokens.textSecondary,
        ),
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
    if (_wallet.trim().isEmpty || _category.trim().isEmpty) {
      _snack(t.t('wallet_category_required'));
      return;
    }
    final note = _note.text.trim();
    if (note.length > 140) {
      _snack(t.t('note_max_140'));
      return;
    }
    final txDate = settings.txIncludeTime
        ? _date
        : DateTime(_date.year, _date.month, _date.day);
    if (txDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      _snack(t.t('invalid_tx_date'));
      return;
    }
    setState(() => _saving = true);
    try {
      await MasterDataService.instance.ensureMasterContains(
        wallet: _wallet,
        category: _category,
        isExpense: _isExpense,
      );
      final currency = _isEdit &&
              widget.editTransaction!.currency.trim().isNotEmpty
          ? widget.editTransaction!.currency
          : settings.currencyCode;
      if (_isEdit) {
        await DatabaseService.instance.updateTransaction(
          id: widget.editTransaction!.id,
          isExpense: _isExpense,
          amount: amount,
          wallet: _wallet,
          category: _category,
          transactionDate: txDate,
          isCleared: true,
          note: note,
          receiptPath: _receipt?.path ?? '',
          currency: currency,
        );
      } else {
        await DatabaseService.instance.addTransaction(
          isExpense: _isExpense,
          amount: amount,
          wallet: _wallet,
          category: _category,
          transactionDate: txDate,
          isCleared: true,
          note: note,
          receiptPath: _receipt?.path ?? '',
          currency: currency,
        );
      }
      await refreshTransactions();
      if (!_isEdit) {
        await AnalyticsService.instance.track(
          'tx_created',
          properties: {
            'is_expense': _isExpense,
            'amount': amount,
            'wallet': _wallet,
            'category': _category,
          },
        );
      }
      if (!mounted) return;
      Navigator.pop(context, <String, dynamic>{
        'tx_saved': true,
        'is_edit': _isEdit,
        'is_expense': _isExpense,
      });
    } catch (e) {
      await ErrorLogService.instance.log(
        source: 'add_transaction_save',
        error: e,
      );
      _snack('${t.t('failed_to_save')}: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    final previous = _receipt?.path;
    final savedPath = await AttachmentService.instance.persist(picked.path);
    if (!mounted) return;
    if (previous != null && previous != savedPath) {
      await AttachmentService.instance.deleteIfManaged(previous);
    }
    setState(() => _receipt = XFile(savedPath));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  Widget _buildDateTimeTile(
    AppLocalizations t,
    bool includeTime, {
    required bool compact,
  }) {
    final accent = AppUiTokens.brandBlue;
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
                      style: TextStyle(
                        fontSize: _actionTextSize,
                        fontWeight: FontWeight.w700,
                        color: AppUiTokens.textSecondary,
                      ),
                    ),
                    SizedBox(height: compact ? 1 : 2),
                    Text(
                      _formatDate(_date, includeTime: includeTime),
                      style: TextStyle(
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
                  color: accent.withValues(alpha: 0.12),
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

  String _categoryLabel(AppLocalizations t, String value) {
    switch (value.toLowerCase()) {
      case 'food':
        return t.t('category_food');
      case 'transport':
        return t.t('category_transport');
      case 'shopping':
        return t.t('category_shopping');
      case 'bills':
        return t.t('category_bills');
      case 'entertainment':
        return t.t('category_entertainment');
      case 'health':
        return t.t('category_health');
      case 'education':
        return t.t('category_education');
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
        return value;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus
      ..removeListener(_handleAmountFocusChange)
      ..dispose();
    super.dispose();
  }
}
