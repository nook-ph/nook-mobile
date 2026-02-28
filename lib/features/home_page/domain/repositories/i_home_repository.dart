import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

abstract class IHomeRepository {
  Future <List<CafeSummaryEntity>> getFeaturedCafes();
  Future <List<CafeSummaryEntity>> getRecommendedCafes();
}                                     