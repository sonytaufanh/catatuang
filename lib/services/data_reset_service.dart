import '../data/database_service.dart';
import '../data/debt_store.dart';
import '../data/recurring_bill_store.dart';
import '../data/transaction_store.dart';
import 'backup_service.dart';
import 'category_budget_service.dart';
import 'master_data_service.dart';
import 'notification_service.dart';
import 'onboarding_service.dart';
import 'recurring_transaction_service.dart';
import 'savings_goal_service.dart';
import 'session_service.dart';
import 'user_profile_service.dart';

/// Wipes all locally stored user data so the app returns to a fresh state.
class DataResetService {
  DataResetService._();

  static final DataResetService instance = DataResetService._();

  Future<void> wipeAll() async {
    await DatabaseService.instance.clearAllData();
    await MasterDataService.instance.clearAll();
    await CategoryBudgetService.instance.clearAll();
    await SavingsGoalService.instance.clear();
    await RecurringTransactionService.instance.clearAll();
    await OnboardingService.instance.reset();
    await BackupService.instance.deleteLocalBackup();
    await NotificationService.instance.clearBudgetSettings();
    await SessionService.instance.clearLocalSession();
    await UserProfileService.instance.reset();

    await refreshTransactions();
    await refreshRecurringBills();
    await refreshDebts();
    await NotificationService.instance.syncFromPreferences();
  }
}
