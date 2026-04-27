import 'package:nook/features/map/data/models/cafe_tags_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';

abstract class CafeTagsRemoteDataSource {
  Future<List<CafeTagsEntity>> filterTags();
}

class CafeTagsRemoteDataSourceImpl implements CafeTagsRemoteDataSource {
  final SupabaseClient supabase;

  CafeTagsRemoteDataSourceImpl(this.supabase);

  @override
  Future<List<CafeTagsEntity>> filterTags() async {
    final response = await supabase.rpc('filter_tags');

    return (response as List)
        .map((json) => CafeTagsModel.fromJson(json))
        .toList();
  }
}
