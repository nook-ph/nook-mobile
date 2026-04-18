import 'package:nook/features/cafe_details/data/models/cafe_details_model.dart';
import 'package:nook/core/cafe/data/cafe_summary_model.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeRemoteDataSource {
  final SupabaseClient supabase;

  CafeRemoteDataSource(this.supabase);

  Future<List<CafeSummaryModel>> fetchCafes({required CafeQuery query}) async {
    try {
      final rpcResponse = await supabase.rpc(
        'get_cafes',
        params: query.toRpcParams(),
      );

      final response = (rpcResponse as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      return response.map((json) => CafeSummaryModel.fromJson(json)).toList();
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch cafe summaries for sort "${query.sort}".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CafeFetchException) rethrow;
      throw CafeFetchException(
        'Failed to fetch cafe summaries for sort "${query.sort}".',
        cause: e,
        stackTrace: st,
      );
    }
  }

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
        ),
        menu_items (
          id,
          cafe_id,
          name,
          price,
          image_url,
          is_highlight,
          menu_categories (
            id,
            name
          )
        )
      ''')
          .eq('id', cafeId)
          .single();

      return CafeDetailsModel.fromJson(Map<String, dynamic>.from(response));
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

  Future<CafeBundleModel> fetchBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  }) async {
    try {
      final fields = <String>[
        'id',
        'created_at',
        'name',
        'description',
        'address',
        'neighborhood',
        'lat',
        'lng',
        'featured_image_url',
        'photo_urls',
        'rating',
        'review_count',
        'is_new',
        'operating_hours',
        'social_links',
        '''
        cafe_tags (
          is_featured,
          tags!cafe_tags_tag_id_fkey (
            id,
            name,
            category,
            created_at
          )
        )
        ''',
      ];

      if (includeMenu) {
        fields.add('''
        menu_items (
          id,
          cafe_id,
          name,
          price,
          image_url,
          is_highlight,
          menu_categories (
            id,
            name
          )
        )
        ''');
      }

      if (includeReviews) {
        fields.add('''
        reviews (
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
        )
        ''');
      }

      final selectClause = fields.join(',');
      final response = await supabase
          .from('cafes')
          .select(selectClause)
          .eq('id', cafeId)
          .single();

      return CafeBundleModel.fromJson(
        Map<String, dynamic>.from(response),
        includeMenu: includeMenu,
        includeReviews: includeReviews,
      );
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch cafe bundle for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch cafe bundle for id "$cafeId".',
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
      final userId = supabase.auth.currentUser?.id ?? '';
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

  Future<List<CafeSummaryModel>> fetchFavorites({String? userId}) async {
    try {
      final resolvedUserId = _resolveUserId(userId);

      final response = await supabase
          .from('user_favorites')
          .select('''
          created_at,
          cafe:cafes!user_favorites_cafe_id_fkey (
            id,
            name,
            address,
            rating,
            featured_image_url,
            system_badge,
            cafe_tags ( is_featured, tags ( name ) )
          )
        ''')
          .eq('user_id', resolvedUserId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => Map<String, dynamic>.from(row))
          .map((row) => row['cafe'])
          .whereType<Map>()
          .map((cafe) => Map<String, dynamic>.from(cafe))
          .map(CafeSummaryModel.fromJson)
          .toList();
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch favorite cafes.',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch favorite cafes.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> addFavorite(String cafeId, {String? userId}) async {
    try {
      final resolvedUserId = _resolveUserId(userId);
      await supabase.from('user_favorites').upsert({
        'user_id': resolvedUserId,
        'cafe_id': cafeId,
      });
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to add favorite cafe for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw CafeFetchException(
        'Failed to add favorite cafe for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> removeFavorite(String cafeId, {String? userId}) async {
    try {
      final resolvedUserId = _resolveUserId(userId);
      await supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', resolvedUserId)
          .eq('cafe_id', cafeId);
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to remove favorite cafe for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw CafeFetchException(
        'Failed to remove favorite cafe for id "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  String _resolveUserId(String? userId) {
    final resolved = userId ?? supabase.auth.currentUser?.id;
    if (resolved == null || resolved.isEmpty) {
      throw const CafeFetchException('No authenticated user for favorites.');
    }
    return resolved;
  }
}

class CafeBundleModel {
  final CafeDetailsModel details;
  final List<MenuItemModel>? menu;
  final List<ReviewModel>? reviews;

  const CafeBundleModel({required this.details, this.menu, this.reviews});

  factory CafeBundleModel.fromJson(
    Map<String, dynamic> json, {
    required bool includeMenu,
    required bool includeReviews,
  }) {
    final details = CafeDetailsModel.fromJson(json);

    final menu = includeMenu
        ? _asList(
            json['menu_items'],
          ).map((item) => MenuItemModel.fromJson(item)).toList()
        : null;

    final reviews = includeReviews
        ? _asList(
            json['reviews'],
          ).map((item) => ReviewModel.fromJson(item)).toList()
        : null;

    return CafeBundleModel(details: details, menu: menu, reviews: reviews);
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }
}

class CafeFetchException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const CafeFetchException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => 'CafeFetchException(message: $message, cause: $cause)';
}
