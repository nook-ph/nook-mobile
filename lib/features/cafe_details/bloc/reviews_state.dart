import 'package:equatable/equatable.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

abstract class ReviewsState extends Equatable {
  const ReviewsState();

  @override
  List<Object?> get props => [];
}

class ReviewsInitial extends ReviewsState {
  const ReviewsInitial();
}

class ReviewsLoading extends ReviewsState {
  const ReviewsLoading();
}

class ReviewsLoaded extends ReviewsState {
  const ReviewsLoaded({required this.cafeId, required this.reviews});

  final String cafeId;
  final List<ReviewEntity> reviews;

  @override
  List<Object?> get props => [cafeId, reviews];
}

class ReviewsError extends ReviewsState {
  const ReviewsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
