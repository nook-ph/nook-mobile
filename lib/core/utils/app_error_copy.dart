import 'dart:async';
import 'dart:io';

import 'package:nook/core/utils/error_info.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps raw thrown values to calm, user-facing copy.
///
/// **AuthException:** For list/detail fetch failures, mapping every
/// [AuthException] to [ErrorType.sessionExpired] matches product needs.
/// Login and signup screens often throw [AuthException] for invalid
/// credentials — those call sites should not use this mapper for form
/// errors, or should build an [ErrorInfo] manually instead.
class AppErrorCopy {
  AppErrorCopy._();

  static ErrorInfo fromException(Object error) {
    final type = _classify(error);
    switch (type) {
      case ErrorType.offline:
        return const ErrorInfo(
          type: ErrorType.offline,
          title: "You're offline",
          subtitle: 'Check your connection and try again',
        );
      case ErrorType.sessionExpired:
        return const ErrorInfo(
          type: ErrorType.sessionExpired,
          title: "You've been signed out",
          subtitle: 'Sign in to continue',
        );
      case ErrorType.serverError:
        return const ErrorInfo(
          type: ErrorType.serverError,
          title: 'Something went wrong',
          subtitle: 'Try again in a moment',
        );
      case ErrorType.unknown:
        return const ErrorInfo(
          type: ErrorType.unknown,
          title: "We couldn't complete that",
          subtitle: 'Try again in a moment',
        );
    }
  }

  static ErrorType _classify(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return ErrorType.offline;
    }
    if (error is AuthException) {
      return ErrorType.sessionExpired;
    }
    if (error is PostgrestException) {
      final code = error.code?.trim().toLowerCase();
      if (code == '401' || code == '403') {
        return ErrorType.sessionExpired;
      }
      return ErrorType.serverError;
    }
    return ErrorType.unknown;
  }
}
