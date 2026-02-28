import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

abstract class CafeDetailsStates {}

class CafeDetailsInitialState extends CafeDetailsStates {}

class CafeDetailsLodingState extends CafeDetailsStates {}

class CafeDetailsLoadedState extends CafeDetailsStates {
  final CafeDetailsEntity cafeDetails;
  final List<MenuItemEntity> menuHighlights;
  final List<MenuItemEntity> allMenuItems;
  final List<ReviewEntity> latestReviews;
  final List<ReviewEntity> allReviews;

  CafeDetailsLoadedState({
    required this.cafeDetails,
    required this.menuHighlights,
    required this.allMenuItems,
    required this.latestReviews,
    required this.allReviews,
  });
}
