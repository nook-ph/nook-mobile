import 'package:nook/core/achievements/data/models/user_achievement_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class IAchievementRemoteDataSource {
  Future<List<UserAchievementModel>> getUserAchievements(String userId);
}

class AchievementRemoteDataSourceImpl implements IAchievementRemoteDataSource {
  final SupabaseClient supabase;

  AchievementRemoteDataSourceImpl(this.supabase);

  @override
  Future<List<UserAchievementModel>> getUserAchievements(String userId) async {
    try {
      final response = await supabase
          .from('user_achievements')
          .select('''
            id,
            user_id,
            earned_at,
            source_type,
            source_ref_id,
            metadata,
            is_visible,
            achievement_definitions!user_achievements_achievement_id_fkey (
              id,
              slug,
              name,
              description,
              category,
              source_type,
              source_id,
              badge_image_url,
              is_limited_edition,
              is_hidden,
              created_at
            )
          ''')
          .eq('user_id', userId)
          .eq('is_visible', true)
          .order('earned_at', ascending: false);

      return (response as List)
          .whereType<Map>()
          .map((item) => UserAchievementModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } on PostgrestException catch (e, st) {
      throw AchievementDataSourceException(
        'Failed to fetch achievements for user "$userId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is AchievementDataSourceException) rethrow;
      throw AchievementDataSourceException(
        'Failed to fetch achievements for user "$userId".',
        cause: e,
        stackTrace: st,
      );
    }
  }
}

class AchievementDataSourceException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AchievementDataSourceException(this.message,
      {this.cause, this.stackTrace});

  @override
  String toString() =>
      'AchievementDataSourceException(message: $message, cause: $cause)';
}
