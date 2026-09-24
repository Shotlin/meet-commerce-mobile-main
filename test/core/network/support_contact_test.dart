import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/network/support_settings_provider.dart';

/// The single source of truth every "Need Help"/"Contact Us" surface reads
/// from — replacing the old hardcoded AppConstants.supportPhone/
/// supportPhoneDialable/supportEmail. Covers the one piece of real logic
/// on the model: deriving a `tel:`-safe dialable string from whatever
/// human-readable format an admin typed into the dashboard.
void main() {
  group('SupportContact.supportPhoneDialable', () {
    test('strips spaces from a dashboard-entered number', () {
      const contact = SupportContact(brandName: 'FreshCuts', supportPhone: '+91 99249 98906');
      expect(contact.supportPhoneDialable, '+919924998906');
    });

    test('strips dashes and parentheses too', () {
      const contact = SupportContact(brandName: 'FreshCuts', supportPhone: '(91) 99249-98906');
      expect(contact.supportPhoneDialable, '9199249-98906'.replaceAll('-', ''));
    });

    test('is null when no phone is configured — never a fabricated fallback', () {
      const contact = SupportContact(brandName: 'FreshCuts');
      expect(contact.supportPhone, isNull);
      expect(contact.supportPhoneDialable, isNull);
    });

    test('is null for a phone that is only whitespace', () {
      const contact = SupportContact(brandName: 'FreshCuts', supportPhone: '   ');
      expect(contact.supportPhoneDialable, isNull);
    });
  });

  group('SupportContact.empty', () {
    test('has a real brand name default but no phone/email', () {
      expect(SupportContact.empty.brandName, 'FreshCuts');
      expect(SupportContact.empty.supportPhone, isNull);
      expect(SupportContact.empty.supportEmail, isNull);
    });
  });
}
