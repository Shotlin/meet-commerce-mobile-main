import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class CartOrderingFor extends ConsumerWidget {
  const CartOrderingFor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final (name, phone) = switch (authState) {
      AuthAuthenticated(:final user) => (
          (user.name?.trim().isNotEmpty ?? false) ? user.name!.trim() : 'You',
          user.phone,
        ),
      _ => ('You', ''),
    };

    return Material(
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFF0F0F0)),
            bottom: BorderSide(color: Color(0xFFF0F0F0)),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF666666),
                    fontFamily: 'Inter',
                  ),
                  children: <InlineSpan>[
                    const TextSpan(text: 'Ordering for '),
                    TextSpan(
                      text: name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2196F3),
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (phone.trim().isNotEmpty) TextSpan(text: ', $phone'),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('${RouteNames.profile}/edit'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2196F3),
                minimumSize: Size(0, 32.h),
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Edit',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2196F3),
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
