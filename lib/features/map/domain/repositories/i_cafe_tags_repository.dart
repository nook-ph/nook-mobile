import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';

abstract class ICafeTagsRepository {
  Future<List<CafeTagsEntity>> filterTags();
}
