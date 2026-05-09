class UploadException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const UploadException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => cause != null
      ? 'UploadException: $message\nCaused by: $cause'
      : 'UploadException: $message';
}
