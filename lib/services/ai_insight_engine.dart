import '../data/models/transaction_record.dart';

/// Offline rule-based insight engine that analyzes spending patterns
/// and generates smart tips without requiring internet or API keys.
class AiInsightEngine {
  AiInsightEngine._();

  static final AiInsightEngine instance = AiInsightEngine._();

  /// Generate insights based on current transaction data.
  List<FinancialInsight> generateInsights({
    required List<TransactionRecord> transactions,
    required int totalBalance,
    required int cycleStartDay,
    required String languageCode,
    required String currencySymbol,
  }) {
    if (transactions.isEmpty) return [];

    final now = DateTime.now();
    final insights = <FinancialInsight>[];

    // 1. Spending anomaly detection
    final anomaly = _detectSpendingAnomaly(transactions, now, languageCode);
    if (anomaly != null) insights.add(anomaly);

    // 2. Category trend analysis
    final trend = _detectCategoryTrend(transactions, now, languageCode);
    if (trend != null) insights.add(trend);

    // 3. Streak & consistency
    final streak = _streakInsight(transactions, now, languageCode);
    if (streak != null) insights.add(streak);

    // 4. Savings opportunity
    final savings = _savingsOpportunity(transactions, now, languageCode, currencySymbol);
    if (savings != null) insights.add(savings);

    // 5. Burn rate warning
    final burnWarning = _burnRateWarning(
      transactions, totalBalance, now, languageCode,
    );
    if (burnWarning != null) insights.add(burnWarning);

    // 6. Top spending day pattern
    final dayPattern = _dayOfWeekPattern(transactions, now, languageCode);
    if (dayPattern != null) insights.add(dayPattern);

    // 7. Income vs Expense ratio
    final ratio = _incomeExpenseRatio(transactions, now, languageCode);
    if (ratio != null) insights.add(ratio);

    // Return max 3 most relevant insights
    insights.sort((a, b) => b.priority.compareTo(a.priority));
    return insights.take(3).toList();
  }

  FinancialInsight? _detectSpendingAnomaly(
    List<TransactionRecord> txs,
    DateTime now,
    String lang,
  ) {
    final thisMonth = txs.where((tx) =>
        tx.isExpense &&
        tx.category != 'transfer_out' &&
        tx.transactionDate.month == now.month &&
        tx.transactionDate.year == now.year);
    final lastMonth = txs.where((tx) =>
        tx.isExpense &&
        tx.category != 'transfer_out' &&
        tx.transactionDate.month == (now.month == 1 ? 12 : now.month - 1) &&
        tx.transactionDate.year == (now.month == 1 ? now.year - 1 : now.year));

    final thisTotal = thisMonth.fold<int>(0, (s, tx) => s + tx.amount);
    final lastTotal = lastMonth.fold<int>(0, (s, tx) => s + tx.amount);

    if (lastTotal <= 0 || thisTotal <= 0) return null;

    final elapsedRatio = now.day / 30;
    final projectedTotal = (thisTotal / elapsedRatio).round();
    final increase = ((projectedTotal - lastTotal) / lastTotal * 100).round();

    if (increase > 20) {
      return FinancialInsight(
        type: InsightType.warning,
        title: lang == 'en'
            ? 'Spending pace is high'
            : 'Laju pengeluaran tinggi',
        message: lang == 'en'
            ? 'At this pace, you\'ll spend ~$increase% more than last month. Consider reviewing your expenses.'
            : 'Dengan laju ini, pengeluaran akan ~$increase% lebih besar dari bulan lalu. Pertimbangkan untuk review pengeluaran.',
        icon: 'trending_up',
        priority: 9,
      );
    }

    if (increase < -15) {
      return FinancialInsight(
        type: InsightType.positive,
        title: lang == 'en'
            ? 'Great spending control!'
            : 'Pengeluaran terkontrol!',
        message: lang == 'en'
            ? 'You\'re spending ${(-increase)}% less than last month. Keep it up!'
            : 'Pengeluaran kamu ${(-increase)}% lebih hemat dari bulan lalu. Pertahankan!',
        icon: 'thumb_up',
        priority: 7,
      );
    }

    return null;
  }

