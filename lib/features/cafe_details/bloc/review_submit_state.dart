import 'package:equatable/equatable.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

abstract class ReviewSubmitState extends Equatable {
  const ReviewSubmitState();

  @override
  List<Object?> get props => [];
}

class ReviewSubmitInitial extends ReviewSubmitState {
  const ReviewSubmitInitial();
}

class ReviewSubmitting extends ReviewSubmitState {
  const ReviewSubmitting();
}

class ReviewSubmitSuccess extends ReviewSubmitState {
  const ReviewSubmitSuccess({required this.review});

  final ReviewEntity review;

  @override
  List<Object?> get props => [review];
}

class ReviewSubmitError extends ReviewSubmitState {
  const ReviewSubmitError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
