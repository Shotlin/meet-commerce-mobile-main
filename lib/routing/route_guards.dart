import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';

part 'route_guards.g.dart';

@Riverpod(keepAlive: true)
class AuthGuard extends _$AuthGuard implements Listenable {
  VoidCallback? _listener;

  @override
  void build() {
    ref.listen<AuthState>(authStateProvider, (_, __) {
      _listener?.call();
    });
  }

  @override
  void addListener(VoidCallback listener) {
    _listener = listener;
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_listener == listener) {
      _listener = null;
    }
  }
}
