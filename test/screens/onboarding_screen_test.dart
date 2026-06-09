import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/screens/onboarding_screen.dart';
import 'package:catatuang/services/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding advances to language step', (tester) async {
    final settings = AppSettings();
    var doneCalled = false;
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          home: OnboardingScreen(
            settings: settings,
            onDone: () => doneCalled = true,
          ),
        ),
      ),
    );

    expect(find.textContaining('CatatUang'), findsOneWidget);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    final hasLanguageStep = find.textContaining('Language').evaluate().isNotEmpty ||
        find.textContaining('Bahasa').evaluate().isNotEmpty;
    expect(hasLanguageStep, isTrue);
    expect(doneCalled, isFalse);
  });
}
