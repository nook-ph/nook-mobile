import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/auth/data/datasources/supabase_auth_remote_data_source.dart';
import 'package:nook/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRemoteDataSource implements SupabaseAuthRemoteDataSource {
  Object? error;

  @override
  Future<void> signInWithGoogle() async {
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<void> signInWithApple() async {
    final e = error;
    if (e != null) throw e;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRemoteDataSource remote;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = _FakeRemoteDataSource();
    repository = AuthRepositoryImpl(remote);
  });

  String messageOf(dynamic either) =>
      either.fold((failure) => failure.message, (_) => 'ok') as String;

  test('a dismissed provider sheet stays the bare CANCELED marker '
      '(A-5)', () async {
    remote.error = const AuthException('CANCELED');

    expect(messageOf(await repository.signInWithGoogle()), 'CANCELED');
    expect(messageOf(await repository.signInWithApple()), 'CANCELED');
  });

  test('provider errors keep their message, not the exception dump', () async {
    remote.error = const AuthException('Google Sign-In failed (unknown).');
    expect(
      messageOf(await repository.signInWithGoogle()),
      'Google Sign-In failed (unknown).',
    );

    remote.error = StateError('plugin blew up');
    expect(
      messageOf(await repository.signInWithApple()),
      'Apple Sign-In failed. Please try again.',
    );

    remote.error = AuthRetryableFetchException(message: 'SocketException');
    expect(
      messageOf(await repository.signInWithGoogle()),
      'Connection failed. Check your internet.',
    );
  });
}
