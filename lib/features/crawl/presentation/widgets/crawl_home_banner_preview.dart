import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_state.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_home_banner.dart';

Crawl _fakeCrawl({bool withImage = false}) {
  return Crawl(
    id: 'crawl-1',
    title: 'Cebu Island Run',
    slug: 'cebu-island-run',
    startsAt: DateTime(2026, 6, 1),
    endsAt: DateTime(2026, 7, 15),
    status: CrawlStatus.active,
    city: 'Cebu',
    totalStops: 12,
    coverImageUrl: withImage
        ? 'https://images.unsplash.com/photo-1504674900247-0877df9cc836'
        : null,
  );
}

Widget _buildPreview({
  required ActiveCrawlsState state,
  Map<String, int>? stampProgress,
}) {
  final cubit = ActiveCrawlsCubit.forState(state);

  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocProvider.value(
          value: cubit,
          child: CrawlHomeBanner(stampProgress: stampProgress),
        ),
      ),
    ),
    theme: ThemeData.light(),
  );
}

@Preview(name: 'Unregistered Banner', group: 'Crawl')
Widget unregisteredBanner() {
  return _buildPreview(
    state: ActiveCrawlsLoaded([_fakeCrawl()], {}),
  );
}

@Preview(name: 'Registered with Progress', group: 'Crawl')
Widget registeredBanner() {
  return _buildPreview(
    state: ActiveCrawlsLoaded([_fakeCrawl()], {'crawl-1'}),
    stampProgress: {'crawl-1': 5},
  );
}

@Preview(name: 'With Cover Image', group: 'Crawl')
Widget bannerWithImage() {
  return _buildPreview(
    state: ActiveCrawlsLoaded([_fakeCrawl(withImage: true)], {}),
  );
}

@Preview(name: 'Empty State', group: 'Crawl')
Widget emptyBanner() {
  return _buildPreview(state: const ActiveCrawlsEmpty());
}
