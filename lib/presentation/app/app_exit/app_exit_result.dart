// Result type describing the outcome of a close-app request.
class AppExitResult {
  final bool success;
  final bool needsUserAction;
  final String message;

  const AppExitResult({
    required this.success,
    required this.needsUserAction,
    required this.message,
  });

  factory AppExitResult.success([String msg = '']) =>
      AppExitResult(success: true, needsUserAction: false, message: msg);

  factory AppExitResult.unsupported([String msg = '']) =>
      AppExitResult(success: false, needsUserAction: true, message: msg);

  factory AppExitResult.failed([String msg = '']) =>
      AppExitResult(success: false, needsUserAction: false, message: msg);
}
