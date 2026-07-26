/// Classification for user-facing error messaging (see `AppErrorCopy`).
enum ErrorType { offline, sessionExpired, serverError, unknown }

/// Stable copy + type for error UI (full page or section).
class ErrorInfo {
  const ErrorInfo({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final ErrorType type;
  final String title;
  final String subtitle;
}
