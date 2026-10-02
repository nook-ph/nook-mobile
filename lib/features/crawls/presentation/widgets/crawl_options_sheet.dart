import 'package:flutter/material.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';

/// What the user picked from a crawl's "⋯" sheet.
enum CrawlOption { share, editTitle, archive, report }

/// The crawl detail "⋯" sheet. The creator can share, rename and archive;
/// everyone else can share and report.
class CrawlOptionsSheet extends StatelessWidget {
  const CrawlOptionsSheet({super.key, required this.crawl});

  final Crawl crawl;

  static Future<CrawlOption?> show(BuildContext context, Crawl crawl) {
    return CrawlSheet.show<CrawlOption>(
      context,
      builder: (_) => CrawlOptionsSheet(crawl: crawl),
    );
  }

  @override
  Widget build(BuildContext context) {
    void pick(CrawlOption option) => Navigator.of(context).pop(option);

    return CrawlSheet(
      title: crawl.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrawlSheetAction(
            title: 'Share crawl link',
            subtitle: 'nookph.app/c/${crawl.shareCode}',
            onTap: () => pick(CrawlOption.share),
          ),
          if (crawl.isCreator) ...[
            CrawlSheetAction(
              title: 'Edit title',
              subtitle: 'Stops cannot change after a crawl is made',
              onTap: () => pick(CrawlOption.editTitle),
            ),
            if (!crawl.isArchived)
              CrawlSheetAction(
                title: 'Archive',
                subtitle:
                    'Nobody can start it again. Runs under way keep working.',
                destructive: true,
                onTap: () => pick(CrawlOption.archive),
              ),
          ] else
            CrawlSheetAction(
              title: 'Report crawl',
              subtitle: 'Flag the title or description',
              destructive: true,
              onTap: () => pick(CrawlOption.report),
            ),
        ],
      ),
    );
  }
}
