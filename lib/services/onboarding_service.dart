import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  OnboardingService._();

  static final OnboardingService instance = OnboardingService._();

  static const String keyCompleted = 'onboarding_completed_v1';
  static const String keyPrimaryWallet = 'onboarding_primary_wallet';
  static const String keyPrimaryCategory = 'onboarding_primary_category';

  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyCompleted) ?? false;
  }

  Future<void> markCompleted({
    required String primaryWallet,
    required String primaryCategory,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyCompleted, true);
    await prefs.setString(keyPrimaryWallet, primaryWallet);
    await prefs.setString(keyPrimaryCategory, primaryCategory);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyCompleted);
    await prefs.remove(keyPrimaryWallet);
    await prefs.remove(keyPrimaryCategory);
  }
}
