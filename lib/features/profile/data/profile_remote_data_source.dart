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
      updates['username'] = username;
      updates['last_username_change'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    }

    if (updates.isEmpty) return;

    await supabaseClient.from('profiles').update(updates).eq('id', userId);
  }
}
