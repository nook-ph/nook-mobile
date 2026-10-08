import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/features/public_profile/data/public_profile_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "@" people search goes through the `search_people` RPC, which applies
/// blocks in both directions (nook-supabase
/// 20261008161000_blocks_both_ways_gallery_and_search.sql). Reading
/// `profiles` directly listed people who had blocked you, and people you had
/// blocked.
void main() {
  late List<http.Request> requests;

  PublicProfileRepositoryImpl repo(Object body) {
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    return PublicProfileRepositoryImpl(
      client: SupabaseClient(
        'http://localhost:54321',
        'anon',
        httpClient: client,
      ),
    );
  }

  setUp(() => requests = []);

  test('calls search_people with the prefix and limit', () async {
    await repo(<Object>[]).searchPeople('cr', limit: 3);

    final request = requests.single;
    expect(request.url.path, '/rest/v1/rpc/search_people');
    expect(jsonDecode(request.body), {'p_prefix': 'cr', 'p_limit': 3});
  });

  test('parses rows in the order the server sends them', () async {
    final people = await repo([
      {'id': 'u1', 'username': 'cris', 'full_name': 'Cris', 'avatar_url': null},
      {
        'id': 'u2',
        'username': 'crislucero',
        'full_name': null,
        'avatar_url': 'https://x/a.jpg',
      },
      // A row without a username can't be shown as @name: skipped.
      {'id': 'u3', 'username': null, 'full_name': 'X', 'avatar_url': null},
    ]).searchPeople('cr');

    expect(people.map((p) => p.username), ['cris', 'crislucero']);
    expect(people.first.userId, 'u1');
    expect(people.first.fullName, 'Cris');
    expect(people.last.avatarUrl, 'https://x/a.jpg');
  });
}
