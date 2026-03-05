import 'package:nook/features/home_page/data/datasources/home_remote_data_source.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';
import 'package:nook/features/home_page/domain/repositories/i_home_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeRepositoryImpl implements IHomeRepository {
  final HomeRemoteDataSource remoteDataSource;

  HomeRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<CafeSummaryEntity>> getFeaturedCafes() async {
    try {
      return await remoteDataSource.fetchFeaturedCafes();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch featured cafes: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  @override
  Future<List<CafeSummaryEntity>> getRecommendedCafes() async {
    try {
      return await remoteDataSource.fetchRecommendedCafes();
    } on PostgrestException catch (e) {
      throw Exception(
        'Database error fetching recommended cafes: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
