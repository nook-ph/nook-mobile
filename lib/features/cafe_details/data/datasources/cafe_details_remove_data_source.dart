import 'package:nook/features/cafe_details/data/models/cafe_details_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeDetailsRemoteDataSource {
  final SupabaseClient supabase;

  CafeDetailsRemoteDataSource(this.supabase);

  Future<CafeDetailsModel> fetchCafeDetailsBase(String cafeId) async {
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
          rating,
          review_count,
          is_new,
          operating_hours,
          social_links
        ''')
        .eq('id', cafeId)
        .single();

    return CafeDetailsModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<MenuItemModel>> fetchCafeMenuItems(
    String cafeId, {
    bool? isHighlight,
    int limit = 100,
    int offset = 0,
  }) async {
    var query = supabase
        .from('menu_items')
        .select('id, cafe_id, name, price, image_url, is_highlight')
        .eq('cafe_id', cafeId);

    if (isHighlight != null) {
      query = query.eq('is_highlight', isHighlight);
    }

    final response = await query
        .order('is_highlight', ascending: false)
        .order('name')
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TagModel>> fetchCafeTags(String cafeId) async {
    final response = await supabase
        .from('cafe_tags')
        .select('''
          is_featured,
          tags (
            id,
            name,
            category,
            icon_name,
            created_at
          )
        ''')
        .eq('cafe_id', cafeId);

    return (response as List).map((row) {
      final map = Map<String, dynamic>.from(row);
      final tagMap = map['tags'] is Map
          ? Map<String, dynamic>.from(map['tags'] as Map)
          : <String, dynamic>{};

      return TagModel.fromJson({...tagMap, 'is_featured': map['is_featured']});
    }).toList();
  }

  Future<List<ReviewModel>> fetchCafeReviews(
    String cafeId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await supabase
        .from('reviews')
        .select('''
          id,
          cafe_id,
          user_id,
          rating,
          content,
          created_at,
          updated_at,
          profiles (
            name,
            full_name
          )
        ''')
        .eq('cafe_id', cafeId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
