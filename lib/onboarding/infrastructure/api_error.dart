// Lightweight API error to carry HTTP status, message, code and raw body.
class ApiError implements Exception {
  final int status;
  final String message;
  final Object? code;
  final String? raw;

  const ApiError({
    required this.status,
    required this.message,
    this.code,
    this.raw,
  });

  @override
  String toString() => 'ApiError(status=$status, code=$code, message=$message)';
}
