import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catatuang/services/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onboarding completion flag can be saved and read', () async {
    SharedPreferences.setMockInitialValues({});
    final service = OnboardingService.instance;

    expect(await service.isCompleted(), isFalse);

    await service.markCompleted(
      primaryWallet: 'cash',
      primaryCategory: 'food',
    );

    expect(await service.isCompleted(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(OnboardingService.keyPrimaryWallet),
      'cash',
    );
    expect(
      prefs.getString(OnboardingService.keyPrimaryCategory),
      'food',
    );
  });
}
