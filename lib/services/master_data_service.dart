import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class MasterDataService extends ChangeNotifier {
  MasterDataService._();

  static final MasterDataService instance = MasterDataService._();

  static const String _walletsKey = 'master_wallets_v1';
  static const String _categoriesKey = 'master_categories_v1';
  static const String _expenseCategoriesKey = 'master_expense_categories_v1';
  static const String _incomeCategoriesKey = 'master_income_categories_v1';
  static const String _openingBalancePrefix = 'wallet_opening_balance_v1_';

  Map<String, int> _openingBalances = const <String, int>{};
  bool _initialized = false;

  static const List<String> defaultWallets = <String>[
    'cash',
    'bank',
    'ewallet',
    'card',
  ];

  static const List<String> defaultCategories = <String>[
    'food',
    'transport',
    'shopping',
    'bills',
    'entertainment',
    'health',
    'education',
    'others',
  ];

  static const List<String> defaultIncomeCategories = <String>[
    'salary',
    'freelance',
    'bonus',
    'business',
    'investment',
    'gift',
    'others',
  ];

  Future<void> init() async {
    if (_initialized) return;
    _openingBalances = await walletOpeningBalances();
    _initialized = true;
  }

  int get openingBalanceTotal {
    var total = 0;
    for (final amount in _openingBalances.values) {
      total += amount;
    }
    return total;
  }

  int openingBalanceForWalletSync(String wallet) {
    return _openingBalances[normalizeMasterKey(wallet)] ?? 0;
  }

  Future<List<String>> wallets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_walletsKey);
    if (raw == null || raw.isEmpty) return defaultWallets;
    return _sanitize(raw, fallback: defaultWallets);
  }

  Future<List<String>> categories() async {
    final expense = await expenseCategories();
    final income = await incomeCategories();
    return _mergeUnique([...expense, ...income]);
  }

  Future<List<String>> expenseCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList(_expenseCategoriesKey) ??
        prefs.getStringList(_categoriesKey);
    if (raw == null || raw.isEmpty) return defaultCategories;
    return _sanitize(raw, fallback: defaultCategories);
  }

  Future<List<String>> incomeCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_incomeCategoriesKey);
    if (raw == null || raw.isEmpty) return defaultIncomeCategories;
    return _sanitize(raw, fallback: defaultIncomeCategories);
  }

  Future<Map<String, int>> walletOpeningBalances() async {
    final prefs = await SharedPreferences.getInstance();
    final walletsList = await wallets();
    return <String, int>{
      for (final wallet in walletsList)
        wallet: prefs.getInt('$_openingBalancePrefix$wallet') ?? 0,
    };
  }

  Future<int> openingBalanceForWallet(String wallet) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(
          '$_openingBalancePrefix${normalizeMasterKey(wallet)}',
        ) ??
        0;
  }

  Future<void> setOpeningBalance({
    required String wallet,
    required int amount,
  }) async {
    final normalized = normalizeMasterKey(wallet);
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_openingBalancePrefix$normalized', amount);
    _openingBalances = await walletOpeningBalances();
    notifyListeners();
  }

  Future<Map<String, dynamic>> exportPayload() async {
    return <String, dynamic>{
      'wallets': await wallets(),
      'expenseCategories': await expenseCategories(),
      'incomeCategories': await incomeCategories(),
      'openingBalances': await walletOpeningBalances(),
    };
  }

  Future<void> restorePayload(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final walletsRaw = payload['wallets'];
    final expenseRaw = payload['expenseCategories'];
    final incomeRaw = payload['incomeCategories'];
    final balancesRaw = payload['openingBalances'];
    final restoredWallets = walletsRaw is List
        ? _sanitize(
            walletsRaw.whereType<String>().toList(),
            fallback: defaultWallets,
          )
        : defaultWallets;
    final restoredExpense = expenseRaw is List
        ? _sanitize(
            expenseRaw.whereType<String>().toList(),
            fallback: defaultCategories,
          )
        : defaultCategories;
    final restoredIncome = incomeRaw is List
        ? _sanitize(
            incomeRaw.whereType<String>().toList(),
            fallback: defaultIncomeCategories,
          )
        : defaultIncomeCategories;
    await prefs.setStringList(_walletsKey, restoredWallets);
    await prefs.setStringList(_expenseCategoriesKey, restoredExpense);
    await prefs.setStringList(_incomeCategoriesKey, restoredIncome);
    for (final wallet in restoredWallets) {
      await prefs.remove('$_openingBalancePrefix$wallet');
    }
    if (balancesRaw is Map) {
      for (final entry in balancesRaw.entries) {
        final wallet = normalizeMasterKey(entry.key.toString());
        final amount = entry.value is num ? (entry.value as num).toInt() : 0;
        if (wallet.isNotEmpty && amount >= 0) {
          await prefs.setInt('$_openingBalancePrefix$wallet', amount);
        }
      }
    }
    _openingBalances = await walletOpeningBalances();
    notifyListeners();
  }

  Future<void> addWallet(String value) async {
    final current = await wallets();
    final normalized = normalizeMasterKey(value);
    if (normalized.isEmpty || current.contains(normalized)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_walletsKey, [...current, normalized]);
    _openingBalances = await walletOpeningBalances();
    notifyListeners();
  }

  Future<void> addCategory(String value) async {
    await addExpenseCategory(value);
  }

  Future<void> addExpenseCategory(String value) async {
    final current = await expenseCategories();
    final normalized = normalizeMasterKey(value);
    if (normalized.isEmpty || current.contains(normalized)) return;
    final prefs = await SharedPreferences.getInstance();
    final expense = await expenseCategories();
    await prefs.setStringList(_expenseCategoriesKey, [...expense, normalized]);
    notifyListeners();
  }

  Future<void> addIncomeCategory(String value) async {
    final current = await incomeCategories();
    final normalized = normalizeMasterKey(value);
    if (normalized.isEmpty || current.contains(normalized)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_incomeCategoriesKey, [...current, normalized]);
    notifyListeners();
  }

  Future<void> removeWallet(String value) async {
    if (defaultWallets.contains(value)) return;
    final current = await wallets();
    final next = current.where((e) => e != value).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _walletsKey,
      next.isEmpty ? defaultWallets : next,
    );
    await prefs.remove('$_openingBalancePrefix${normalizeMasterKey(value)}');
    _openingBalances = await walletOpeningBalances();
    notifyListeners();
  }

  Future<void> removeCategory(String value) async {
    await removeExpenseCategory(value);
  }

  Future<void> removeExpenseCategory(String value) async {
    if (defaultCategories.contains(value)) return;
    final current = await expenseCategories();
    final next = current.where((e) => e != value).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _expenseCategoriesKey,
      next.isEmpty ? defaultCategories : next,
    );
    notifyListeners();
  }

  Future<void> removeIncomeCategory(String value) async {
    if (defaultIncomeCategories.contains(value)) return;
    final current = await incomeCategories();
    final next = current.where((e) => e != value).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _incomeCategoriesKey,
      next.isEmpty ? defaultIncomeCategories : next,
    );
    notifyListeners();
  }

  Future<bool> renameExpenseCategory(String oldValue, String newValue) async {
    final normalized = normalizeMasterKey(newValue);
    if (normalized.isEmpty) return false;
    final current = await expenseCategories();
    final idx = current.indexOf(oldValue);
    if (idx < 0) return false;
    if (current.contains(normalized) && normalized != oldValue) return false;
    current[idx] = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_expenseCategoriesKey, current);
    notifyListeners();
    return true;
  }

  Future<bool> renameIncomeCategory(String oldValue, String newValue) async {
    final normalized = normalizeMasterKey(newValue);
    if (normalized.isEmpty) return false;
    final current = await incomeCategories();
    final idx = current.indexOf(oldValue);
    if (idx < 0) return false;
    if (current.contains(normalized) && normalized != oldValue) return false;
    current[idx] = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_incomeCategoriesKey, current);
    notifyListeners();
    return true;
  }

  Future<bool> renameWallet(String oldValue, String newValue) async {
    final normalized = normalizeMasterKey(newValue);
    if (normalized.isEmpty) return false;
    final current = await wallets();
    final idx = current.indexOf(oldValue);
    if (idx < 0) return false;
    if (current.contains(normalized) && normalized != oldValue) return false;
    current[idx] = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_walletsKey, current);
    // Migrate opening balance
    final oldBalance =
        prefs.getInt('$_openingBalancePrefix$oldValue') ?? 0;
    await prefs.remove('$_openingBalancePrefix$oldValue');
    if (oldBalance > 0) {
      await prefs.setInt('$_openingBalancePrefix$normalized', oldBalance);
    }
    _openingBalances = await walletOpeningBalances();
    notifyListeners();
    return true;
  }

  Future<void> ensureMasterContains({
    required String wallet,
    required String category,
    bool? isExpense,
  }) async {
    final walletKey = normalizeMasterKey(wallet);
    final categoryKey = normalizeMasterKey(category);
    if (walletKey.isNotEmpty) {
      await addWallet(walletKey);
    }
    if (categoryKey.isNotEmpty) {
      if (isExpense == false) {
        await addIncomeCategory(categoryKey);
      } else {
        await addExpenseCategory(categoryKey);
      }
    }
  }

  List<String> _sanitize(
    List<String> source, {
    required List<String> fallback,
  }) {
    final out = <String>[];
    for (final item in source) {
      final normalized = normalizeMasterKey(item);
      if (normalized.isNotEmpty && !out.contains(normalized)) {
        out.add(normalized);
      }
    }
    return out.isEmpty ? fallback : out;
  }

  List<String> _mergeUnique(List<String> values) {
    final out = <String>[];
    for (final value in values) {
      final normalized = normalizeMasterKey(value);
      if (normalized.isNotEmpty && !out.contains(normalized)) {
        out.add(normalized);
      }
    }
    return out;
  }

  static String normalizeMasterKey(String value) {
    final cleaned = value.trim().toLowerCase();
    if (cleaned.isEmpty) return '';
    return cleaned
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
