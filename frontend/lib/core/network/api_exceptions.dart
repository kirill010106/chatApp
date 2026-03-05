class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = 'Unauthorized'])
      : super(message, statusCode: 401);
}

class NetworkException extends ApiException {
  NetworkException([String message = 'Network error'])
      : super(message);
}
