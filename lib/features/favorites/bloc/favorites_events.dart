import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

abstract class FavoritesEvent {}

class LoadFavoritesEvent extends FavoritesEvent {
  final String? userId;

  LoadFavoritesEvent({this.userId});
}

class ToggleFavoriteEvent extends FavoritesEvent {
  final String cafeId;
  final CafeSummary cafe;
  final String? userId;

  ToggleFavoriteEvent(this.cafeId, this.cafe, {this.userId});
}
