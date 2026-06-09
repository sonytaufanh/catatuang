import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/services/due_date_service.dart';

void main() {
  group('DueDateService.daysUntilDueDate', () {
    test('returns 0 when due day is today', () {
      final from = DateTime(2026, 3, 15, 10, 30);
      final days = DueDateService.daysUntilDueDate(from: from, dueDay: 15);
      expect(days, 0);
    });

    test('clamps due day to end of month correctly', () {
      final from = DateTime(2026, 2, 27);
      final days = DueDateService.daysUntilDueDate(from: from, dueDay: 31);
      expect(days, 1);
    });

    test('rolls to next month when this month due date passed', () {
      final from = DateTime(2026, 2, 28);
      final days = DueDateService.daysUntilDueDate(from: from, dueDay: 27);
      expect(days, 27);
    });
  });
}
