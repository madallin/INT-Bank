import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internet_banking/core/services/privacy_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivacyModeService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state is false and toggling changes state', () async {
      final service = PrivacyModeService();
      await service.init();

      await service.setPrivacyMode(false);
      expect(service.isPrivacyModeEnabled.value, false);

      await service.togglePrivacyMode();
      expect(service.isPrivacyModeEnabled.value, true);

      await service.togglePrivacyMode();
      expect(service.isPrivacyModeEnabled.value, false);
    });

    test('formatOrMask returns raw amount when privacy mode is disabled', () async {
      final service = PrivacyModeService();
      await service.setPrivacyMode(false);

      expect(service.formatOrMask('1,250.00 RON'), '1,250.00 RON');
      expect(service.formatOrMask('-50.00 RON'), '-50.00 RON');
    });

    test('formatOrMask returns masked string when privacy mode is enabled', () async {
      final service = PrivacyModeService();
      await service.setPrivacyMode(true);

      expect(service.formatOrMask('1,250.00 RON'), '\u2022\u2022\u2022\u2022 RON');
      expect(service.formatOrMask('500.00 EUR', mask: '\u2022\u2022\u2022\u2022 EUR'), '\u2022\u2022\u2022\u2022 EUR');
    });
  });
}
