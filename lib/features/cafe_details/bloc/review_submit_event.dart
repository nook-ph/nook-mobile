import 'package:equatable/equatable.dart';

abstract class ReviewSubmitEvent extends Equatable {
  const ReviewSubmitEvent();

  @override
  List<Object?> get props => [];
}

class SubmitReviewRequested extends ReviewSubmitEvent {
  const SubmitReviewRequested({
    required this.cafeId,
    required this.userId,
    required this.rating,
    required this.content,
  });

  final String cafeId;
  final String userId;
  final int rating;
  final String content;

  @override
  List<Object?> get props => [cafeId, userId, rating, content];
}
