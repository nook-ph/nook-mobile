import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  ErrorType typeOf(Object error) => AppErrorCopy.fromException(error).type;

  CafeFetchException wrapped(Object cause) =>
      CafeFetchException('Failed to fetch cafe summaries.', cause: cause);

  test('looks through the cafe data source wrapper (H-1)', () {
    expect(
      typeOf(wrapped(const SocketException('Failed host lookup'))),
      ErrorType.offline,
    );
    expect(typeOf(wrapped(TimeoutException('slow'))), ErrorType.offline);
    expect(
      typeOf(wrapped(const AuthException('JWT expired'))),
      ErrorType.sessionExpired,
    );
    expect(
      typeOf(wrapped(const PostgrestException(message: 'boom', code: '500'))),
      ErrorType.serverError,
    );
    expect(
      typeOf(wrapped(wrapped(const SocketException('nested')))),
      ErrorType.offline,
    );
  });

  test('a dropped connection from the http client is offline', () {
    final dropped = http.ClientException('Connection closed');
    expect(typeOf(dropped), ErrorType.offline);
    expect(typeOf(wrapped(dropped)), ErrorType.offline);
  });

  test('a wrapper with no cause stays unknown', () {
    expect(
      typeOf(const CafeFetchException('Failed to parse.')),
      ErrorType.unknown,
    );
  });
}
