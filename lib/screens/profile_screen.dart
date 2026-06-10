import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/recurring_bill_store.dart';
import '../data/database_service.dart';
import '../data/transaction_store.dart';
import '../services/app_localizations.dart';
import '../services/app_animations.dart';
import '../services/app_settings.dart';
import '../services/app_ui_tokens.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/app_passcode_service.dart';
import '../services/backup_service.dart';
import '../services/biometric_lock_service.dart';
import '../services/error_log_service.dart';
import '../services/export_report_service.dart';
import '../services/master_data_service.dart';
import '../services/notification_service.dart';
import '../services/recurring_transaction_service.dart';
import '../services/thousand_separator_formatter.dart';
import '../services/user_profile_service.dart';
import '../widgets/category_budget_card.dart';
import 'home/home_formatters.dart';
import 'home/transaction_search_delegate.dart';
import 'profile/profile_tiles.dart';
import 'app_lock_gate.dart';
import 'legal_center_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int _maxAmount = 1000000000;
  bool notifTagihan = true;
  bool notifAnggaran = true;
  bool notifRingkasanHarian = false;
  bool biometricLock = false;
  bool autoBackup = true;
  int budgetLimit = 1000000;
  int budgetThreshold = 80;
  String budgetScopeType = 'all';
  String budgetScopeValue = '';
  int budgetPeriodDays = 0;
  TimeOfDay ringkasanTime = const TimeOfDay(hour: 20, minute: 0);
  bool _backupBusy = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    final profile = UserProfileService.instance;
    final screenHeight = MediaQuery.of(context).size.height;
    final compact = true;
    final veryCompact = screenHeight < 820;

    return SafeArea(
      child: AnimatedFadeSlide(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppUiTokens.space6,
            AppUiTokens.space2,
            AppUiTokens.space6,
            veryCompact ? AppUiTokens.space5 : 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedTabReveal(
                tabIndex: 3,
                delay: const Duration(milliseconds: 20),
                child: _buildHeader(t, settings),
              ),
              const SizedBox(height: AppUiTokens.space2),
              AnimatedTabReveal(
                tabIndex: 3,
                delay: const Duration(milliseconds: 90),
                child: _buildProfileCard(compact: compact, profile: profile),
              ),
              const SizedBox(height: AppUiTokens.space2),
              Expanded(
                child: _buildFixedSettingsLayout(settings, t, compact: compact),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations t, AppSettings settings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          t.t('profile'),
          style: const TextStyle(
            fontSize: AppUiTokens.textDisplay,
            fontWeight: FontWeight.w800,
          ),
        ),
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                showSearch<void>(
                  context: context,
                  delegate: TransactionSearchDelegate(
                    transactions: transactionsNotifier.value,
                    settings: settings,
                    t: t,
                    categoryLabel: homeCategoryLabel,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUiTokens.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppUiTokens.borderSoft),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppUiTokens.brandBlue,
                ),
              ),
            ),
            const SizedBox(width: AppUiTokens.space4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppUiTokens.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppUiTokens.borderSoft),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 18,
                color: AppUiTokens.brandBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileCard({
    required bool compact,
    required UserProfileService profile,
  }) {
    final isEn = AppSettingsScope.of(context).languageCode == 'en';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppUiTokens.space5 : 14,
        vertical: compact ? 7 : AppUiTokens.space6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppUiTokens.brandBlue, AppUiTokens.brandBlueSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 38 : 48,
            height: compact ? 38 : 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppUiTokens.white.withValues(alpha: 0.3),
                  AppUiTokens.white.withValues(alpha: 0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppUiTokens.white.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _profileInitials(profile.displayName, profile.email),
              style: TextStyle(
                color: AppUiTokens.white,
                fontSize: compact ? AppUiTokens.textLg : 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: AppUiTokens.space5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: TextStyle(
                    color: AppUiTokens.white,
                    fontSize: compact ? AppUiTokens.textMd : AppUiTokens.textXl,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (profile.email.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    profile.email,
                    style: TextStyle(
                      color: AppUiTokens.white70,
                      fontSize: compact
                          ? AppUiTokens.textXs
                          : AppUiTokens.textSm,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                SizedBox(height: compact ? 0 : AppUiTokens.space2),
                Text(
                  _memberSinceLabel(profile.memberSince, isEn: isEn),
                  style: TextStyle(
                    color: AppUiTokens.white70,
                    fontSize: compact ? AppUiTokens.textXs : AppUiTokens.textXs,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const ProfileAccentChip(
                label: 'LOCAL',
                color: AppUiTokens.white,
                icon: Icons.shield_moon_rounded,
              ),
              SizedBox(
                height: compact ? AppUiTokens.space2 : AppUiTokens.space3,
              ),
              IconButton(
                onPressed: _showEditNameDialog,
                icon: const Icon(Icons.edit_rounded, color: AppUiTokens.white),
                iconSize: compact ? 13 : 16,
                tooltip: isEn ? 'Edit name' : 'Ubah nama',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _profileInitials(String displayName, String email) {
    final source = displayName.trim().isNotEmpty
        ? displayName.trim()
        : email.trim();
    if (source.isEmpty) return 'CT';
    final words = source
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.length >= 2) {
      return '${words.first[0]}${words[1][0]}'.toUpperCase();
    }
    final compactSource = source.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compactSource.length >= 2) {
      return compactSource.substring(0, 2).toUpperCase();
    }
    return compactSource.isEmpty ? 'CT' : compactSource[0].toUpperCase();
  }

  Future<void> _showEditNameDialog() async {
    final isEn = AppSettingsScope.of(context).languageCode == 'en';
    final profile = UserProfileService.instance;
    final controller = TextEditingController(text: profile.displayName);
    final result = await _showPolishedDialog<bool>(
      title: isEn ? 'Edit display name' : 'Ubah nama tampilan',
      subtitle: isEn
          ? 'Update how your profile appears in the app.'
          : 'Ubah nama yang tampil di seluruh aplikasi.',
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        decoration: _sheetFieldDecoration(
          label: isEn ? 'Display name' : 'Nama tampilan',
          hint: isEn ? 'Your name' : 'Nama kamu',
          icon: Icons.person_rounded,
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(isEn ? 'Cancel' : 'Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(isEn ? 'Save' : 'Simpan'),
        ),
      ],
    );
    if (result != true) return;
    final nextName = controller.text.trim();
    if (nextName.length < 2 || nextName.length > 40) {
      _showAction(
        isEn ? 'Name must be 2-40 characters.' : 'Nama harus 2-40 karakter.',
      );
      return;
    }
    await profile.updateDisplayName(nextName);
    if (mounted) {
      setState(() {});
    }
  }

  String _memberSinceLabel(DateTime date, {required bool isEn}) {
    const idMonths = <String>[
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
    const enMonths = <String>[
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
    final month = (isEn ? enMonths : idMonths)[date.month - 1];
    return isEn
        ? 'Member since $month ${date.year}'
        : 'Member sejak $month ${date.year}';
  }

  Widget _buildFixedSettingsLayout(
    AppSettings settings,
    AppLocalizations t, {
    required bool compact,
  }) {
    return Column(
      children: [
        Expanded(
          child: _buildSettingsSection(
            delay: const Duration(milliseconds: 160),
            title: settings.languageCode == 'en' ? 'Experience' : 'Pengalaman',
            caption: '',
            compact: compact,
            children: [
              ProfileActionTile(
                icon: Icons.language_rounded,
                color: AppUiTokens.brandBlueSoft,
                title: t.t('language'),
                subtitle: settings.languageCode == 'en'
                    ? 'English'
                    : 'Indonesia',
                compact: compact,
                onTap: () => _showSelectionSheet(
                  title: t.t('select_language'),
                  options: const ['Indonesia', 'English'],
                  selected: settings.languageCode == 'en'
                      ? 'English'
                      : 'Indonesia',
                  onSelected: (value) async {
                    await settings.setLanguage(
                      value == 'English' ? 'en' : 'id',
                    );
                  },
                ),
              ),
              ProfileActionTile(
                icon: Icons.palette_rounded,
                color: AppUiTokens.pinkAccent,
                title: t.t('theme'),
                subtitle: _themeLabel(settings.themeMode, t),
                compact: compact,
                onTap: () => _showSelectionSheet(
                  title: t.t('select_theme'),
                  options: [
                    t.t('theme_system'),
                    t.t('theme_light'),
                    t.t('theme_dark'),
                  ],
                  selected: _themeLabel(settings.themeMode, t),
                  onSelected: (value) async {
                    if (value == t.t('theme_light')) {
                      await settings.setTheme(ThemeMode.light);
                    } else if (value == t.t('theme_dark')) {
                      await settings.setTheme(ThemeMode.dark);
                    } else {
                      await settings.setTheme(ThemeMode.system);
                    }
                  },
                ),
              ),
              ProfileActionTile(
                icon: Icons.currency_exchange_rounded,
                color: AppUiTokens.successStrong,
                title: t.t('currency'),
                subtitle: settings.currencyLabel,
                compact: compact,
                onTap: () => _showSelectionSheet(
                  title: t.t('select_currency'),
                  options: const [
                    'IDR (Rp)',
                    'USD (\$)',
                    'SGD (\$)',
                    'MYR (RM)',
                  ],
                  selected: settings.currencyLabel,
                  onSelected: (value) async {
                    if (value.startsWith('USD')) {
                      await settings.setCurrency('USD');
                    } else if (value.startsWith('SGD')) {
                      await settings.setCurrency('SGD');
                    } else if (value.startsWith('MYR')) {
                      await settings.setCurrency('MYR');
                    } else {
                      await settings.setCurrency('IDR');
                    }
                    await NotificationService.instance.syncFromPreferences();
                  },
                ),
              ),
              ProfileActionTile(
                icon: Icons.calendar_month_rounded,
                color: AppUiTokens.warning,
                title: t.t('billing_cycle_start'),
                subtitle: '${t.t('date_label')} ${settings.billingCycleStart}',
                compact: compact,
                onTap: () => _showSelectionSheet(
                  title: t.t('billing_cycle_start'),
                  options: List<String>.generate(
                    31,
                    (i) => '${t.t('date_label')} ${i + 1}',
                  ),
                  selected:
                      '${t.t('date_label')} ${settings.billingCycleStart}',
                  onSelected: (value) async {
                    final day = int.tryParse(
                      value.replaceAll('${t.t('date_label')} ', ''),
                    );
                    if (day != null) {
                      await settings.setBillingCycleStart(day);
                      await NotificationService.instance.syncFromPreferences();
                    }
                  },
                ),
              ),
              ProfileActionTile(
                icon: Icons.schedule_rounded,
                color: AppUiTokens.brandBlue,
                title: t.t('tx_time_input'),
                subtitle: settings.txIncludeTime
                    ? t.t('tx_time_with_time')
                    : t.t('tx_time_date_only'),
                compact: compact,
                onTap: () => _showSelectionSheet(
                  title: t.t('tx_time_input'),
                  options: [t.t('tx_time_with_time'), t.t('tx_time_date_only')],
                  selected: settings.txIncludeTime
                      ? t.t('tx_time_with_time')
                      : t.t('tx_time_date_only'),
                  onSelected: (value) async {
                    await settings.setTxIncludeTime(
                      value == t.t('tx_time_with_time'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _buildSettingsSection(
            delay: const Duration(milliseconds: 210),
            title: settings.languageCode == 'en' ? 'Automation' : 'Otomasi',
            caption: '',
            compact: compact,
            children: [
              ProfileActionTile(
                icon: Icons.notifications_active_rounded,
                color: AppUiTokens.brandBlue,
                title: t.t('notifications'),
                subtitle:
                    '${t.t('recurring_bills')}, ${t.t('budget_limit')}, ${t.t('daily_summary')}',
                compact: compact,
                onTap: _showNotificationSheet,
              ),
              ProfileActionTile(
                icon: Icons.receipt_long_rounded,
                color: AppUiTokens.brandBlueSoft,
                title: t.t('manage_recurring_bills'),
                subtitle: t.t('manage_recurring_bills_desc'),
                compact: compact,
                onTap: _showRecurringBillsManager,
              ),
              ProfileActionTile(
                icon: Icons.dataset_rounded,
                color: AppUiTokens.brandBlueSoft,
                title: t.t('master_data_center'),
                subtitle: t.t('master_data_center_desc'),
                compact: compact,
                onTap: _showMasterDataCenter,
              ),
              ProfileActionTile(
                icon: Icons.file_download_rounded,
                color: AppUiTokens.brandBlueSoft,
                title: t.t('export_reports'),
                subtitle: t.t('export_reports_desc'),
                compact: compact,
                onTap: _showExportReportsSheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _buildSettingsSection(
            delay: const Duration(milliseconds: 260),
            title: settings.languageCode == 'en' ? 'Security' : 'Keamanan',
            caption: '',
            compact: compact,
            children: [
              ProfileActionTile(
                icon: Icons.security_rounded,
                color: AppUiTokens.brandBlue,
                title: t.t('security_backup'),
                subtitle:
                    '${t.t('biometric_lock')}, ${t.t('auto_backup')}, ${t.t('backup_restore')}',
                compact: compact,
                onTap: _showSecuritySheet,
              ),
              ProfileActionTile(
                icon: Icons.gavel_rounded,
                color: AppUiTokens.textMutedDeep,
                title: t.t('legal_privacy'),
                subtitle: t.t('legal_privacy_desc'),
                compact: compact,
                onTap: () => Navigator.push(
                  context,
                  AppAnimations.fadeSlideRoute(const LegalCenterScreen()),
                ),
              ),
            ],
            footer: Center(
              child: SizedBox(
                width: compact ? 160 : 170,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUiTokens.dangerDeep,
                    side: const BorderSide(color: AppUiTokens.dangerSoftBorder),
                    padding: EdgeInsets.symmetric(vertical: compact ? 4 : 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.logout_rounded, size: compact ? 14 : 18),
                  label: Text(
                    t.t('logout'),
                    style: TextStyle(
                      fontSize: compact ? 10.2 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required Duration delay,
    required String title,
    required String caption,
    required bool compact,
    required List<Widget> children,
    Widget? footer,
  }) {
    final tiles = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        tiles.add(const ProfileDivider());
      }
      tiles.add(children[i]);
    }
    return AnimatedTabReveal(
      tabIndex: 3,
      delay: delay,
      child: ProfileSettingsCard(
        children: [
          ProfileSectionLabel(label: title, caption: caption),
          ...tiles,
          if (footer != null) ...[
            const ProfileDivider(),
            ProfileSectionFooter(child: footer),
          ],
        ],
      ),
    );
  }

  Future<void> _showRecurringBillsManager() async {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    await _showPolishedSheet<void>(
      context: context,
      title: t.t('manage_recurring_bills'),
      subtitle: t.locale.languageCode == 'en'
          ? 'Review, edit, or remove bills that repeat every month.'
          : 'Tinjau, ubah, atau hapus tagihan yang berulang setiap bulan.',
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final deleted = await removeDefaultSeedRecurringBills();
                    if (!mounted) return;
                    if (deleted > 0) {
                      await NotificationService.instance.syncFromPreferences();
                    }
                    _showAction(
                      deleted > 0
                          ? t.t('seed_bills_removed')
                          : t.t('seed_bills_not_found'),
                    );
                  },
                  icon: const Icon(Icons.cleaning_services_rounded),
                  label: Text(t.t('remove_seed_bills')),
                ),
                OutlinedButton.icon(
                  onPressed: _showRecurringTransactionManager,
                  icon: const Icon(Icons.repeat_rounded),
                  label: Text(t.t('recurring_tx_manage')),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showRecurringBillForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.t('add_recurring_bill')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<List<RecurringBill>>(
              valueListenable: recurringBillsNotifier,
              builder: (context, bills, _) {
                if (bills.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppUiTokens.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppUiTokens.borderSoft),
                    ),
                    child: Text(
                      t.t('no_bills'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppUiTokens.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: bills.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      final isSample = isDefaultSeedRecurringBill(bill);
                      return PressableScale(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showRecurringBillForm(initial: bill),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppUiTokens.borderSoft),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppUiTokens.brandBlueLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppUiTokens.brandBlue,
                                  size: 18,
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
                                            bill.name,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (isSample)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  AppUiTokens.surfaceBlueSoft,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color:
                                                    AppUiTokens.brandBlueBorder,
                                              ),
                                            ),
                                            child: Text(
                                              t.t('sample_data'),
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color:
                                                    AppUiTokens.brandBlueDark,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (isSample) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        t.t('sample_data_desc'),
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: AppUiTokens.textTertiary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.t('due_date')} ${bill.dueDay}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppUiTokens.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      settings.formatCurrency(bill.amount),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppUiTokens.dangerDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _showRecurringBillForm(initial: bill),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: AppUiTokens.brandBlue,
                                ),
                                tooltip: t.t('edit'),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _confirmDeleteRecurringBill(bill),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: AppUiTokens.dangerStrong,
                                ),
                                tooltip: t.t('delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRecurringBillForm({RecurringBill? initial}) async {
    final t = AppLocalizations.of(context);
    final isEdit = initial != null;
    final nameController = TextEditingController(text: initial?.name ?? '');
    final amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toString(),
    );
    final dueDayController = TextEditingController(
      text: initial == null ? '' : initial.dueDay.toString(),
    );

    final shouldSave = await showModalBottomSheet<bool>(
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
                  textInputAction: TextInputAction.next,
                  decoration: _sheetFieldDecoration(
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
                  textInputAction: TextInputAction.next,
                  decoration: _sheetFieldDecoration(
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
                  textInputAction: TextInputAction.done,
                  decoration: _sheetFieldDecoration(
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

    if (shouldSave != true) return;

    final name = nameController.text.trim();
    final amount =
        int.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final dueDay = int.tryParse(dueDayController.text) ?? 0;
    if (name.length < 2 ||
        name.length > 40 ||
        amount <= 0 ||
        amount > _maxAmount ||
        dueDay < 1 ||
        dueDay > 31) {
      _showAction(t.t('invalid_recurring_bill'));
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
      _showAction(isEdit ? t.t('bill_updated') : t.t('bill_added'));
    } catch (e) {
      await ErrorLogService.instance.log(
        source: 'profile_bill_form_save',
        error: e,
      );
      _showAction('Gagal menyimpan tagihan: $e');
    }
  }

  Future<void> _showRecurringTransactionManager() async {
    final t = AppLocalizations.of(context);
    await _showPolishedSheet<void>(
      context: context,
      title: t.t('recurring_tx_title'),
      subtitle: t.locale.languageCode == 'en'
          ? 'Templates generate transactions when the scheduled date is due.'
          : 'Template akan membuat transaksi saat tanggal jadwalnya sudah jatuh.',
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<List<RecurringTransactionTemplate>>(
              future: RecurringTransactionService.instance.templates(),
              builder: (context, snapshot) {
                final templates =
                    snapshot.data ?? const <RecurringTransactionTemplate>[];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await _showRecurringTransactionForm();
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: Text(t.t('recurring_tx_add')),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final created = await RecurringTransactionService
                                .instance
                                .syncDueTransactions();
                            if (!mounted) return;
                            _showAction(
                              created > 0
                                  ? 'Berhasil membuat $created transaksi rutin.'
                                  : 'Belum ada transaksi rutin yang jatuh pada tanggal hari ini.',
                            );
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Sync sekarang'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppUiTokens.surfaceBlueSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppUiTokens.brandBlueBorder),
                      ),
                      child: const Text(
                        'Template otomatis membuat transaksi saat tanggalnya tiba. Gunakan "Buat sekarang" bila ingin menambahkan transaksi manual saat ini.',
                        style: TextStyle(
                          fontSize: 10.8,
                          color: AppUiTokens.textMutedDeep,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (templates.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppUiTokens.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppUiTokens.borderSoft),
                        ),
                        child: Text(
                          t.t('recurring_tx_empty'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppUiTokens.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: templates.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tpl = templates[index];
                            final amountColor = tpl.isExpense
                                ? AppUiTokens.dangerDark
                                : AppUiTokens.successDeep;
                            return PressableScale(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await _showRecurringTransactionForm(
                                  initial: tpl,
                                );
                                setModalState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  10,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppUiTokens.borderSoft,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: amountColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        tpl.isExpense
                                            ? Icons.north_east_rounded
                                            : Icons.south_west_rounded,
                                        size: 18,
                                        color: amountColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tpl.name,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Tanggal ${tpl.dayOfMonth} | ${tpl.wallet} | ${tpl.category}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppUiTokens.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            AppSettingsScope.of(
                                              context,
                                            ).formatCurrency(tpl.amount),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: amountColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await RecurringTransactionService
                                            .instance
                                            .createNow(tpl);
                                        if (!mounted) return;
                                        _showAction(
                                          'Transaksi manual berhasil dibuat dari template.',
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.flash_on_rounded,
                                        size: 18,
                                        color: AppUiTokens.warning,
                                      ),
                                      tooltip: 'Buat sekarang',
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await _showRecurringTransactionForm(
                                          initial: tpl,
                                        );
                                        setModalState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        size: 18,
                                        color: AppUiTokens.brandBlue,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await RecurringTransactionService
                                            .instance
                                            .deleteTemplate(tpl.id);
                                        setModalState(() {});
                                        if (!mounted) return;
                                        _showAction(
                                          t.t('recurring_tx_deleted'),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppUiTokens.dangerStrong,
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
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showRecurringTransactionForm({
    RecurringTransactionTemplate? initial,
  }) async {
    final t = AppLocalizations.of(context);
    final isEdit = initial != null;
    final wallets = await MasterDataService.instance.wallets();
    final expenseCategories = await MasterDataService.instance
        .expenseCategories();
    final incomeCategories = await MasterDataService.instance
        .incomeCategories();
    final nameController = TextEditingController(text: initial?.name ?? '');
    final amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toString(),
    );
    final dayController = TextEditingController(
      text: initial == null ? '' : initial.dayOfMonth.toString(),
    );
    final noteController = TextEditingController(text: initial?.note ?? '');
    var isExpense = initial?.isExpense ?? true;
    var categories = isExpense ? expenseCategories : incomeCategories;
    var wallet = initial?.wallet ?? (wallets.isEmpty ? 'cash' : wallets.first);
    var category =
        initial?.category ?? (categories.isEmpty ? 'food' : categories.first);
    if (!wallets.contains(wallet) && wallets.isNotEmpty) {
      wallet = wallets.first;
    }
    if (!categories.contains(category) && categories.isNotEmpty) {
      category = categories.first;
    }
    if (!mounted) return;

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    colors: [
                      AppUiTokens.surfaceGradientStart,
                      AppUiTokens.white,
                    ],
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
                    Text(
                      isEdit
                          ? t.t('recurring_tx_edit')
                          : t.t('recurring_tx_add'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppUiTokens.surfaceBlueSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppUiTokens.brandBlueBorder),
                      ),
                      child: const Text(
                        'Template ini tidak selalu langsung membuat transaksi. Transaksi otomatis dibuat saat tanggal yang dipilih sudah tiba.',
                        style: TextStyle(
                          fontSize: 10.8,
                          color: AppUiTokens.textMutedDeep,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: _sheetFieldDecoration(
                        label: t.t('bill_name'),
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandSeparatorFormatter()],
                      decoration: _sheetFieldDecoration(
                        label: t.t('amount'),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: isExpense ? 'expense' : 'income',
                            decoration: _sheetFieldDecoration(
                              label: t.t('recurring_tx_type'),
                              icon: Icons.compare_arrows_rounded,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'expense',
                                child: Text(t.t('recurring_tx_expense')),
                              ),
                              DropdownMenuItem(
                                value: 'income',
                                child: Text(t.t('recurring_tx_income')),
                              ),
                            ],
                            onChanged: (value) {
                              setModalState(() {
                                isExpense = value != 'income';
                                categories = isExpense
                                    ? expenseCategories
                                    : incomeCategories;
                                if (!categories.contains(category) &&
                                    categories.isNotEmpty) {
                                  category = categories.first;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _sheetFieldDecoration(
                              label: t.t('recurring_tx_day'),
                              icon: Icons.calendar_today_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: wallet,
                            decoration: _sheetFieldDecoration(
                              label: t.t('fund_source'),
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            items: wallets
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => wallet = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: _sheetFieldDecoration(
                              label: t.t('category'),
                              icon: Icons.grid_view_rounded,
                            ),
                            items: categories
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => category = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      decoration: _sheetFieldDecoration(
                        label: t.t('add_note'),
                        icon: Icons.sticky_note_2_outlined,
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
      },
    );

    if (shouldSave != true) return;
    final name = nameController.text.trim();
    final note = noteController.text.trim();
    final amount =
        int.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final day = int.tryParse(dayController.text) ?? 0;
    if (name.length < 2 ||
        name.length > 40 ||
        amount <= 0 ||
        amount > _maxAmount ||
        day < 1 ||
        day > 31) {
      _showAction(t.t('invalid_amount'));
      return;
    }
    if (wallet.trim().isEmpty || category.trim().isEmpty) {
      _showAction('Dompet/kategori tidak valid');
      return;
    }
    if (note.length > 140) {
      _showAction('Catatan maksimal 140 karakter');
      return;
    }
    await RecurringTransactionService.instance.upsertTemplate(
      RecurringTransactionTemplate(
        id: initial?.id ?? '',
        name: name,
        isExpense: isExpense,
        amount: amount,
        wallet: wallet,
        category: category,
        dayOfMonth: day,
        note: note,
        active: true,
      ),
    );
    final created = await RecurringTransactionService.instance
        .syncDueTransactions();
    _showAction(
      created > 0 ? ' -  transaksi dibuat' : ' - akan berjalan mulai tanggal ',
    );
  }

  Future<void> _confirmDeleteRecurringBill(RecurringBill bill) async {
    final t = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.t('delete_recurring_bill')),
        content: Text(
          '${t.t('delete_recurring_bill_confirm')} "${bill.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.t('delete')),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await deleteRecurringBill(bill.id);
      await NotificationService.instance.syncFromPreferences();
      _showAction(t.t('bill_deleted'));
    } catch (e) {
      await ErrorLogService.instance.log(
        source: 'profile_bill_delete',
        error: e,
      );
      _showAction('Gagal menghapus tagihan: $e');
    }
  }

  Future<void> _showMasterDataCenter() async {
    final t = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  t.t('master_data_center'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppUiTokens.brandBlue,
                ),
                title: Text(t.t('manage_wallets')),
                subtitle: Text(t.t('manage_wallets_desc')),
                onTap: () async {
                  Navigator.pop(context);
                  await _showMasterListEditor(isWallet: true);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.category_rounded,
                  color: AppUiTokens.brandBlueSoft,
                ),
                title: Text(t.t('manage_expense_categories')),
                subtitle: Text(t.t('manage_expense_categories_desc')),
                onTap: () async {
                  Navigator.pop(context);
                  await _showMasterListEditor(isWallet: false);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.payments_rounded,
                  color: AppUiTokens.successDeep,
                ),
                title: Text(t.t('manage_income_categories')),
                subtitle: Text(t.t('manage_income_categories_desc')),
                onTap: () async {
                  Navigator.pop(context);
                  await _showMasterListEditor(
                    isWallet: false,
                    isIncomeCategory: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.repeat_rounded,
                  color: AppUiTokens.warning,
                ),
                title: Text(t.t('manage_recurring_transactions')),
                subtitle: Text(t.t('manage_recurring_transactions_desc')),
                onTap: () async {
                  Navigator.pop(context);
                  await _showRecurringTransactionManager();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMasterListEditor({
    required bool isWallet,
    bool isIncomeCategory = false,
  }) async {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<List<String>> readItems() {
              if (isWallet) return MasterDataService.instance.wallets();
              return isIncomeCategory
                  ? MasterDataService.instance.incomeCategories()
                  : MasterDataService.instance.expenseCategories();
            }

            Future<void> addItem() async {
              final raw = controller.text.trim();
              if (raw.isEmpty) return;
              if (raw.length < 2 || raw.length > 30) {
                _showAction('Panjang nama harus 2-30 karakter');
                return;
              }
              final normalized = raw.toLowerCase();
              final existing = await readItems();
              final duplicate = existing.any(
                (e) => e.toLowerCase() == normalized,
              );
              if (duplicate) {
                _showAction('Data sudah ada');
                return;
              }
              if (isWallet) {
                await MasterDataService.instance.addWallet(raw);
              } else if (isIncomeCategory) {
                await MasterDataService.instance.addIncomeCategory(raw);
              } else {
                await MasterDataService.instance.addExpenseCategory(raw);
              }
              controller.clear();
              setModalState(() {});
            }

            Future<void> removeItem(String value) async {
              if (isWallet) {
                await MasterDataService.instance.removeWallet(value);
              } else if (isIncomeCategory) {
                await MasterDataService.instance.removeIncomeCategory(value);
              } else {
                await MasterDataService.instance.removeExpenseCategory(value);
              }
              setModalState(() {});
            }

            Future<void> renameItem(String oldValue) async {
              final renameController = TextEditingController(text: oldValue);
              final save = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isWallet
                                ? t.t('rename_wallet')
                                : t.t('rename_category'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: renameController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: isWallet
                                  ? t.t('wallet_name_hint')
                                  : t.t('category_name_hint'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: Text(t.t('cancel')),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
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
              final newName = renameController.text.trim();
              if (newName.isEmpty || newName.length < 2 || newName.length > 30) {
                return;
              }
              bool success;
              if (isWallet) {
                success = await MasterDataService.instance
                    .renameWallet(oldValue, newName);
              } else if (isIncomeCategory) {
                success = await MasterDataService.instance
                    .renameIncomeCategory(oldValue, newName);
              } else {
                success = await MasterDataService.instance
                    .renameExpenseCategory(oldValue, newName);
              }
              if (!success) return;
              // Update all transactions with old category/wallet name
              final txs = transactionsNotifier.value;
              final normalized =
                  MasterDataService.normalizeMasterKey(newName);
              for (final tx in txs) {
                bool needsUpdate = false;
                String updatedWallet = tx.wallet;
                String updatedCategory = tx.category;
                if (isWallet && tx.wallet == oldValue) {
                  updatedWallet = normalized;
                  needsUpdate = true;
                } else if (!isWallet && tx.category == oldValue) {
                  updatedCategory = normalized;
                  needsUpdate = true;
                }
                if (needsUpdate) {
                  await DatabaseService.instance.updateTransaction(
                    id: tx.id,
                    isExpense: tx.isExpense,
                    amount: tx.amount,
                    wallet: updatedWallet,
                    category: updatedCategory,
                    transactionDate: tx.transactionDate,
                    isCleared: tx.isCleared,
                    note: tx.note,
                    receiptPath: tx.receiptPath,
                  );
                }
              }
              await refreshTransactions();
              setModalState(() {});
            }

            Future<void> editOpeningBalance(String wallet) async {
              final current = await MasterDataService.instance
                  .openingBalanceForWallet(wallet);
              final controller = TextEditingController(
                text: current == 0 ? '' : current.toString(),
              );
              final save = await _showPolishedDialog<bool>(
                title: t.t('opening_balance'),
                subtitle: t.t('opening_balance_desc'),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandSeparatorFormatter()],
                  decoration: _sheetFieldDecoration(
                    label: wallet,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(t.t('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t.t('save')),
                  ),
                ],
              );
              if (save != true) return;
              final amount =
                  int.tryParse(
                    controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                  0;
              if (amount < 0 || amount > _maxAmount) {
                _showAction(t.t('invalid_amount'));
                return;
              }
              await MasterDataService.instance.setOpeningBalance(
                wallet: wallet,
                amount: amount,
              );
              setModalState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isWallet
                          ? t.t('manage_wallets')
                          : isIncomeCategory
                          ? t.t('manage_income_categories')
                          : t.t('manage_expense_categories'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: isWallet
                                  ? t.t('wallet_name_hint')
                                  : t.t('category_name_hint'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: addItem,
                          child: Text(t.t('add')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<String>>(
                      future: readItems(),
                      builder: (context, snapshot) {
                        final items = snapshot.data ?? const <String>[];
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isDefault = isWallet
                                  ? MasterDataService.defaultWallets.contains(
                                      item,
                                    )
                                  : isIncomeCategory
                                  ? MasterDataService.defaultIncomeCategories
                                        .contains(item)
                                  : MasterDataService.defaultCategories
                                        .contains(item);
                              final openingBalance = isWallet
                                  ? MasterDataService.instance
                                        .openingBalanceForWalletSync(item)
                                  : 0;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: isWallet
                                    ? Text(
                                        '${t.t('opening_balance')}: ${settings.formatCurrency(openingBalance)}',
                                        style: const TextStyle(fontSize: 10),
                                      )
                                    : Text(
                                        isIncomeCategory
                                            ? t.t('income_category_scope')
                                            : t.t('expense_category_scope'),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isWallet)
                                      IconButton(
                                        tooltip: t.t('opening_balance'),
                                        onPressed: () =>
                                            editOpeningBalance(item),
                                        icon: const Icon(
                                          Icons.savings_outlined,
                                          color: AppUiTokens.brandBlue,
                                        ),
                                      ),
                                    IconButton(
                                      tooltip: isWallet
                                          ? t.t('rename_wallet')
                                          : t.t('rename_category'),
                                      onPressed: isDefault
                                          ? null
                                          : () => renameItem(item),
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: isDefault
                                            ? AppUiTokens.textHint
                                            : AppUiTokens.brandBlueDark,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: isDefault
                                          ? null
                                          : () => removeItem(item),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: isDefault
                                            ? AppUiTokens.textHint
                                            : AppUiTokens.dangerStrong,
                                      ),
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
      },
    );
  }

  Future<void> _showNotificationSheet() async {
    final t = AppLocalizations.of(context);
    final settings = AppSettingsScope.of(context);
    await _showPolishedSheet(
      context: context,
      title: t.t('notifications'),
      subtitle: t.locale.languageCode == 'en'
          ? 'Control reminders and automatic summaries.'
          : 'Atur pengingat dan ringkasan otomatis.',
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ProfileSettingsCard(
              children: [
                ProfileSwitchTile(
                  icon: Icons.notifications_active_rounded,
                  title: t.t('recurring_bills'),
                  subtitle: t.t('recurring_bills_desc'),
                  value: notifTagihan,
                  onChanged: (v) async {
                    setState(() => notifTagihan = v);
                    setSheetState(() {});
                    await _saveBool(NotificationService.keyNotifTagihan, v);
                    if (v) {
                      await NotificationService.instance.scheduleRecurringBills(
                        recurringBillsNotifier.value,
                      );
                    } else {
                      await NotificationService.instance.cancelAllBills();
                    }
                  },
                  compact: true,
                ),
                const ProfileDivider(),
                ProfileSwitchTile(
                  icon: Icons.ssid_chart_rounded,
                  title: t.t('budget_limit'),
                  subtitle: t.t('budget_limit_desc'),
                  value: notifAnggaran,
                  onChanged: (v) async {
                    setState(() => notifAnggaran = v);
                    setSheetState(() {});
                    await _saveBool(NotificationService.keyNotifAnggaran, v);
                    if (v) {
                      await NotificationService.instance.syncFromPreferences();
                    } else {
                      await NotificationService.instance.cancel(
                        NotificationService.idAnggaranHarian,
                      );
                    }
                  },
                  compact: true,
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.tune_rounded,
                  color: AppUiTokens.brandBlueDark,
                  title: t.t('budget_settings'),
                  subtitle:
                      '${t.t('budget_limit')} ${settings.formatCurrency(budgetLimit)}',
                  compact: true,
                  onTap: _showBudgetSheet,
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.pie_chart_rounded,
                  color: AppUiTokens.brandBlueSoft,
                  title: t.t('budget_per_category'),
                  subtitle: t.t('category_budget'),
                  compact: true,
                  onTap: () => showCategoryBudgetSheet(context),
                ),
                const ProfileDivider(),
                ProfileSwitchTile(
                  icon: Icons.today_rounded,
                  title: t.t('daily_summary'),
                  subtitle: t.t('daily_summary_desc'),
                  value: notifRingkasanHarian,
                  onChanged: (v) async {
                    setState(() => notifRingkasanHarian = v);
                    setSheetState(() {});
                    await _saveBool(NotificationService.keyNotifRingkasan, v);
                    if (v) {
                      await NotificationService.instance.scheduleDaily(
                        id: NotificationService.idRingkasanHarian,
                        title: t.t('daily_summary'),
                        body: t.t('daily_summary_body'),
                        time: ringkasanTime,
                      );
                    } else {
                      await NotificationService.instance.cancel(
                        NotificationService.idRingkasanHarian,
                      );
                    }
                  },
                  compact: true,
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.access_time_rounded,
                  color: AppUiTokens.brandBlueSoft,
                  title: t.t('summary_time'),
                  subtitle: ringkasanTime.format(context),
                  compact: true,
                  onTap: _pickRingkasanTime,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSecuritySheet() async {
    final t = AppLocalizations.of(context);
    await _showPolishedSheet(
      context: context,
      title: t.t('security_backup'),
      subtitle: t.locale.languageCode == 'en'
          ? 'Protect access, backup data, and restore safely.'
          : 'Lindungi akses, backup data, dan restore dengan aman.',
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ProfileSettingsCard(
              children: [
                ProfileSwitchTile(
                  icon: Icons.fingerprint_rounded,
                  title: t.t('biometric_lock'),
                  subtitle: t.t('biometric_lock_desc'),
                  value: biometricLock,
                  onChanged: (v) async {
                    setState(() => biometricLock = v);
                    setSheetState(() {});
                    await _saveBool(BiometricLockService.keyBiometricLock, v);
                  },
                  compact: true,
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.pin_rounded,
                  color: AppUiTokens.brandBlueSoft,
                  title: t.t('security_pin'),
                  subtitle: t.t('security_pin_desc'),
                  compact: true,
                  onTap: _showPasscodeSheet,
                ),
                const ProfileDivider(),
                ProfileSwitchTile(
                  icon: Icons.backup_rounded,
                  title: t.t('auto_backup'),
                  subtitle: t.t('auto_backup_desc'),
                  value: autoBackup,
                  onChanged: (v) async {
                    setState(() => autoBackup = v);
                    setSheetState(() {});
                    await _saveBool(BackupService.keyAutoBackup, v);
                    if (v) {
                      await BackupService.instance.autoBackupIfDue();
                    }
                  },
                  compact: true,
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.sync_rounded,
                  color: AppUiTokens.brandBlue,
                  title: t.t('backup_restore'),
                  subtitle: t.t('backup_restore_desc'),
                  compact: true,
                  onTap: _showBackupRestoreSheet,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPasscodeSheet() async {
    final t = AppLocalizations.of(context);
    final hasPin = await AppPasscodeService.instance.hasPasscode();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  t.t('security_pin'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppUiTokens.brandBlue,
                ),
                title: Text(hasPin ? t.t('change_pin') : t.t('create_pin')),
                subtitle: Text(t.t('pin_4_6_digits')),
                onTap: () async {
                  Navigator.pop(context);
                  await _showSetPasscodeDialog();
                },
              ),
              if (hasPin)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppUiTokens.dangerStrong,
                  ),
                  title: Text(t.t('remove_pin')),
                  subtitle: Text(t.t('remove_pin_desc')),
                  onTap: () async {
                    Navigator.pop(context);
                    await AppPasscodeService.instance.disablePasscode();
                    if (!mounted) return;
                    _showAction(t.t('pin_removed'));
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSetPasscodeDialog() async {
    final t = AppLocalizations.of(context);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final save = await _showPolishedDialog<bool>(
      title: t.t('security_pin'),
      subtitle: t.locale.languageCode == 'en'
          ? 'Create a 4-6 digit PIN as a fallback unlock method.'
          : 'Buat PIN 4-6 digit sebagai metode buka cadangan.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: pinController,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _sheetFieldDecoration(
              label: t.t('create_pin'),
              icon: Icons.pin_rounded,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: confirmController,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _sheetFieldDecoration(
              label: t.t('confirm_pin'),
              icon: Icons.verified_user_rounded,
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(t.t('save')),
        ),
      ],
    );
    if (save != true) return;
    final pin = pinController.text.trim();
    final confirm = confirmController.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      _showAction(t.t('pin_4_6_digits'));
      return;
    }
    if (pin != confirm) {
      _showAction(t.t('pin_not_match'));
      return;
    }
    try {
      await AppPasscodeService.instance.setPasscode(pin);
      _showAction(t.t('pin_saved'));
    } catch (e) {
      _showAction('$e');
    }
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T?> _showPolishedDialog<T>({
    required String title,
    String? subtitle,
    required Widget child,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppUiTokens.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                child,
                if (actions != null && actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        Expanded(child: actions[i]),
                        if (i < actions.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _sheetFieldDecoration({
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

  Future<void> _showExportReportsSheet() async {
    final t = AppLocalizations.of(context);
    var selectedPeriod = 'month';
    await _showPolishedSheet<void>(
      context: context,
      title: t.t('export_reports'),
      subtitle: t.locale.languageCode == 'en'
          ? 'Choose a period and export the current records.'
          : 'Pilih periode lalu ekspor catatan yang aktif.',
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedPeriod,
                  decoration: _sheetFieldDecoration(
                    label: t.t('period'),
                    icon: Icons.date_range_rounded,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'month',
                      child: Text(t.t('this_month')),
                    ),
                    DropdownMenuItem(
                      value: 'days30',
                      child: Text(t.t('days_30')),
                    ),
                    DropdownMenuItem(
                      value: 'year',
                      child: Text(t.t('this_year')),
                    ),
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(t.t('all_time')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => selectedPeriod = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _exportReport(
                            format: 'csv',
                            period: selectedPeriod,
                          );
                        },
                        icon: const Icon(Icons.table_chart_rounded),
                        label: Text(
                          t.locale.languageCode == 'en'
                              ? 'Full CSV'
                              : 'CSV Lengkap',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _exportReport(
                            format: 'pdf',
                            period: selectedPeriod,
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(
                          t.locale.languageCode == 'en'
                              ? 'Summary PDF'
                              : 'PDF Ringkasan',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportReport({
    required String format,
    required String period,
  }) async {
    final txs = transactionsNotifier.value;
    final (start, endExclusive) = _resolvePeriodRange(period);
    try {
      String path;
      if (format == 'pdf') {
        path = await ExportReportService.instance.exportPdf(
          transactions: txs,
          start: start,
          endExclusive: endExclusive,
        );
      } else {
        path = await ExportReportService.instance.exportCsv(
          transactions: txs,
          start: start,
          endExclusive: endExclusive,
        );
      }
      await AnalyticsService.instance.track(
        'export_report',
        properties: {'format': format, 'period': period, 'count': txs.length},
      );
      if (!mounted) return;
      _showAction('Export berhasil: $path');
    } catch (e) {
      await ErrorLogService.instance.log(source: 'export_report', error: e);
      if (!mounted) return;
      _showAction('Export gagal: $e');
    }
  }

  (DateTime, DateTime) _resolvePeriodRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'year':
        return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
      case 'days30':
        final start = DateUtils.dateOnly(
          now,
        ).subtract(const Duration(days: 29));
        return (start, DateUtils.dateOnly(now).add(const Duration(days: 1)));
      case 'all':
        return (DateTime(2020, 1, 1), DateTime(now.year + 1, 1, 1));
      case 'month':
      default:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1),
        );
    }
  }

  Future<void> _backupNow() async {
    await _runBackupTask(() async {
      final path = await BackupService.instance.backupNow();
      await AnalyticsService.instance.track('backup_success');
      if (!mounted) return;
      _showAction('Backup berhasil: $path');
    });
  }

  Future<void> _exportBackupKey() async {
    final approved = await _showPolishedDialog<bool>(
      title: 'Export Kunci Backup',
      subtitle:
          'Kunci ini dipakai untuk membuka backup terenkripsi di perangkat lain.',
      child: const Text(
        'Simpan file dan token di tempat aman. Siapa pun yang punya kunci ini dapat membuka backup kamu.',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Lanjut'),
        ),
      ],
    );
    if (approved != true) return;
    await _runBackupTask(() async {
      final path = await BackupService.instance.exportEncryptionKeyToFile();
      final token = await BackupService.instance.exportEncryptionKeyToken();
      await Clipboard.setData(ClipboardData(text: token));
      if (!mounted) return;
      _showAction('Kunci backup diekspor: $path (token disalin ke clipboard)');
    });
  }

  Future<void> _importBackupKeyFromFile() async {
    await _runBackupTask(() async {
      try {
        final imported = await BackupService.instance
            .importEncryptionKeyFromFile();
        if (!mounted) return;
        if (imported) {
          final valid = await BackupService.instance
              .validateCurrentKeyForLatestEncryptedBackup();
          if (valid == false) {
            _showAction(
              'Kunci diimpor, tapi tidak cocok dengan backup terbaru.',
            );
          } else {
            _showAction('Kunci backup berhasil diimpor dari file');
          }
        } else {
          _showAction('File kunci backup tidak ditemukan');
        }
      } catch (e) {
        await ErrorLogService.instance.log(
          source: 'backup_key_import_file',
          error: e,
        );
        if (!mounted) return;
        _showAction('Import kunci gagal: $e');
      }
    });
  }

  Future<void> _showImportKeyTokenDialog() async {
    final controller = TextEditingController();
    final token = await _showPolishedDialog<String>(
      title: 'Import Kunci Backup',
      subtitle:
          'Tempel token dari perangkat lama untuk membuka backup terenkripsi.',
      child: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: _sheetFieldDecoration(
          label: 'Token kunci',
          hint: 'Tempel token kunci backup',
          icon: Icons.key_rounded,
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Import'),
        ),
      ],
    );

    if (token == null) return;
    await _runBackupTask(() async {
      try {
        await BackupService.instance.importEncryptionKeyFromToken(token);
        if (!mounted) return;
        final valid = await BackupService.instance
            .validateCurrentKeyForLatestEncryptedBackup();
        if (valid == false) {
          _showAction(
            'Kunci berhasil diimpor, tapi tidak cocok dengan backup terbaru.',
          );
        } else {
          _showAction('Kunci backup berhasil diimpor');
        }
      } catch (e) {
        await ErrorLogService.instance.log(
          source: 'backup_key_import_token',
          error: e,
        );
        if (!mounted) return;
        _showAction('Token tidak valid: $e');
      }
    });
  }

  Future<void> _showBackupRestoreSheet() async {
    await _showPolishedSheet<void>(
      context: context,
      title: AppLocalizations.of(context).t('backup_restore'),
      subtitle: AppLocalizations.of(context).locale.languageCode == 'en'
          ? 'Create a backup, restore, or move the encryption key.'
          : 'Buat backup, restore, atau pindahkan kunci enkripsi.',
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<DateTime?>(
              future: BackupService.instance.lastBackupAt(),
              builder: (context, snapshot) {
                final t = AppLocalizations.of(context);
                final date = snapshot.data;
                final label = date == null
                    ? t.t('backup_never')
                    : '${t.t('backup_last')}: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppUiTokens.surfaceBlueSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppUiTokens.brandBlueBorder),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppUiTokens.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ProfileSettingsCard(
              children: [
                ProfileActionTile(
                  icon: Icons.backup_rounded,
                  color: AppUiTokens.brandBlue,
                  title: 'Backup sekarang',
                  subtitle: 'Simpan salinan data terbaru',
                  compact: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await _backupNow();
                  },
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.restore_rounded,
                  color: AppUiTokens.brandBlueSoft,
                  title: 'Restore dari backup',
                  subtitle: 'Pulihkan data dari backup terakhir',
                  compact: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await _restoreBackup();
                  },
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.key_rounded,
                  color: AppUiTokens.warning,
                  title: 'Export kunci backup',
                  subtitle: 'Simpan file kunci + salin token ke clipboard',
                  compact: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportBackupKey();
                  },
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.file_download_rounded,
                  color: AppUiTokens.brandBlueSoft,
                  title: 'Import kunci dari file',
                  subtitle: 'Gunakan file kunci backup lokal terbaru',
                  compact: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await _importBackupKeyFromFile();
                  },
                ),
                const ProfileDivider(),
                ProfileActionTile(
                  icon: Icons.content_paste_rounded,
                  color: AppUiTokens.brandBlue,
                  title: 'Import kunci dari token',
                  subtitle: 'Tempel token kunci backup dari perangkat lama',
                  compact: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await _showImportKeyTokenDialog();
                  },
                ),
              ],
            ),
            if (_backupBusy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _restoreBackup() async {
    final allowed = await BiometricLockService.instance
        .authenticateForSensitiveAction(
          reason: 'Verifikasi biometrik untuk proses restore backup',
        );
    if (!allowed) {
      if (!mounted) return;
      _showAction('Verifikasi biometrik gagal. Restore dibatalkan.');
      return;
    }
    if (!mounted) return;

    final shouldRestore = await _showPolishedDialog<bool>(
      title: 'Restore Data',
      subtitle: 'Aksi ini akan mengganti data yang ada sekarang.',
      child: const Text(
        'Gunakan hanya jika backup terakhir memang yang ingin dipulihkan.',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Restore'),
        ),
      ],
    );
    if (shouldRestore != true) return;

    final restored = await BackupService.instance.restoreFromLatestBackup();
    if (!mounted) return;
    if (restored) {
      await AnalyticsService.instance.track('restore_success');
      _showAction('Restore berhasil');
    } else {
      _showAction('Backup tidak ditemukan');
    }
  }

  Future<void> _runBackupTask(Future<void> Function() task) async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      await task();
    } finally {
      if (mounted) {
        setState(() => _backupBusy = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final t = AppLocalizations.of(context);
    final shouldLogout = await _showPolishedDialog<bool>(
      title: t.t('logout'),
      subtitle: t.locale.languageCode == 'en'
          ? 'You will need to unlock or sign in again to continue.'
          : 'Kamu perlu membuka kunci atau masuk lagi untuk melanjutkan.',
      child: Text(
        t.t('logout_action'),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.t('logout')),
        ),
      ],
    );

    if (shouldLogout == true && mounted) {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppAnimations.fadeSlideRoute(const AppLockGate()),
        (_) => false,
      );
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notifTagihan =
          prefs.getBool(NotificationService.keyNotifTagihan) ?? notifTagihan;
      notifAnggaran =
          prefs.getBool(NotificationService.keyNotifAnggaran) ?? notifAnggaran;
      notifRingkasanHarian =
          prefs.getBool(NotificationService.keyNotifRingkasan) ??
          notifRingkasanHarian;
      budgetLimit =
          prefs.getInt(NotificationService.keyBudgetLimit) ?? budgetLimit;
      budgetThreshold =
          prefs.getInt(NotificationService.keyBudgetThreshold) ??
          budgetThreshold;
      budgetScopeType =
          prefs.getString(NotificationService.keyBudgetScopeType) ??
          budgetScopeType;
      budgetScopeValue =
          prefs.getString(NotificationService.keyBudgetScopeValue) ??
          budgetScopeValue;
      budgetPeriodDays =
          prefs.getInt(NotificationService.keyBudgetPeriodDays) ??
          budgetPeriodDays;
      final hour =
          prefs.getInt(NotificationService.keyRingkasanHour) ??
          ringkasanTime.hour;
      final minute =
          prefs.getInt(NotificationService.keyRingkasanMinute) ??
          ringkasanTime.minute;
      ringkasanTime = TimeOfDay(hour: hour, minute: minute);
      biometricLock =
          prefs.getBool(BiometricLockService.keyBiometricLock) ?? biometricLock;
      autoBackup = prefs.getBool(BackupService.keyAutoBackup) ?? autoBackup;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _showBudgetSheet() async {
    final settings = AppSettingsScope.of(context);
    final t = AppLocalizations.of(context);
    final limitController = TextEditingController(text: budgetLimit.toString());
    var tempThreshold = budgetThreshold;
    var tempScopeType = budgetScopeType;
    var tempScopeValue = budgetScopeValue;
    final wallets = await MasterDataService.instance.wallets();
    final categories = await MasterDataService.instance.categories();
    if (!mounted) return;
    await _showPolishedSheet<void>(
      context: context,
      title: t.t('budget_settings'),
      subtitle: t.locale.languageCode == 'en'
          ? 'Set spending limits, alert threshold, and scope.'
          : 'Atur batas anggaran, ambang alert, dan cakupannya.',
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandSeparatorFormatter()],
                  decoration: _sheetFieldDecoration(
                    label: t.t('monthly_limit'),
                    hint: '${settings.currencySymbol} 1000000',
                    icon: Icons.payments_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: tempThreshold,
                  decoration: _sheetFieldDecoration(
                    label: t.t('alert_when'),
                    icon: Icons.notification_important_rounded,
                  ),
                  items: [
                    DropdownMenuItem(value: 70, child: Text(t.t('alert_70'))),
                    DropdownMenuItem(value: 80, child: Text(t.t('alert_80'))),
                    DropdownMenuItem(value: 90, child: Text(t.t('alert_90'))),
                    DropdownMenuItem(value: 100, child: Text(t.t('alert_100'))),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      tempThreshold = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tempScopeType,
                  decoration: _sheetFieldDecoration(
                    label: t.t('budget_scope'),
                    icon: Icons.tune_rounded,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(t.t('budget_scope_all')),
                    ),
                    DropdownMenuItem(
                      value: 'category',
                      child: Text(t.t('budget_scope_category')),
                    ),
                    DropdownMenuItem(
                      value: 'wallet',
                      child: Text(t.t('budget_scope_wallet')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() {
                        tempScopeType = value;
                        tempScopeValue = '';
                      });
                    }
                  },
                ),
                if (tempScopeType == 'category') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categories.contains(tempScopeValue)
                        ? tempScopeValue
                        : null,
                    decoration: _sheetFieldDecoration(
                      label: t.t('category'),
                      icon: Icons.category_rounded,
                    ),
                    items: categories
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => tempScopeValue = value);
                      }
                    },
                  ),
                ],
                if (tempScopeType == 'wallet') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: wallets.contains(tempScopeValue)
                        ? tempScopeValue
                        : null,
                    decoration: _sheetFieldDecoration(
                      label: t.t('fund_source'),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                    items: wallets
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => tempScopeValue = value);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppUiTokens.surfaceBlueSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppUiTokens.brandBlueBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: AppUiTokens.brandBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.t('budget_calendar_month'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppUiTokens.textNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove(
                            NotificationService.keyBudgetLimit,
                          );
                          await prefs.remove(
                            NotificationService.keyBudgetThreshold,
                          );
                          await prefs.remove(
                            NotificationService.keyBudgetScopeType,
                          );
                          await prefs.remove(
                            NotificationService.keyBudgetScopeValue,
                          );
                          await prefs.remove(
                            NotificationService.keyBudgetPeriodDays,
                          );
                          setState(() {
                            budgetLimit = 1000000;
                            budgetThreshold = 80;
                            budgetScopeType = 'all';
                            budgetScopeValue = '';
                            budgetPeriodDays = 0;
                          });
                          NotificationService.notifyBudgetSettingsChanged();
                          if (notifAnggaran) {
                            await NotificationService.instance
                                .syncFromPreferences();
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                          _showAction('Limit anggaran berhasil direset');
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final parsed =
                              int.tryParse(
                                limitController.text.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                ),
                              ) ??
                              budgetLimit;
                          if (parsed <= 0 || parsed > _maxAmount) {
                            _showAction(
                              'Limit anggaran harus 1 sampai Rp 1.000.000.000',
                            );
                            return;
                          }
                          setState(() {
                            budgetLimit = parsed;
                            budgetThreshold = tempThreshold;
                            budgetScopeType = tempScopeType;
                            budgetScopeValue = tempScopeValue;
                            budgetPeriodDays = 0;
                          });
                          await _saveInt(
                            NotificationService.keyBudgetLimit,
                            budgetLimit,
                          );
                          await _saveInt(
                            NotificationService.keyBudgetThreshold,
                            budgetThreshold,
                          );
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(
                            NotificationService.keyBudgetScopeType,
                            budgetScopeType,
                          );
                          await prefs.setString(
                            NotificationService.keyBudgetScopeValue,
                            budgetScopeValue,
                          );
                          await prefs.remove(
                            NotificationService.keyBudgetPeriodDays,
                          );
                          NotificationService.notifyBudgetSettingsChanged();
                          if (notifAnggaran) {
                            await NotificationService.instance
                                .syncFromPreferences();
                            await NotificationService.instance.showNow(
                              id: NotificationService.idAnggaranHarian + 2,
                              title: t.t('budget_saved'),
                              body:
                                  '${t.t('budget_limit')} ${settings.formatCurrency(budgetLimit)} - ${t.t('budget_alert')} $budgetThreshold% (${t.t('this_month')})',
                            );
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          t.t('save'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickRingkasanTime() async {
    final t = AppLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: ringkasanTime,
    );
    if (picked != null) {
      setState(() => ringkasanTime = picked);
      await _saveInt(NotificationService.keyRingkasanHour, picked.hour);
      await _saveInt(NotificationService.keyRingkasanMinute, picked.minute);
      if (notifRingkasanHarian) {
        await NotificationService.instance.scheduleDaily(
          id: NotificationService.idRingkasanHarian,
          title: t.t('daily_summary'),
          body: t.t('daily_summary_body'),
          time: ringkasanTime,
        );
      }
    }
  }

  String _themeLabel(ThemeMode mode, AppLocalizations t) {
    switch (mode) {
      case ThemeMode.light:
        return t.t('theme_light');
      case ThemeMode.dark:
        return t.t('theme_dark');
      case ThemeMode.system:
        return t.t('theme_system');
    }
  }

  void _showSelectionSheet({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    _showPolishedSheet<void>(
      context: context,
      title: title,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.72;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ProfileSettingsCard(
            children: List.generate(options.length * 2 - 1, (index) {
              if (index.isOdd) return const ProfileDivider();
              final option = options[index ~/ 2];
              final isSelected = option == selected;
              return ProfileActionTile(
                icon: isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? AppUiTokens.brandBlue
                    : AppUiTokens.textMutedDeep,
                title: option,
                subtitle: isSelected ? 'Selected' : 'Tap to choose',
                compact: true,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(option);
                },
              );
            }),
          ),
        );
      },
    );
  }

  Future<T?> _showPolishedSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    required String title,
    String? subtitle,
  }) {
    return showModalBottomSheet<T>(
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
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppUiTokens.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    builder(sheetContext),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
