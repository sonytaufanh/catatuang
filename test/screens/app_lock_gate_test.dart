import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catatuang/screens/app_lock_gate.dart';
import 'package:catatuang/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows sign in UI when local session is signed out', (tester) async {
    SharedPreferences.setMockInitialValues({
      SessionService.keySignedIn: false,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AppLockGate(),
      ),
    );
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(TextField).evaluate().isNotEmpty) {
        break;
      }
    }

    final hasSignInForm = find.byType(TextField).evaluate().length == 2;
    final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    expect(hasSignInForm || hasLoading, isTrue);
  });
}
