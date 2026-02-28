import 'package:equatable/equatable.dart';

abstract class CafeDetailsEvent extends Equatable {
  const CafeDetailsEvent();

  @override
  List<Object?> get props => [];
}

class LoadCafeDetailsRequested extends CafeDetailsEvent {
  final String cafeId;
  final int menuHighlightsLimit;
  final int latestReviewsLimit;

  const LoadCafeDetailsRequested({
    required this.cafeId,
    this.menuHighlightsLimit = 3,
    this.latestReviewsLimit = 5,
  });

  @override
  List<Object?> get props => [cafeId, menuHighlightsLimit, latestReviewsLimit]; 
}