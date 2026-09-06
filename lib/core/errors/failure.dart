sealed class Failure {
  const Failure({required this.message});

  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, this.errors});

  final List<String>? errors;
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({required super.message, this.resetAt});

  final DateTime? resetAt;
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class UnknownFailure extends Failure {
  const UnknownFailure({required super.message});
}
