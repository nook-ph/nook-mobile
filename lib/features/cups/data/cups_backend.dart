import 'package:flutter/foundation.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether [error] says an RPC does not exist on the server: PostgREST's
/// `PGRST202` ("Could not find the function ... in the schema cache"), or
/// Postgres' `42883` (undefined function) when it gets that far. Anything
/// else (a timeout, a permission error, a bad argument) is a real failure.
bool isMissingRpc(Object error) {
  if (error is! PostgrestException) return false;
  if (error.code == 'PGRST202' || error.code == '42883') return true;
  return error.message.contains('Could not find the function');
}

/// Decides, once per app run, whether the Cups RPCs exist, and routes each
/// call to them or to the legacy reviews + gallery paths.
///
/// The first call that reaches the server settles it: a missing-function
/// error flips to [CupsMode.legacy] and that same call is answered by the
/// legacy path, so nobody sees an error. A migration applied while the app
/// runs is picked up on the next launch.
class CupsBackend {
  CupsBackend({CupsMode initial = CupsMode.unknown}) : _mode = initial;

  CupsMode _mode;

  CupsMode get mode => _mode;

  /// For tests and the debug demo.
  @visibleForTesting
  set mode(CupsMode value) => _mode = value;

  Future<T> run<T>({
    required Future<T> Function() cups,
    required Future<T> Function() legacy,
  }) async {
    if (_mode == CupsMode.legacy) return legacy();
    try {
      final result = await cups();
      _mode = CupsMode.cups;
      return result;
    } catch (e) {
      if (!isMissingRpc(e)) rethrow;
      debugPrint('[Cups] RPCs not on this backend; using reviews + gallery');
      _mode = CupsMode.legacy;
      return legacy();
    }
  }
}
