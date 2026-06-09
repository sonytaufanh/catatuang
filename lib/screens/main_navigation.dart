import 'dart:async';

import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/onboarding_service.dart';
import '../services/app_animations.dart';
import '../services/app_ui_tokens.dart';
import '../services/error_log_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'add_transaction_screen.dart';
import 'stats_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'onboarding_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _checkingOnboarding = true;
  bool _showOnboarding = false;
  bool _isTabAnimating = false;
  late final ValueNotifier<int> _activeTabNotifier = ValueNotifier<int>(0);
  late final PageController _pageController = PageController();

  final List<Widget> _pages = [
    const HomeScreen(),
    const StatsScreen(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  @override
  void dispose() {
    _activeTabNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadOnboardingState() async {
    final completed = await OnboardingService.instance.isCompleted();
    if (!mounted) return;
    setState(() {
      _showOnboarding = !completed;
      _checkingOnboarding = false;
    });
    if (completed) {
      unawaited(_warmUpAppServices());
    }
  }

  Future<void> _warmUpAppServices() async {
    try {
      await NotificationService.instance.warmUpInBackground();
    } catch (e) {
      await ErrorLogService.instance.log(
        source: 'notification_warmup',
        error: e,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOnboarding) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showOnboarding) {
      return OnboardingScreen(
        settings: AppSettingsScope.of(context),
        onDone: () {
          if (!mounted) return;
          setState(() => _showOnboarding = false);
          unawaited(_warmUpAppServices());
        },
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final compact = screenHeight < 860;
    final navHeight = compact ? 68.0 : 76.0;
    final fabSize = compact ? 54.0 : 60.0;
    final navGap = compact ? 14.0 : 20.0;

    return TabActivationScope(
      activeIndexListenable: _activeTabNotifier,
      child: Scaffold(
        body: AnimatedScale(
          scale: _isTabAnimating ? 0.992 : 1,
          duration: AppAnimations.normal,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _isTabAnimating ? 0.985 : 1,
            duration: AppAnimations.fast,
            curve: Curves.easeOutCubic,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                if (!mounted) return;
                _activeTabNotifier.value = index;
                setState(() => _currentIndex = index);
              },
              children: _pages
                  .map((page) => RepaintBoundary(child: page))
                  .toList(growable: false),
            ),
          ),
        ),

        // Tombol Tambah Mengambang dengan Gradien
        // Tombol Tambah Mengambang
        floatingActionButton: Container(
          height: fabSize,
          width: fabSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppUiTokens.fabGradient,
            boxShadow: [
              BoxShadow(
                color: AppUiTokens.brandBlue.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<Object?>(
                  builder: (_) => const AddTransactionScreen(),
                ),
              ).then((result) {
                if (!context.mounted) return;
                showTransactionSaveResultSnack(context, result);
              });
            },
            backgroundColor: AppUiTokens.transparent,
            elevation: 0,
            child: Icon(
              Icons.add,
              color: AppUiTokens.white,
              size: compact ? 28 : 32,
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        // Bottom Bar yang Diperlebar agar tidak Overflow
        bottomNavigationBar: BottomAppBar(
          color: scheme.surface,
          shape: const CircularNotchedRectangle(),
          notchMargin: compact ? 10.0 : 12.0,
          elevation: 10,
          child: Container(
            height: navHeight,
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildNavIcon(Icons.home_rounded, 0),
                    SizedBox(width: navGap),
                    _buildNavIcon(Icons.bar_chart_rounded, 1),
                  ],
                ),
                Row(
                  children: [
                    _buildNavIcon(Icons.account_balance_wallet_rounded, 2),
                    SizedBox(width: navGap),
                    _buildNavIcon(Icons.person_rounded, 3),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget Navigasi Tanpa Teks Label (Mencegah Overflow)
  Widget _buildNavIcon(IconData icon, int index) {
    bool isActive = _currentIndex == index;
    final scheme = Theme.of(context).colorScheme;
    return PressableScale(
      borderRadius: BorderRadius.circular(15),
      pressedScale: 0.94,
      onTap: () async {
        if (_currentIndex == index || _isTabAnimating) return;
        setState(() {
          _currentIndex = index;
          _isTabAnimating = true;
        });
        _activeTabNotifier.value = index;
        try {
          await _pageController.animateToPage(
            index,
            duration: AppAnimations.slow,
            curve: Curves.easeInOutCubicEmphasized,
          );
        } finally {
          if (mounted) {
            setState(() => _isTabAnimating = false);
          }
        }
      },
      child: AnimatedContainer(
        duration: AppAnimations.normal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.14)
              : AppUiTokens.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: AnimatedSlide(
          offset: isActive ? Offset.zero : const Offset(0, 0.03),
          duration: AppAnimations.normal,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: isActive ? 1.0 : 0.96,
            duration: AppAnimations.normal,
            curve: Curves.easeOutCubic,
            child: Icon(
              icon,
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              size: isActive ? 29 : 27,
            ),
          ),
        ),
      ),
    );
  }
}
