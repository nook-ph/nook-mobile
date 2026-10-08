import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/auth/data/datasources/supabase_auth_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({String provider = 'email', List<String>? providers}) => User(
  id: '11111111-2222-4333-8444-555555555555',
  appMetadata: {'provider': provider, 'providers': ?providers},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

void main() {
  late List<Map<String, dynamic>> sent;
  late int appleAsks;

  SupabaseAuthRemoteDataSource source({
    required User user,
    Future<String?> Function()? apple,
    int status = 200,
  }) {
    return SupabaseAuthRemoteDataSource(
      client: SupabaseClient('http://localhost', 'anon'),
      currentUser: () => user,
      appleReauthCode:
          apple ??
          () async {
            appleAsks++;
            return 'fresh-code';
          },
      invokeDeleteUser: (body) async {
        sent.add(body);
        return status;
      },
    );
  }

  setUp(() {
    sent = [];
    appleAsks = 0;
  });

  test('usesApple reads provider, providers and identities', () {
    expect(SupabaseAuthRemoteDataSource.usesApple(null), isFalse);
    expect(SupabaseAuthRemoteDataSource.usesApple(_user()), isFalse);
    expect(
      SupabaseAuthRemoteDataSource.usesApple(_user(provider: 'apple')),
      isTrue,
    );
    expect(
      SupabaseAuthRemoteDataSource.usesApple(
        _user(providers: ['email', 'apple']),
      ),
      isTrue,
    );
  });

  test('an Apple account re-confirms with Apple and sends the code', () async {
    await source(user: _user(provider: 'apple')).deleteAccount();
    expect(appleAsks, 1);
    expect(sent.single, {'appleAuthorizationCode': 'fresh-code'});
  });

  test('a non-Apple account never asks Apple', () async {
    await source(user: _user(provider: 'google')).deleteAccount();
    expect(appleAsks, 0);
    expect(sent.single, isEmpty);
  });

  test('cancelling Apple cancels the deletion', () async {
    final s = source(
      user: _user(provider: 'apple'),
      apple: () async => throw const AuthException(
        SupabaseAuthRemoteDataSource.appleDeleteCanceled,
      ),
    );
    await expectLater(s.deleteAccount(), throwsA(isA<AuthException>()));
    expect(sent, isEmpty);
  });

  test('no code (not iOS) still deletes, without one', () async {
    await source(
      user: _user(provider: 'apple'),
      apple: () async => null,
    ).deleteAccount();
    expect(sent.single, isEmpty);
  });

  test('a non-200 answer is an error', () async {
    await expectLater(
      source(user: _user(), status: 500).deleteAccount(),
      throwsA(isA<AuthException>()),
    );
  });
}
