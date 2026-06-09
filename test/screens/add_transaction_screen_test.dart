import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catatuang/screens/add_transaction_screen.dart';
import 'package:catatuang/services/app_localizations.dart';
import 'package:catatuang/services/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('can toggle transaction type labels', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AppSettingsScope(
          settings: settings,
          child: const AddTransactionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nominal Pengeluaran'), findsOneWidget);
    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Nominal Pemasukan'), findsOneWidget);
  });

  testWidgets('income type shows income categories', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AppSettingsScope(
          settings: settings,
          child: const AddTransactionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kuliner'), findsOneWidget);
    expect(find.text('Gaji'), findsNothing);

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();

    expect(find.text('Gaji'), findsOneWidget);
    expect(find.text('Freelance'), findsOneWidget);
    expect(find.text('Kuliner'), findsNothing);
  });
}
