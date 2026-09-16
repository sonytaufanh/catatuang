import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catatuang/screens/add_transaction_screen.dart';
import 'package:catatuang/screens/transfer_screen.dart';
import 'package:catatuang/services/app_localizations.dart';
import 'package:catatuang/services/app_settings.dart';

Widget _wrap(Widget child, AppSettings settings) {
  return MaterialApp(
    locale: const Locale('id'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: AppSettingsScope(settings: settings, child: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add transaction rejects empty amount with localized message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();

    await tester.pumpWidget(
      _wrap(const AddTransactionScreen(), settings),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIMPAN DATA'));
    await tester.pump();

    expect(find.text('Nominal transaksi belum valid'), findsOneWidget);
  });

  testWidgets('transfer rejects empty amount with localized message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();

    await tester.pumpWidget(_wrap(const TransferScreen(), settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIMPAN DATA'));
    await tester.pump();

    expect(find.text('Nominal transaksi belum valid'), findsOneWidget);
  });
}
