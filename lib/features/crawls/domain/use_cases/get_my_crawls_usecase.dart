import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class GetMyCrawlsUseCase {
  final ICrawlRepository repository;

  GetMyCrawlsUseCase(this.repository);

  Future<MyCrawls> call() => repository.getMyCrawls();
}
