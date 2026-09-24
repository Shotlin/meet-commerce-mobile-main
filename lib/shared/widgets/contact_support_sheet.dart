import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakaloo_flutter_app/core/network/support_settings_provider.dart';

/// FreshCuts red — matches the exact hex the "Need Help"/"Contact Us"
/// styling was speced against. Deliberately local to this file rather than
/// pulled from `AppColors.brandRed` (a close but different red, 0xFFD02428)
/// or the Order-Details-screen-only `OrderDetailPalette` — this widget is
/// shared by two screens outside that screen's own scope.
class _ContactSheetPalette {
  _ContactSheetPalette._();
  static const primaryRed = Color(0xFFC32D2E);
  static const textPrimary = Color(0xFF111318);
  static const textSecondary = Color(0xFF6F7785);
}

/// Shared "Need Help" / "Contact Us" bottom sheet — one source of layout
/// and one source of contact data ([supportContactProvider]) for both
/// Order Details' "Need Help?" and Profile's "Contact Us", so they can
/// never drift out of sync with each other or with what the dashboard's
/// Support & Contact Settings panel actually saved. A phone/email row is
/// omitted entirely (not shown disabled/broken) when that field genuinely
/// isn't configured — never a fabricated fallback.
Future<void> showContactSupportSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (_) => _ContactSupportSheetBody(title: title),
  );
}

class _ContactSupportSheetBody extends ConsumerWidget {
  const _ContactSupportSheetBody({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactAsync = ref.watch(supportContactProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 18.h),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: _ContactSheetPalette.textPrimary,
            ),
          ),
          Gap(14.h),
          contactAsync.when(
            data: (contact) => _ContactRows(contact: contact),
            loading: () => Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _ContactSheetPalette.primaryRed,
                    ),
                  ),
                ),
              ),
            ),
            // Fails open to the same "nothing configured" empty state as a
            // genuinely-empty settings row — the sheet still opens and
            // closes cleanly, it just has no contact rows to show.
            error: (_, __) => const _ContactRows(contact: SupportContact.empty),
          ),
          Gap(18.h),
          SizedBox(
            width: double.infinity,
            height: 55.h,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: _ContactSheetPalette.primaryRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRows extends StatelessWidget {
  const _ContactRows({required this.contact});

  final SupportContact contact;

  @override
  Widget build(BuildContext context) {
    final phone = contact.supportPhone;
    final phoneDialable = contact.supportPhoneDialable;
    final email = contact.supportEmail;

    if (phone == null && email == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Text(
          'Support contact details are not available right now.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.sp,
            color: _ContactSheetPalette.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (phone != null && phoneDialable != null)
          _ContactRow(
            icon: PhosphorIcons.phone,
            label: 'Call $phone',
            onTap: () => launchUrl(Uri.parse('tel:$phoneDialable')),
          ),
        if (email != null)
          _ContactRow(
            icon: PhosphorIcons.envelope,
            label: 'Email $email',
            onTap: () => launchUrl(Uri.parse('mailto:$email')),
          ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18.sp, color: _ContactSheetPalette.primaryRed),
            Gap(10.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  color: _ContactSheetPalette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
