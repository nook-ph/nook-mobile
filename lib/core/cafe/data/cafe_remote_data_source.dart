import 'package:nook/features/cafe_details/data/models/cafe_details_model.dart';
import 'package:nook/features/home_page/data/models/cafe_summary_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeRemoteDataSource {
  final SupabaseClient supabase;

  CafeRemoteDataSource(this.supabase);

  Future<List<CafeSummaryModel>> fetchSummaries({
    required String type,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final normalizedType = type.trim().toLowerCase();
      final start = page * limit;
      final end = start + limit - 1;

      const selectClause = '''
      id,
      name,
      address,
      rating,
      featured_image_url,
      system_badge,
      cafe_tags ( is_featured, tags ( name ) )
    ''';

      late final List response;

      switch (normalizedType) {
        case 'featured':
          response = await supabase
              .from('cafes')
              .select(selectClause)
              .not('system_badge', 'is', null)
              .range(start, end);
          break;
        case 'recommended':
          response = await supabase
              .from('cafes')
              .select(selectClause)
              .order('rating', ascending: false)
              .range(start, end);
          break;
        case 'nearby':
          response = await supabase
              .from('cafes')
              .select(selectClause)
              .order('created_at', ascending: false)
              .range(start, end);
          break;
        default:
          throw CafeFetchException(
            'Unsupported summary type: $type. Expected featured, recommended, or nearby.',
          );
      }

      return response
          .map(
            (json) =>
                CafeSummaryModel.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
    } on PostgrestException catch (e, st) {
      throw CafeFetchException(
        'Failed to fetch cafe summaries for type "$type".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CafeFetchException) rethrow;
      throw CafeFetchException(
        'Failed to fetch cafe summaries for type "$type".',
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
          created_at,
          updated_at,
          profiles (
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
