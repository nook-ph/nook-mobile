import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Why the cafe page could not load: one of the app's four error messages,
/// or a cafe that no longer exists.
///
/// The data source wraps every failure in [CafeFetchException], which on its
/// own reads as "unknown". This looks through the wrapper at the real cause,
/// so offline, signed-out and server failures get their own copy, and a
/// missing row gets its own page.
class CafeLoadFailure {
  const CafeLoadFailure._({required this.isNotFound, required this.info});

  /// The cafe id matched no row (deleted, unpublished, or a bad link).
  final bool isNotFound;

  /// Copy for every other failure. Unused when [isNotFound].
  final ErrorInfo info;

  /// PostgREST's "JSON object requested, multiple (or no) rows returned",
  /// which `.single()` raises for an id with no row.
  static const _noRowsCode = 'PGRST116';

  /// Postgres "invalid input syntax": an id that is not a UUID at all,
  /// e.g. a mangled deep link.
  static const _invalidInputCode = '22P02';

  static CafeLoadFailure from(Object error) {
    final cause = unwrap(error);
    if (cause is PostgrestException) {
      final code = cause.code?.trim();
      if (code == _noRowsCode || code == _invalidInputCode) {
        return CafeLoadFailure._(
          isNotFound: true,
          info: AppErrorCopy.fromException(cause),
        );
      }
    }
    // The http client reports a dropped connection as a ClientException
    // rather than the SocketException underneath it.
    final classified = cause is http.ClientException
        ? const SocketException('Connection failed')
        : cause;
    return CafeLoadFailure._(
      isNotFound: false,
      info: AppErrorCopy.fromException(classified),
    );
  }

  /// The innermost cause behind any [CafeFetchException] wrappers.
  static Object unwrap(Object error) {
    var current = error;
    while (current is CafeFetchException && current.cause != null) {
      current = current.cause!;
    }
    return current;
  }
}