  FinancialInsight? _detectCategoryTrend(
    List<TransactionRecord> txs,
    DateTime now,
    String lang,
  ) {
    final thisMonth = <String, int>{};
    final lastMonth = <String, int>{};

    for (final tx in txs) {
      if (!tx.isExpense) continue;
      if (tx.category == 'transfer_out') continue;
      final d = tx.transactionDate;
      if (d.month == now.month && d.year == now.year) {
        thisMonth[tx.category] = (thisMonth[tx.category] ?? 0) + tx.amount;
      } else if (d.month == (now.month == 1 ? 12 : now.month - 1) &&
          d.year == (now.month == 1 ? now.year - 1 : now.year)) {
        lastMonth[tx.category] = (lastMonth[tx.category] ?? 0) + tx.amount;
      }
    }

    String? biggestRiser;
    var biggestIncrease = 0;

    for (final entry in thisMonth.entries) {
      final prev = lastMonth[entry.key] ?? 0;
      if (prev <= 0) continue;
      final increase = entry.value - prev;
      if (increase > biggestIncrease && increase > prev * 0.3) {
        biggestIncrease = increase;
        biggestRiser = entry.key;
      }
    }

    if (biggestRiser == null) return null;

    final percent = ((biggestIncrease / (lastMonth[biggestRiser] ?? 1)) * 100).round();
    return FinancialInsight(
      type: InsightType.info,
      title: lang == 'en'
          ? 'Category spike: $biggestRiser'
          : 'Lonjakan kategori: $biggestRiser',
      message: lang == 'en'
          ? '"$biggestRiser" spending is up $percent% compared to last month.'
          : 'Pengeluaran "$biggestRiser" naik $percent% dibanding bulan lalu.',
      icon: 'category',
      priority: 6,
    );
  }

  FinancialInsight? _streakInsight(
    List<TransactionRecord> txs,
    DateTime now,
    String lang,
  ) {
    final activeDays = <DateTime>{};
    for (final tx in txs) {
      activeDays.add(DateTime(
        tx.transactionDate.year,
        tx.transactionDate.month,
        tx.transactionDate.day,
      ));
    }

    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    if (streak >= 7) {
      return FinancialInsight(
        type: InsightType.positive,
        title: lang == 'en'
            ? '🔥 $streak-day streak!'
            : '🔥 Streak $streak hari!',
        message: lang == 'en'
            ? 'Amazing consistency! You\'ve been tracking finances for $streak days straight.'
            : 'Konsistensi luar biasa! Kamu sudah mencatat keuangan selama $streak hari berturut-turut.',
        icon: 'local_fire_department',
        priority: streak >= 14 ? 8 : 5,
      );
    }

    return null;
  }

  FinancialInsight? _savingsOpportunity(
    List<TransactionRecord> txs,
    DateTime now,
    String lang,
    String currencySymbol,
  ) {
    // Find recurring small expenses that add up
    final thisMonth = txs.where((tx) =>
        tx.isExpense &&
        tx.transactionDate.month == now.month &&
        tx.transactionDate.year == now.year &&
        tx.category != 'transfer_out');

    final categoryCount = <String, int>{};
    final categoryTotal = <String, int>{};

    for (final tx in thisMonth) {
      categoryCount[tx.category] = (categoryCount[tx.category] ?? 0) + 1;
      categoryTotal[tx.category] = (categoryTotal[tx.category] ?? 0) + tx.amount;
    }

    // Find categories with many small transactions
    String? frequentCategory;
    var maxCount = 0;
    for (final entry in categoryCount.entries) {
      if (entry.value > maxCount && entry.value >= 5) {
        maxCount = entry.value;
        frequentCategory = entry.key;
      }
    }

    if (frequentCategory == null) return null;

    final total = categoryTotal[frequentCategory] ?? 0;
    final avgPerTx = total ~/ maxCount;

    return FinancialInsight(
      type: InsightType.tip,
      title: lang == 'en'
          ? 'Savings opportunity'
          : 'Peluang hemat',
      message: lang == 'en'
          ? 'You made $maxCount "$frequentCategory" purchases this month. Reducing 2 could save you ~$currencySymbol${avgPerTx * 2}.'
          : 'Kamu melakukan $maxCount transaksi "$frequentCategory" bulan ini. Mengurangi 2x bisa hemat ~$currencySymbol ${avgPerTx * 2}.',
      icon: 'savings',
      priority: 5,
    );
  }

