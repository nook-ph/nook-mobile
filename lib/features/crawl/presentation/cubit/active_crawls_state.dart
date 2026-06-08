import 'package:equatable/equatable.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';

sealed class ActiveCrawlsState extends Equatable {
  const ActiveCrawlsState();

  @override
  List<Object?> get props => [];
}

class ActiveCrawlsLoading extends ActiveCrawlsState {
  const ActiveCrawlsLoading();
}

class ActiveCrawlsLoaded extends ActiveCrawlsState {
  final List<Crawl> crawls;
  final Set<String> registeredCrawlIds;

  const ActiveCrawlsLoaded(this.crawls, this.registeredCrawlIds);

  @override
  List<Object?> get props => [crawls, registeredCrawlIds];
}

class ActiveCrawlsError extends ActiveCrawlsState {
  final Failure failure;

  const ActiveCrawlsError(this.failure);

  @override
  List<Object?> get props => [failure];
}

class ActiveCrawlsEmpty extends ActiveCrawlsState {
  const ActiveCrawlsEmpty();
}
