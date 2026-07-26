import 'package:nook/features/map/data/datasources/cafe_tags_remote_data_source.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:nook/features/map/domain/repositories/i_cafe_tags_repository.dart';

class CafeTagsRepositoryImpl implements ICafeTagsRepository {
  final CafeTagsRemoteDataSource remoteDataSource;

  CafeTagsRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<CafeTagsEntity>> filterTags() async {
    return await remoteDataSource.filterTags();
  }
}