  FinancialInsight? _burnRateWarning(
    List<TransactionRecord> txs,
    int totalBalance,
    DateTime now,
    String lang,
  ) {
    if (totalBalance <= 0) return null;

    final thisMonth = txs.where((tx) =>
        tx.isExpense &&
        tx.category != 'transfer_out' &&
        tx.transactionDate.month == now.month &&
        tx.transactionDate.year == now.year);

    final totalExpense = thisMonth.fold<int>(0, (s, tx) => s + tx.amount);
    if (totalExpense <= 0) return null;

    final daysElapsed = now.day.clamp(1, 30);
    final dailyBurn = totalExpense ~/ daysElapsed;
    if (dailyBurn <= 0) return null;

    final runwayDays = totalBalance ~/ dailyBurn;

    if (runwayDays < 30) {
      return FinancialInsight(
        type: InsightType.warning,
        title: lang == 'en'
            ? 'Low runway warning'
            : 'Peringatan saldo menipis',
        message: lang == 'en'
            ? 'At current spending rate, your balance covers ~$runwayDays days. Consider reducing expenses.'
            : 'Dengan laju pengeluaran saat ini, saldo cukup untuk ~$runwayDays hari. Pertimbangkan untuk mengurangi pengeluaran.',
        icon: 'warning',
        priority: 10,
      );
    }

    return null;
  }

  FinancialInsight? _dayOfWeekPattern(
    List<TransactionRecord> txs,
    DateTime now,
    String lang,
  ) {
    final last30 = txs.where((tx) =>
        tx.isExpense &&
        tx.category != 'transfer_out' &&
        tx.transactionDate.isAfter(now.subtract(const Duration(days: 30))));

    final dayTotals = List<int>.filled(7, 0);
    final dayCounts = List<int>.filled(7, 0);

    for (final tx in last30) {
      final weekday = tx.transactionDate.weekday - 1; // 0=Mon, 6=Sun
      dayTotals[weekday] += tx.amount;
      dayCounts[weekday]++;
    }

    var maxDay = 0;
    var maxTotal = 0;
    for (var i = 0; i < 7; i++) {
      if (dayTotals[i] > maxTotal) {
        maxTotal = dayTotals[i];
        maxDay = i;
      }
    }

    if (maxTotal <= 0) return null;

    final avgDaily = dayTotals.fold<int>(0, (s, v) => s + v) ~/ 7;
    if (maxTotal < avgDaily * 1.4) return null; // Not significant

    final dayNames = lang == 'en'
        ? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        : ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    return FinancialInsight(
      type: InsightType.info,
      title: lang == 'en'
          ? 'Peak spending day'
          : 'Hari paling boros',
      message: lang == 'en'
          ? '${dayNames[maxDay]} is your highest spending day. Being mindful could help save more.'
          : '${dayNames[maxDay]} adalah hari pengeluaran tertinggimu. Lebih sadar bisa bantu hemat.',
      icon: 'today',
      priority: 4,
    );
  }

  FinancialInsight? _incomeExpenseRatio(
    List<TransactionRecord> txs,
    DateTime now,
    String lang,
  ) {
    final thisMonth = txs.where((tx) =>
        tx.transactionDate.month == now.month &&
        tx.transactionDate.year == now.year);

    final income = thisMonth
        .where((tx) => !tx.isExpense && tx.category != 'transfer_in')
        .fold<int>(0, (s, tx) => s + tx.amount);
    final expense = thisMonth
        .where((tx) => tx.isExpense && tx.category != 'transfer_out')
        .fold<int>(0, (s, tx) => s + tx.amount);

    if (income <= 0) return null;

    final savingRate = ((income - expense) / income * 100).round();

    if (savingRate >= 30) {
      return FinancialInsight(
        type: InsightType.positive,
        title: lang == 'en'
            ? 'Excellent saving rate!'
            : 'Rasio tabungan bagus!',
        message: lang == 'en'
            ? 'You\'re saving $savingRate% of your income this month. That\'s above the recommended 20%.'
            : 'Kamu menabung $savingRate% dari pendapatan bulan ini. Itu di atas rekomendasi 20%.',
        icon: 'stars',
        priority: 6,
      );
    }

    if (savingRate < 5 && expense > 0) {
      return FinancialInsight(
        type: InsightType.warning,
        title: lang == 'en'
            ? 'Low saving rate'
            : 'Rasio tabungan rendah',
        message: lang == 'en'
            ? 'You\'re only saving $savingRate% this month. Try to target at least 20%.'
            : 'Kamu hanya menabung $savingRate% bulan ini. Coba targetkan minimal 20%.',
        icon: 'account_balance',
        priority: 7,
      );
    }

    return null;
  }
}

enum InsightType { positive, warning, info, tip }

class FinancialInsight {
  const FinancialInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    required this.priority,
  });

  final InsightType type;
  final String title;
  final String message;
  final String icon;
  final int priority;
}
