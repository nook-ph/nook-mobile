import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRemoteDataSource {
  final SupabaseClient supabaseClient;

  const ProfileRemoteDataSource({required this.supabaseClient});

  Future<void> updateProfile({
    required String userId,
    String? name,
    String? bio,
    String? avatarUrl,
    String? username,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) updates['full_name'] = name;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (username != null) {
      // The same RPC signup uses: it checks the format and that no one else
      // holds the name in any letter case, which a plain update does not.
      await supabaseClient.rpc(
        'set_username',
        params: {'p_username': username},
      );
      updates['last_username_change'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    }

    if (updates.isEmpty) return;

    await supabaseClient.from('profiles').update(updates).eq('id', userId);
  }
}
