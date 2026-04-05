import 'package:equatable/equatable.dart';

abstract class ReviewsEvent extends Equatable {
  const ReviewsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReviewsRequested extends ReviewsEvent {
  const LoadReviewsRequested({required this.cafeId});

  final String cafeId;

  @override
  List<Object?> get props => [cafeId];
}
