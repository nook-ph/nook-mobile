import 'package:equatable/equatable.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';

sealed class CrawlDetailState extends Equatable {
  const CrawlDetailState();

  @override
  List<Object?> get props => [];
}

class CrawlDetailInitial extends CrawlDetailState {
  const CrawlDetailInitial();
}

class CrawlDetailLoading extends CrawlDetailState {
  const CrawlDetailLoading();
}

class CrawlDetailLoaded extends CrawlDetailState {
  final CrawlDetail detail;

  const CrawlDetailLoaded(this.detail);

  int get totalStamps => detail.userProgress?.totalStamps ?? 0;
  int get totalStops => detail.stops.length;
  double get progressFraction =>
      totalStops > 0 ? totalStamps / totalStops : 0;

  @override
  List<Object?> get props => [detail];
}

class CrawlDetailError extends CrawlDetailState {
  final Failure failure;

  const CrawlDetailError(this.failure);

  @override
  List<Object?> get props => [failure];
}
