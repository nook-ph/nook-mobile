import 'dart:io';

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
    this.photos = const [],
    this.accessToken,
  });

  final String cafeId;
  final String userId;
  final int rating;
  final String content;
  final List<File> photos;
  final String? accessToken;

  @override
  List<Object?> get props => [
    cafeId,
    userId,
    rating,
    content,
    photos,
    accessToken,
  ];
}
