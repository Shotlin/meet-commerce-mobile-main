import 'package:bakaloo_flutter_app/core/errors/failure.dart';

sealed class AppException implements Exception {
  const AppException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;
}

class NetworkException extends AppException {
  const NetworkException({required super.message, super.statusCode});
}

class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode});
}

class AuthException extends AppException {
  const AuthException({required super.message, super.statusCode});
}

class NotFoundException extends AppException {
  const NotFoundException({required super.message, super.statusCode});
}

class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.statusCode,
    this.errors,
  });

  final List<String>? errors;
}

class RateLimitException extends AppException {
  const RateLimitException({
    required super.message,
    super.statusCode,
    this.resetAt,
  });

  final DateTime? resetAt;
}

class CacheException extends AppException {
  const CacheException({required super.message, super.statusCode});
}

class UnknownException extends AppException {
  const UnknownException({required super.message, super.statusCode});
}

extension FailureToException on Failure {
  AppException toException() {
    return switch (this) {
      NetworkFailure() => NetworkException(message: message),
      ServerFailure() => ServerException(message: message),
      AuthFailure() => AuthException(message: message),
      NotFoundFailure() => NotFoundException(message: message),
      ValidationFailure(:final errors) => ValidationException(
          message: message,
          errors: errors,
          statusCode: 400,
        ),
      RateLimitFailure(:final resetAt) => RateLimitException(
          message: message,
          resetAt: resetAt,
          statusCode: 429,
        ),
      CacheFailure() => CacheException(message: message),
      UnknownFailure() => UnknownException(message: message),
    };
  }
}

extension AppExceptionToFailure on AppException {
  Failure toFailure() {
    return switch (this) {
      NetworkException() => NetworkFailure(message: message),
      ServerException() => ServerFailure(message: message),
      AuthException() => AuthFailure(message: message),
      NotFoundException() => NotFoundFailure(message: message),
      ValidationException(:final errors) => ValidationFailure(
          message: message,
          errors: errors,
        ),
      RateLimitException(:final resetAt) => RateLimitFailure(
          message: message,
          resetAt: resetAt,
        ),
      CacheException() => CacheFailure(message: message),
      UnknownException() => UnknownFailure(message: message),
    };
  }
}
