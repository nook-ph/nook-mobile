class ReviewImageUploadException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const ReviewImageUploadException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    return 'ReviewImageUploadException(message: $message, cause: $cause)';
  }
}
