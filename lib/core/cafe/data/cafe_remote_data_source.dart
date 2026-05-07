import 'package:flutter/foundation.dart';
import 'package:nook/features/cafe_details/data/models/cafe_details_model.dart';
import 'package:nook/core/cafe/data/cafe_summary_model.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeRemoteDataSource {
  final SupabaseClient supabase;

  CafeRemoteDataSource(this.supabase);

  Future<List<CafeSummaryModel>> fetchCafes({required CafeQuery query}) async {
    final params = query.toRpcParams();

    try {
      final rpcResponse = await supabase.rpc('get_cafes', params: params);

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
        'city',
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
        // Menu items are fetched via RPC to include variants.
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

      final payload = Map<String, dynamic>.from(response);
      if (includeMenu) {
        payload['menu_items'] = await _fetchMenuItemsByCafeId(cafeId);
      }

      return CafeBundleModel.fromJson(
        payload,
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

  //lists

  Future<String> fetchDefaultListId({String? userId}) async {
    try {
      final resolvedUserId = _resolveUserId(userId);
      final response = await supabase
          .from('list_members')
          .select('list_id')
          .eq('user_id', resolvedUserId)
          .eq('is_default', true)
          .single();
      return response['list_id'] as String;
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch default list id.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserLists() async {
    try {
      final userId = _resolveUserId(null);
      final response = await supabase
          .from('list_members')
          .select('''
              list_id,
              role,
              is_default,
              lists (
                id,
                name,
                description,
                cover_image_url,
                is_public,
                cafe_count,
                created_at,
                updated_at
              )
            ''')
          .eq('user_id', userId)
          .eq('role', 'owner')
          .order('is_default', ascending: false);
      return (response as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch user lists.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<List<CafeSummaryModel>> fetchListCafes(String listId) async {
    try {
      final response = await supabase
          .from('list_cafes')
          .select('''
              added_at,
              cafe:cafes!list_cafes_cafe_id_fkey (
                id,
                name,
                address,
                neighborhood,
                city,
                rating,
                featured_image_url,
                cafe_tags ( is_featured, tags ( name ) )
              )
            ''')
          .eq('list_id', listId)
          .order('added_at', ascending: false);
      return (response as List)
          .map((row) => Map<String, dynamic>.from(row))
          .map((row) => row['cafe'])
          .whereType<Map>()
          .map((cafe) => Map<String, dynamic>.from(cafe))
          .map(CafeSummaryModel.fromJson)
          .toList();
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch cafes for list "$listId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<Set<String>> fetchCafeListMemberships(
    String cafeId,
    List<String> listIds,
  ) async {
    if (listIds.isEmpty) return const {};

    try {
      final response = await supabase
          .from('list_cafes')
          .select('list_id')
          .eq('cafe_id', cafeId)
          .inFilter('list_id', listIds);

      return (response as List)
          .whereType<Map>()
          .map((row) => row['list_id']?.toString())
          .whereType<String>()
          .toSet();
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch list memberships for cafe "$cafeId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> isCafeInList(String listId, String cafeId) async {
    try {
      final response = await supabase
          .from('list_cafes')
          .select('cafe_id')
          .eq('list_id', listId)
          .eq('cafe_id', cafeId)
          .limit(1);

      return (response as List).isNotEmpty;
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to check cafe "$cafeId" in list "$listId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> addCafeToList(String listId, String cafeId) async {
    try {
      final userId = _resolveUserId(null);
      final shouldUseCafeAsCover = await _isListEmpty(listId);

      await supabase.from('list_cafes').upsert({
        'list_id': listId,
        'cafe_id': cafeId,
        'added_by': userId,
      });

      if (shouldUseCafeAsCover) {
        final coverImageUrl = await _fetchCafeHeroImageUrl(cafeId);
        if (coverImageUrl != null) {
          await supabase
              .from('lists')
              .update({'cover_image_url': coverImageUrl})
              .eq('id', listId);
        }
      }
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to add cafe "$cafeId" to list "$listId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> _isListEmpty(String listId) async {
    final response = await supabase
        .from('list_cafes')
        .select('cafe_id')
        .eq('list_id', listId)
        .limit(1);

    return (response as List).isEmpty;
  }

  Future<String?> _fetchCafeHeroImageUrl(String cafeId) async {
    final response = await supabase
        .from('cafes')
        .select('featured_image_url')
        .eq('id', cafeId)
        .single();
    final coverImageUrl = response['featured_image_url']?.toString().trim();

    return coverImageUrl == null || coverImageUrl.isEmpty
        ? null
        : coverImageUrl;
  }

  /// Recomputes `lists.cover_image_url` after membership changes so the cover stays in sync:
  /// uses the **newest remaining** café (`added_at` desc) whose `featured_image_url` is set;
  /// clears the URL when the list is empty or no remaining café has a hero image.
  Future<void> _refreshListCoverAfterMembershipChange(String listId) async {
    try {
      final response = await supabase
          .from('list_cafes')
          .select('''
              added_at,
              cafe:cafes!list_cafes_cafe_id_fkey ( featured_image_url )
            ''')
          .eq('list_id', listId)
          .order('added_at', ascending: false)
          .limit(50);

      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      String? coverUrl;
      for (final row in rows) {
        final cafe = row['cafe'];
        if (cafe is! Map) continue;
        final raw = cafe['featured_image_url']?.toString().trim();
        if (raw != null && raw.isNotEmpty) {
          coverUrl = raw;
          break;
        }
      }

      await supabase
          .from('lists')
          .update({'cover_image_url': coverUrl})
          .eq('id', listId);
    } catch (e, st) {
      debugPrint(
        '[Lists] cover_image_url refresh failed for list="$listId": $e\n$st',
      );
    }
  }

  Future<void> removeCafeFromList(String listId, String cafeId) async {
    try {
      await supabase
          .from('list_cafes')
          .delete()
          .eq('list_id', listId)
          .eq('cafe_id', cafeId);
      await _refreshListCoverAfterMembershipChange(listId);
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to remove cafe "$cafeId" from list "$listId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Deletes [cafeId] from all lists owned by the current user (same scope as [fetchUserLists]).
  Future<void> removeCafeFromAllUserLists(String cafeId) async {
    try {
      final userId = _resolveUserId(null);
      final memberRows = await supabase
          .from('list_members')
          .select('list_id')
          .eq('user_id', userId)
          .eq('role', 'owner');

      final listIds = (memberRows as List)
          .whereType<Map>()
          .map((row) => row['list_id']?.toString())
          .whereType<String>()
          .toList(growable: false);

      if (listIds.isEmpty) return;

      final affectedResponse = await supabase
          .from('list_cafes')
          .select('list_id')
          .eq('cafe_id', cafeId)
          .inFilter('list_id', listIds);

      final affectedListIds = (affectedResponse as List)
          .whereType<Map>()
          .map((row) => row['list_id']?.toString())
          .whereType<String>()
          .toSet();

      await supabase
          .from('list_cafes')
          .delete()
          .eq('cafe_id', cafeId)
          .inFilter('list_id', listIds);

      for (final listId in affectedListIds) {
        await _refreshListCoverAfterMembershipChange(listId);
      }
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to remove cafe "$cafeId" from all user lists.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<String> createList({required String name, String? description}) async {
    try {
      debugPrint(
        '[Lists] RPC create_new_list start '
        'nameLength=${name.trim().length} '
        'hasDescription=${description?.trim().isNotEmpty == true}',
      );
      final response = await supabase.rpc(
        'create_new_list',
        params: {'list_name': name, 'list_description': description},
      );
      debugPrint('[Lists] RPC create_new_list success response=$response');
      return response as String;
    } on PostgrestException catch (e, st) {
      debugPrint(
        '[Lists] RPC create_new_list PostgrestException '
        'code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}',
      );
      debugPrint('[Lists] RPC create_new_list stackTrace=$st');
      throw CafeFetchException(
        'Failed to create list "$name".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      debugPrint('[Lists] RPC create_new_list unexpected error=$e');
      debugPrint('[Lists] RPC create_new_list stackTrace=$st');
      throw CafeFetchException(
        'Failed to create list "$name".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteList(String listId) async {
    try {
      await supabase.from('lists').delete().eq('id', listId);
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to delete list "$listId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> renameList(String listId, String name) async {
    try {
      await supabase.from('lists').update({'name': name}).eq('id', listId);
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to rename list "$listId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  String _resolveUserId(String? userId) {
    final resolved = userId ?? supabase.auth.currentUser?.id;
    if (resolved == null || resolved.isEmpty) {
      throw const CafeFetchException('No authenticated user for lists.');
    }
    return resolved;
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

  //lists stuff
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

//lists stuff
