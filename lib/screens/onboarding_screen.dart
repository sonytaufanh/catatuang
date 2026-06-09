import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';
import '../services/app_animations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/master_data_service.dart';
import '../services/onboarding_service.dart';
import '../services/savings_goal_service.dart';
import '../services/thousand_separator_formatter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.settings,
    required this.onDone,
  });

  final AppSettings settings;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _stepCount = 4;
  static const double _maxContentWidth = 520;
  static const String _appIconAsset = 'assets/icons/app_icon.png';
  static final RegExp _nonDigitPattern = RegExp(r'[^0-9]');
  static const List<_ChoiceSpec> _languageChoices = [
    _ChoiceSpec(
      value: 'id',
      labelId: 'Indonesia',
      labelEn: 'Indonesia',
      icon: Icons.translate_rounded,
    ),
    _ChoiceSpec(
      value: 'en',
      labelId: 'English',
      labelEn: 'English',
      icon: Icons.language_rounded,
    ),
  ];
  static const List<_ChoiceSpec> _currencyChoices = [
    _ChoiceSpec(
      value: 'IDR',
      labelId: 'IDR (Rp)',
      labelEn: 'IDR (Rp)',
      icon: Icons.payments_rounded,
    ),
    _ChoiceSpec(
      value: 'USD',
      labelId: 'USD (\$)',
      labelEn: 'USD (\$)',
      icon: Icons.attach_money_rounded,
    ),
    _ChoiceSpec(
      value: 'SGD',
      labelId: 'SGD (\$)',
      labelEn: 'SGD (\$)',
      icon: Icons.account_balance_rounded,
    ),
    _ChoiceSpec(
      value: 'MYR',
      labelId: 'MYR (RM)',
      labelEn: 'MYR (RM)',
      icon: Icons.credit_card_rounded,
    ),
  ];
  static const List<_ChoiceSpec> _walletChoices = [
    _ChoiceSpec(
      value: 'cash',
      labelId: 'Tunai',
      labelEn: 'Cash',
      icon: Icons.payments_outlined,
    ),
    _ChoiceSpec(
      value: 'bank',
      labelId: 'Bank',
      labelEn: 'Bank',
      icon: Icons.account_balance_rounded,
    ),
    _ChoiceSpec(
      value: 'ewallet',
      labelId: 'E-Wallet',
      labelEn: 'E-Wallet',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _ChoiceSpec(
      value: 'card',
      labelId: 'Kartu',
      labelEn: 'Card',
      icon: Icons.credit_card_rounded,
    ),
  ];
  static const List<_ChoiceSpec> _categoryChoices = [
    _ChoiceSpec(
      value: 'food',
      labelId: 'Makanan',
      labelEn: 'Food',
      icon: Icons.restaurant_rounded,
    ),
    _ChoiceSpec(
      value: 'transport',
      labelId: 'Transport',
      labelEn: 'Transport',
      icon: Icons.directions_car_rounded,
    ),
    _ChoiceSpec(
      value: 'bills',
      labelId: 'Tagihan',
      labelEn: 'Bills',
      icon: Icons.receipt_long_rounded,
    ),
    _ChoiceSpec(
      value: 'shopping',
      labelId: 'Belanja',
      labelEn: 'Shopping',
      icon: Icons.shopping_bag_rounded,
    ),
  ];
  static const List<_IntroFeatureSpec> _introFeatures = [
    _IntroFeatureSpec(
      icon: Icons.language_rounded,
      titleId: 'Preferensi lokal',
      titleEn: 'Local preferences',
      subtitleId:
          'Bahasa dan mata uang mengikuti kebiasaan kamu mencatat uang.',
      subtitleEn: 'Language and currency follow the way you record money.',
    ),
    _IntroFeatureSpec(
      icon: Icons.account_balance_wallet_rounded,
      titleId: 'Default harian',
      titleEn: 'Daily defaults',
      subtitleId: 'Dompet utama dan kategori favorit siap dari awal.',
      subtitleEn: 'Your main wallet and category are ready from the start.',
    ),
    _IntroFeatureSpec(
      icon: Icons.flag_rounded,
      titleId: 'Target opsional',
      titleEn: 'Optional goal',
      subtitleId: 'Tambahkan target tabungan pertama sekarang atau nanti.',
      subtitleEn: 'Add a first savings target now or keep it for later.',
    ),
  ];

  int _step = 0;
  String _language = 'id';
  String _currency = 'IDR';
  String _wallet = 'cash';
  String _category = 'food';
  final TextEditingController _openingBalanceController =
      TextEditingController();
  final TextEditingController _goalAmountController = TextEditingController();
  final TextEditingController _goalLabelController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _language = widget.settings.languageCode;
    _currency = widget.settings.currencyCode;
  }

  @override
  void dispose() {
    _openingBalanceController.dispose();
    _goalAmountController.dispose();
    _goalLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.height < 760 || screenSize.width < 380;
    final horizontalPadding = screenSize.width < 390
        ? AppUiTokens.space6
        : AppUiTokens.space8;

    return Scaffold(
      backgroundColor: _pageBackgroundColor(context),
      body: Container(
        decoration: BoxDecoration(gradient: _pageGradient(context)),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? AppUiTokens.space5 : AppUiTokens.space6,
                  horizontalPadding,
                  AppUiTokens.space6,
                ),
                child: Column(
                  children: [
                    _buildHeader(isEn),
                    SizedBox(
                      height: compact ? AppUiTokens.space5 : AppUiTokens.space8,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppAnimations.normal,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Align(
                          key: ValueKey(_step),
                          alignment: Alignment.topCenter,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: _maxContentWidth,
                                minHeight:
                                    constraints.maxHeight -
                                    (compact ? 132 : 152),
                              ),
                              child: _buildStep(isEn),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: compact ? AppUiTokens.space4 : AppUiTokens.space6,
                    ),
                    _buildActions(isEn),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEn) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stepLabel = isEn
        ? 'Step ${_step + 1} of $_stepCount'
        : 'Langkah ${_step + 1} dari $_stepCount';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppUiTokens.surfaceDarkCard
                      : AppUiTokens.white,
                  borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
                  border: Border.all(color: _borderColor(context)),
                  boxShadow: [
                    BoxShadow(
                      color: AppUiTokens.black.withValues(
                        alpha: isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(7),
                child: Image.asset(_appIconAsset, fit: BoxFit.contain),
              ),
              const SizedBox(width: AppUiTokens.space5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CatatUang',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: AppUiTokens.textXl,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isEn
                          ? 'Personal finance setup'
                          : 'Setup keuangan pribadi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.62),
                        fontSize: AppUiTokens.textSm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUiTokens.space5,
                  vertical: AppUiTokens.space3,
                ),
                decoration: BoxDecoration(
                  color: _softSurfaceColor(context),
                  borderRadius: BorderRadius.circular(AppUiTokens.radiusFull),
                  border: Border.all(color: _borderColor(context)),
                ),
                child: Text(
                  stepLabel,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    fontSize: AppUiTokens.textXs,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUiTokens.space6),
          _buildProgress(isEn),
        ],
      ),
    );
  }

  Widget _buildProgress(bool isEn) {
    return Semantics(
      label: isEn
          ? 'Onboarding progress, step ${_step + 1} of $_stepCount'
          : 'Progress onboarding, langkah ${_step + 1} dari $_stepCount',
      value: '${((_step + 1) / _stepCount * 100).round()}%',
      child: Row(
        children: List.generate(_stepCount, (index) {
          final active = index <= _step;
          final current = index == _step;
          return Expanded(
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              height: current ? 7 : 5,
              margin: EdgeInsets.only(
                right: index == _stepCount - 1 ? 0 : AppUiTokens.space3,
              ),
              decoration: BoxDecoration(
                color: active
                    ? AppUiTokens.brandBlue
                    : _borderColor(context).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppUiTokens.radiusFull),
                boxShadow: current
                    ? [
                        BoxShadow(
                          color: AppUiTokens.brandBlue.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActions(bool isEn) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
      child: Column(
        children: [
          Row(
            children: [
              if (_step > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _step -= 1),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(isEn ? 'Back' : 'Kembali'),
                  ),
                ),
                const SizedBox(width: AppUiTokens.space4),
              ],
              Expanded(
                flex: _step > 0 ? 1 : 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _onNext,
                  icon: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppUiTokens.white,
                          ),
                        )
                      : Icon(
                          _step == _stepCount - 1
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _step == _stepCount - 1
                        ? (isEn ? 'Finish' : 'Selesai')
                        : (isEn ? 'Next' : 'Lanjut'),
                  ),
                ),
              ),
            ],
          ),
          if (_step != _stepCount - 1) ...[
            const SizedBox(height: AppUiTokens.space3),
            TextButton(
              onPressed: _saving ? null : _finishOnboarding,
              child: Text(isEn ? 'Skip for now' : 'Lewati dulu'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(bool isEn) {
    switch (_step) {
      case 0:
        return _buildIntro(isEn);
      case 1:
        return _buildLanguageCurrency(isEn);
      case 2:
        return _buildPrimarySetup(isEn);
      default:
        return _buildGoalStep(isEn);
    }
  }

  Widget _buildIntro(bool isEn) {
    return _stepShell(
      badge: isEn ? 'Quick Setup' : 'Setup Cepat',
      icon: Icons.auto_awesome_rounded,
      accent: AppUiTokens.brandBlue,
      title: isEn ? 'Start with tidy records' : 'Mulai catat dengan rapi',
      subtitle: isEn
          ? 'Set your defaults once so every transaction feels faster and tidier.'
          : 'Atur preferensi utama sekali saja supaya pencatatan harian lebih cepat dan rapi.',
      child: Column(children: _buildIntroFeatureList(isEn)),
    );
  }

  Widget _buildLanguageCurrency(bool isEn) {
    return _stepShell(
      badge: isEn ? 'Preferences' : 'Preferensi',
      icon: Icons.tune_rounded,
      accent: AppUiTokens.brandBlueSoft,
      title: isEn ? 'Language & Currency' : 'Bahasa & Mata Uang',
      subtitle: isEn
          ? 'Choose the interface language and the money format used across the app.'
          : 'Pilih bahasa antarmuka dan format uang yang dipakai di seluruh aplikasi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(isEn ? 'Language' : 'Bahasa'),
          const SizedBox(height: AppUiTokens.space3),
          _choiceWrap(
            children: _buildChoiceChips(
              choices: _languageChoices,
              selectedValue: _language,
              isEn: isEn,
              onSelected: (value) => _language = value,
            ),
          ),
          const SizedBox(height: AppUiTokens.space8),
          _sectionLabel(isEn ? 'Currency' : 'Mata Uang'),
          const SizedBox(height: AppUiTokens.space3),
          _choiceWrap(
            children: _buildChoiceChips(
              choices: _currencyChoices,
              selectedValue: _currency,
              isEn: isEn,
              onSelected: (value) => _currency = value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimarySetup(bool isEn) {
    return _stepShell(
      badge: isEn ? 'Defaults' : 'Default',
      icon: Icons.dashboard_customize_rounded,
      accent: AppUiTokens.success,
      title: isEn ? 'Daily Defaults' : 'Default Harian',
      subtitle: isEn
          ? 'Pick the wallet and expense category you use most often.'
          : 'Pilih dompet dan kategori pengeluaran yang paling sering dipakai.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(isEn ? 'Primary wallet' : 'Dompet utama'),
          const SizedBox(height: AppUiTokens.space3),
          _choiceWrap(
            children: _buildChoiceChips(
              choices: _walletChoices,
              selectedValue: _wallet,
              isEn: isEn,
              onSelected: (value) => _wallet = value,
            ),
          ),
          const SizedBox(height: AppUiTokens.space8),
          TextField(
            controller: _openingBalanceController,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandSeparatorFormatter()],
            decoration: _inputDecoration(
              label: isEn ? 'Opening balance' : 'Saldo awal',
              hint: isEn
                  ? 'Current balance in this wallet'
                  : 'Saldo dompet saat mulai pakai',
              icon: Icons.savings_rounded,
            ),
          ),
          const SizedBox(height: AppUiTokens.space8),
          _sectionLabel(
            isEn ? 'Favorite expense category' : 'Kategori pengeluaran favorit',
          ),
          const SizedBox(height: AppUiTokens.space3),
          _choiceWrap(
            children: _buildChoiceChips(
              choices: _categoryChoices,
              selectedValue: _category,
              isEn: isEn,
              onSelected: (value) => _category = value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep(bool isEn) {
    return _stepShell(
      badge: isEn ? 'Optional' : 'Opsional',
      icon: Icons.flag_rounded,
      accent: AppUiTokens.warning,
      title: isEn ? 'Savings Goal' : 'Target Tabungan',
      subtitle: isEn
          ? 'Create one clear target now, or leave it empty and add it later.'
          : 'Buat satu target yang jelas sekarang, atau kosongkan dan tambahkan nanti.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _goalLabelController,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration(
              label: isEn ? 'Goal name' : 'Nama target',
              hint: isEn
                  ? 'Vacation, emergency fund, new laptop'
                  : 'Liburan, dana darurat, laptop baru',
              icon: Icons.edit_note_rounded,
            ),
          ),
          const SizedBox(height: AppUiTokens.space6),
          TextField(
            controller: _goalAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandSeparatorFormatter()],
            decoration: _inputDecoration(
              label: isEn ? 'Target amount' : 'Nominal target',
              hint: isEn ? 'Amount to save' : 'Nominal yang ingin dicapai',
              icon: Icons.savings_rounded,
            ),
          ),
          const SizedBox(height: AppUiTokens.space8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppUiTokens.space6),
            decoration: BoxDecoration(
              color: _softSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
              border: Border.all(color: _borderColor(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppUiTokens.space4),
                Expanded(
                  child: Text(
                    isEn
                        ? 'Leaving this blank will not block setup.'
                        : 'Dikosongkan juga tidak apa-apa, setup tetap bisa selesai.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                      fontSize: AppUiTokens.textSm,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
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

  Widget _stepShell({
    required String badge,
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedFadeSlide(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppUiTokens.space8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppUiTokens.radiusXl),
          border: Border.all(color: _borderColor(context)),
          boxShadow: [
            BoxShadow(
              color: AppUiTokens.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
                    border: Border.all(
                      color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(width: AppUiTokens.space6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppUiTokens.space5,
                        vertical: AppUiTokens.space3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.14 : 0.09),
                        borderRadius: BorderRadius.circular(
                          AppUiTokens.radiusFull,
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: isDark ? 0.25 : 0.18),
                        ),
                      ),
                      child: Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppUiTokens.textXs,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppUiTokens.space8),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
                height: 1.12,
              ),
            ),
            const SizedBox(height: AppUiTokens.space4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppUiTokens.textLg,
                color: scheme.onSurface.withValues(alpha: 0.66),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppUiTokens.space10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _introFeature({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _softSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppUiTokens.radiusSm),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Icon(icon, color: scheme.primary, size: 18),
        ),
        const SizedBox(width: AppUiTokens.space5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: AppUiTokens.textLg,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                  fontSize: AppUiTokens.textSm,
                  fontWeight: FontWeight.w600,
                  height: 1.32,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: AppUiTokens.textSm,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.74),
      ),
    );
  }

  Widget _choiceWrap({required List<Widget> children}) {
    return Wrap(
      spacing: AppUiTokens.space4,
      runSpacing: AppUiTokens.space4,
      children: children,
    );
  }

  List<Widget> _buildIntroFeatureList(bool isEn) {
    final children = <Widget>[];
    for (final feature in _introFeatures) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppUiTokens.space4));
      }
      children.add(
        _introFeature(
          icon: feature.icon,
          title: feature.title(isEn),
          subtitle: feature.subtitle(isEn),
        ),
      );
    }
    return children;
  }

  List<Widget> _buildChoiceChips({
    required List<_ChoiceSpec> choices,
    required String selectedValue,
    required bool isEn,
    required ValueChanged<String> onSelected,
  }) {
    return choices
        .map(
          (choice) => _choiceChip(
            label: choice.label(isEn),
            icon: choice.icon,
            selected: selectedValue == choice.value,
            onTap: () {
              if (selectedValue == choice.value) return;
              setState(() => onSelected(choice.value));
            },
          ),
        )
        .toList(growable: false);
  }

  Widget _choiceChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark
        ? AppUiTokens.brandBlueSoft
        : AppUiTokens.brandBlueDark;
    final foreground = selected
        ? selectedColor
        : scheme.onSurface.withValues(alpha: 0.68);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressableScale(
        borderRadius: BorderRadius.circular(AppUiTokens.radiusFull),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppUiTokens.space5,
            vertical: AppUiTokens.space4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppUiTokens.brandBlue.withValues(alpha: isDark ? 0.20 : 0.08)
                : _softSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppUiTokens.radiusFull),
            border: Border.all(
              color: selected
                  ? AppUiTokens.brandBlueBorderStrong
                  : _borderColor(context),
              width: selected ? 1.25 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: AppUiTokens.space3),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppUiTokens.textSm,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppUiTokens.space3),
                Icon(Icons.check_circle_rounded, size: 14, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18),
    );
  }

  LinearGradient _pageGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const LinearGradient(
        colors: [Color(0xFF0B1220), Color(0xFF111827)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFFF8FAFC), AppUiTokens.surfaceBlueSoft],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  Color _pageBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppUiTokens.surfaceAppDark
        : AppUiTokens.surfaceAppLight;
  }

  Color _softSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F172A)
        : AppUiTokens.surfaceSoft;
  }

  Color _borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF263244)
        : AppUiTokens.borderSoft;
  }

  Future<void> _onNext() async {
    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
      return;
    }
    await _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final openingBalance = _parseUnsignedInt(_openingBalanceController);
      final goalAmount = _parseUnsignedInt(_goalAmountController);
      final settingsUpdates = <Future<void>>[];
      if (widget.settings.languageCode != _language) {
        settingsUpdates.add(widget.settings.setLanguage(_language));
      }
      if (widget.settings.currencyCode != _currency) {
        settingsUpdates.add(widget.settings.setCurrency(_currency));
      }
      await Future.wait(settingsUpdates);

      final masterData = MasterDataService.instance;
      await masterData.ensureMasterContains(
        wallet: _wallet,
        category: _category,
        isExpense: true,
      );
      if (openingBalance > 0) {
        await masterData.setOpeningBalance(
          wallet: _wallet,
          amount: openingBalance,
        );
      }

      final completionTasks = <Future<void>>[
        OnboardingService.instance.markCompleted(
          primaryWallet: _wallet,
          primaryCategory: _category,
        ),
      ];
      if (goalAmount > 0) {
        completionTasks.add(
          SavingsGoalService.instance.save(
            targetAmount: goalAmount,
            label: _goalLabelController.text.trim(),
          ),
        );
      }
      await Future.wait(completionTasks);

      await AnalyticsService.instance.track(
        'onboarding_finished',
        properties: {
          'language': _language,
          'currency': _currency,
          'wallet': _wallet,
          'category': _category,
          'goal_set': goalAmount > 0,
        },
      );
      if (!mounted) return;
      widget.onDone();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  int _parseUnsignedInt(TextEditingController controller) {
    return int.tryParse(controller.text.replaceAll(_nonDigitPattern, '')) ?? 0;
  }
}

class _ChoiceSpec {
  const _ChoiceSpec({
    required this.value,
    required this.labelId,
    required this.labelEn,
    required this.icon,
  });

  final String value;
  final String labelId;
  final String labelEn;
  final IconData icon;

  String label(bool isEn) => isEn ? labelEn : labelId;
}

class _IntroFeatureSpec {
  const _IntroFeatureSpec({
    required this.icon,
    required this.titleId,
    required this.titleEn,
    required this.subtitleId,
    required this.subtitleEn,
  });

  final IconData icon;
  final String titleId;
  final String titleEn;
  final String subtitleId;
  final String subtitleEn;

  String title(bool isEn) => isEn ? titleEn : titleId;

  String subtitle(bool isEn) => isEn ? subtitleEn : subtitleId;
}
