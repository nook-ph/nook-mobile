import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:nook/features/map/domain/repositories/i_cafe_tags_repository.dart';

class GetFilterTagsUseCase {
  final ICafeTagsRepository repository;

  GetFilterTagsUseCase(this.repository);

  Future<List<CafeTagsEntity>> call() {
    return repository.filterTags();
  }
}
