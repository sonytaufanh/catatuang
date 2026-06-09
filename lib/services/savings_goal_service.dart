import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavingsGoalState {
  const SavingsGoalState({
    required this.targetAmount,
    required this.label,
  });

  final int targetAmount;
  final String label;

  bool get enabled => targetAmount > 0;
}

class SavingsGoalService {
  SavingsGoalService._();

  static final SavingsGoalService instance = SavingsGoalService._();

  static const String keyTargetAmount = 'savings_goal_target_amount';
  static const String keyLabel = 'savings_goal_label';

  final ValueNotifier<SavingsGoalState> notifier = ValueNotifier(
    const SavingsGoalState(targetAmount: 0, label: ''),
  );

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    notifier.value = SavingsGoalState(
      targetAmount: prefs.getInt(keyTargetAmount) ?? 0,
      label: prefs.getString(keyLabel) ?? '',
    );
    _loaded = true;
  }

  Future<void> save({
    required int targetAmount,
    required String label,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyTargetAmount, targetAmount);
    await prefs.setString(keyLabel, label);
    notifier.value = SavingsGoalState(targetAmount: targetAmount, label: label);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyTargetAmount);
    await prefs.remove(keyLabel);
    notifier.value = const SavingsGoalState(targetAmount: 0, label: '');
  }
}
