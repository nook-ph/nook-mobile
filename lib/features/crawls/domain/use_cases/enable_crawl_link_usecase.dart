import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

/// Opens a crawl to anyone holding its link or code, just before it is shared.
///
/// Crawls are created private, and a private crawl reads as "not found" to
/// everyone but its creator and run members, so a shared link or code would
/// lead nowhere. Only the creator can change this; for anyone else, and for a
/// crawl that is already open, this does nothing.
class EnableCrawlLinkUseCase {
  final ICrawlRepository repository;

  EnableCrawlLinkUseCase(this.repository);

  Future<void> call(Crawl crawl) async {
    if (!crawl.isCreator || crawl.isLinkVisible) return;
    await repository.enableCrawlLink(crawl.id);
  }
}
