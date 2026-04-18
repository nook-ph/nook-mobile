import 'package:equatable/equatable.dart';

abstract class ReviewsEvent extends Equatable {
  const ReviewsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReviewsRequested extends ReviewsEvent {
  const LoadReviewsRequested({
    required this.cafeId,
    this.sort = 'recommended',
    this.ratingFilter,
  });

  final String cafeId;
  final String sort;
  final int? ratingFilter;

  @override
  List<Object?> get props => [cafeId, sort, ratingFilter];
}
