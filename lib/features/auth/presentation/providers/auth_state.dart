import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';

sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthOtpSent extends AuthState {
  const AuthOtpSent({required this.phone});

  final String phone;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user});

  final UserEntity user;
}

class AuthError extends AuthState {
  const AuthError({required this.message});

  final String message;
}
