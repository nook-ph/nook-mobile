import 'dart:async';

import 'package:http/http.dart' as http;

/// Gives every request a deadline for its response to start, so a stalled
/// network ends in a [TimeoutException] (shown as "You're offline") instead
/// of a spinner that waits for the OS to give up. Supabase's REST, RPC,
/// auth and function calls go through it; photo uploads use their own
/// client and timeouts.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient({
    this.timeout = const Duration(seconds: 20),
    http.Client? inner,
  }) : _inner = inner ?? http.Client();

  final Duration timeout;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(timeout);

  @override
  void close() => _inner.close();
}
