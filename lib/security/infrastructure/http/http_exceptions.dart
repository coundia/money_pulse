/// Lightweight HTTP exceptions to distinguish 401 and others.
class HttpError implements Exception {
  final int statusCode;
  final String? message;
  HttpError(this.statusCode, {this.message});
  @override
  String toString() =>
      'HttpError($statusCode${message != null ? ': $message' : ''})';
}

class HttpUnauthorizedException extends HttpError {
  HttpUnauthorizedException({String? message}) : super(401, message: message);
}
