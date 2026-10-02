import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class CreateCrawlUseCase {
  final ICrawlRepository repository;

  CreateCrawlUseCase(this.repository);

  static const minStops = 3;
  static const maxStops = 6;
  static const minTitleLength = 3;
  static const maxTitleLength = 60;

  Future<Crawl> call({
    required String title,
    required List<String> cafeIds,
    String? sourceListId,
  }) {
    final trimmed = title.trim();
    if (trimmed.length < minTitleLength || trimmed.length > maxTitleLength) {
      throw ArgumentError(
        'Title must be $minTitleLength–$maxTitleLength characters.',
      );
    }
    if (cafeIds.length < minStops || cafeIds.length > maxStops) {
      throw ArgumentError('A crawl needs $minStops–$maxStops stops.');
    }
    return repository.createCrawl(
      title: trimmed,
      cafeIds: cafeIds,
      sourceListId: sourceListId,
    );
  }
}
