class DueDateService {
  DueDateService._();

  static int daysUntilDueDate({
    required DateTime from,
    required int dueDay,
  }) {
    final today = DateTime(from.year, from.month, from.day);
    final next = nextDueDate(from: today, dueDay: dueDay);
    return next.difference(today).inDays;
  }

  static DateTime nextDueDate({
    required DateTime from,
    required int dueDay,
  }) {
    final today = DateTime(from.year, from.month, from.day);
    final normalizedDay = dueDay.clamp(1, 31);
    final thisMonthDay = safeDayInMonth(
      year: today.year,
      month: today.month,
      requestedDay: normalizedDay,
    );
    final thisMonthDueDate = DateTime(today.year, today.month, thisMonthDay);

    if (!thisMonthDueDate.isBefore(today)) {
      return thisMonthDueDate;
    }

    final nextMonth = DateTime(today.year, today.month + 1, 1);
    final nextMonthDay = safeDayInMonth(
      year: nextMonth.year,
      month: nextMonth.month,
      requestedDay: normalizedDay,
    );
    return DateTime(nextMonth.year, nextMonth.month, nextMonthDay);
  }

  static int safeDayInMonth({
    required int year,
    required int month,
    required int requestedDay,
  }) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return requestedDay.clamp(1, lastDay);
  }
}
