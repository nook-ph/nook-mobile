import 'package:nook/features/home_page/data/models/cafe_summary_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeRemoteDataSource {
  final SupabaseClient supabase;

  HomeRemoteDataSource(this.supabase);

  Future<List<CafeSummaryModel>> fetchFeaturedCafes() async {
    final response = await supabase
        .from('cafes')
        .select('''
      id, 
      name, 
      address, 
      rating, 
      featured_image_url, 
      system_badge, 
      cafe_tags ( is_featured, tags ( name ) )
    ''')
        .not('system_badge', 'is', null)
        .limit(5);

    return (response as List)
        .map((json) => CafeSummaryModel.fromJson(json))
        .toList();
  }

  Future<List<CafeSummaryModel>> fetchRecommendedCafes() async {
    final response = await supabase
        .from('cafes')
        .select('''
      id, 
      name, 
      address, 
      rating, 
      featured_image_url, 
      system_badge, 
      cafe_tags ( is_featured, tags ( name ) )
    ''')
        .order('rating', ascending: false)
        .limit(10);

    return (response as List)
        .map((json) => CafeSummaryModel.fromJson(json))
        .toList();
  }
}
