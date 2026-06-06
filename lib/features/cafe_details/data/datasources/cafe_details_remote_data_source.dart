import 'package:nook/features/cafe_details/data/models/cafe_details_model.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeDetailsRemoteDataSource {
  final SupabaseClient supabase;

  CafeDetailsRemoteDataSource(this.supabase);

  Future<CafeDetailsModel> fetchDetailsById(String cafeId) async {
    try {
      final response = await supabase
          .from('cafes')
          .select('''
        id,
        created_at,
        name,
        description,
        address,
        neighborhood,
        city,
        lat,
        lng,
        featured_image_url,
        photo_urls,
        rating,
        review_count,
        is_new,
        operating_hours,
        social_links,
        cafe_tags (
          is_featured,
          tags!cafe_tags_tag_id_fkey (
            id,
            name,
            category,
            created_at
          )
        )
      ''')
          .eq('id', cafeId)
          .single();
      final menuItems = await _fetchMenuItemsByCafeId(cafeId);
      final payload = Map<String, dynamic>.from(response);
      payload['menu_items'] = menuItems;
      return CafeDetailsModel.fromJson(payload);
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch cafe details for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch cafe details for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<List<ReviewModel>> fetchReviewsByCafeId(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      final rpcResponse = await supabase.rpc(
        'get_reviews_with_vote_status',
        params: {
          'p_cafe_id': cafeId,
          'p_user_id': userId,
          'p_sort': sort,
          'p_rating_filter': ratingFilter,
        },
      );

      return (rpcResponse as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(ReviewModel.fromJson)
          .toList();
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch cafe reviews for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CafeFetchException) rethrow;
      throw CafeFetchException(
        'Failed to fetch cafe reviews for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> toggleHelpfulVote({
    required String reviewId,
    required String userId,
    required bool currentlyVoted,
  }) async {
    try {
      if (currentlyVoted) {
        await supabase
            .from('review_helpful_votes')
            .delete()
            .eq('review_id', reviewId)
            .eq('user_id', userId);
      } else {
        await supabase.from('review_helpful_votes').insert({
          'review_id': reviewId,
          'user_id': userId,
        });
      }
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to toggle helpful vote for review "$reviewId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CafeFetchException) rethrow;
      throw CafeFetchException(
        'Failed to toggle helpful vote for review "$reviewId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<ReviewModel> insertReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    try {
      final response = await supabase
          .from('reviews')
          .insert({
            'cafe_id': cafeId,
            'user_id': userId,
            'rating': rating,
            'content': content,
            'image_urls': imageUrls,
          })
          .select('''
            id,
            cafe_id,
            user_id,
            rating,
            content,
            image_urls,
            created_at,
            updated_at,
            profile:profiles!reviews_user_id_fkey (
              username,
              full_name
            )
          ''')
          .single();

      return ReviewModel.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to insert review for cafe id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw CafeFetchException(
        'Failed to insert review for cafe id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMenuItemsByCafeId(
    String cafeId,
  ) async {
    final rpcResponse = await supabase.rpc(
      'get_menu_items',
      params: {'p_cafe_id': cafeId},
    );

    // RPC may return null when the cafe has no menu rows (Postgres / SQL).
    if (rpcResponse == null) {
      return const [];
    }
    if (rpcResponse is! List) {
      return const [];
    }

    return rpcResponse
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
