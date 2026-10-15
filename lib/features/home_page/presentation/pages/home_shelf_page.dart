import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/features/home_page/domain/use_cases/get_home_shelf_usecase.dart';
import 'package:nook/features/search/presentation/widgets/search_rows.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';
import 'package:nook/injection_container.dart';

/// What a banner shows on the shelf it opens: its own title and line, so
/// the page keeps the banner's promise ("Cebu Coffee Week is on") rather
/// than the shelf's working name.
class HomeShelfHeader {
  const HomeShelfHeader({required this.title, this.body});

  final String title;
  final String? body;
}

/// Where a shelf's page is, for `context.push`.
String homeShelfLocation(String sectionId) =>
    '/shelf/${Uri.encodeComponent(sectionId)}';

/// One shelf of the Home layout in full (`nook://shelf/<section id>`): the
/// landing for a banner, and "See all" for custom shelves.
///
/// A sage header with the title (the banner's when it opened the page, else
/// the shelf's), the banner's line and a count, then the cafes as search
/// rows: photo, name, distance, rating and area, open state, tags.
class HomeShelfPage extends StatefulWidget {
  const HomeShelfPage({
    super.key,
    required this.sectionId,
    this.header,
    this.load,
  });

  final String sectionId;
  final HomeShelfHeader? header;

  /// Defaults to the app's [GetHomeShelfUseCase]; tests pass their own.
  final Future<HomeShelf?> Function(String id)? load;

  /// House picks under its default name.
  static const featuredTitle = 'House picks';

  @override
  State<HomeShelfPage> createState() => _HomeShelfPageState();
}

class _HomeShelfPageState extends State<HomeShelfPage> {
  late Future<HomeShelf?> _shelf;

  @override
  void initState() {
    super.initState();
    _shelf = _load();
  }

  Future<HomeShelf?> _load() async {
    final load = widget.load ?? sl<GetHomeShelfUseCase>().call;
    final shelf = await load(widget.sectionId);
    logAppEvent(
      HomeShelfEvents.opened,
      properties: {
        'shelf': widget.sectionId,
        'from_banner': widget.header != null,
        'found': shelf != null,
        'cafes': shelf?.cafes.length ?? 0,
      },
    );
    return shelf;
  }

  void _retry() {
    // FutureBuilder listens from the next build; until then a failure must
    // not count as unhandled.
    final next = _load()..ignore();
    setState(() {
      _shelf = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.white,
      body: FutureBuilder<HomeShelf?>(
        future: _shelf,
        builder: (context, snap) {
          final loading = snap.connectionState != ConnectionState.done;
          final shelf = snap.data;
          final title =
              widget.header?.title ??
              shelf?.title ??
              (shelf != null ? HomeShelfPage.featuredTitle : null);
          final cafes = shelf?.cafes ?? const <CafeSummary>[];

          final Widget body;
          if (loading) {
            body = const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: SearchTokens.gutter),
                child: SearchResultsSkeleton(),
              ),
            );
          } else if (snap.hasError) {
            final copy = AppErrorCopy.fromException(snap.error!);
            body = _Message(
              title: copy.title,
              body: copy.subtitle,
              action: 'Try again',
              onAction: _retry,
            );
          } else if (shelf == null || cafes.isEmpty) {
            body = _Message(
              title: 'This shelf isn’t on Nook right now',
              body: 'It may have ended or moved. Home has what’s on now.',
              action: 'Go to Home',
              onAction: () => context.go('/'),
            );
          } else {
            body = SliverPadding(
              padding: EdgeInsets.fromLTRB(
                SearchTokens.gutter,
                0,
                SearchTokens.gutter,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.separated(
                itemCount: cafes.length,
                separatorBuilder: (_, _) => const SearchDivider(),
                itemBuilder: (_, i) => SearchResultRow(cafe: cafes[i]),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  title: title,
                  body: widget.header?.body,
                  count: loading || shelf == null || cafes.isEmpty
                      ? null
                      : cafes.length,
                ),
              ),
              body,
            ],
          );
        },
      ),
    );
  }
}

/// Back, the title, an optional line and the count, on the banner's sage so
/// a banner tap reads as opening that banner.
class _Header extends StatelessWidget {
  const _Header({required this.title, this.body, this.count});

  final String? title;
  final String? body;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final title = this.title;
    final body = this.body;
    final count = this.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: scheme.primary20,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, SearchTokens.gutter, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    excludeSemantics: true,
                    child: AdaptiveTap(
                      onTap: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          LucideIcons.arrowLeft,
                          size: 24,
                          color: scheme.black,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    // Text on the 20 gutter; the back target overhangs it.
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: SearchTokens.text(
                                context,
                                size: 24,
                                weight: FontWeight.w600,
                              ).copyWith(height: 1.25),
                            ),
                          ),
                        if (body != null) ...[
                          const SizedBox(height: 6),
                          Text(body, style: SearchTokens.text(context)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (count != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SearchTokens.gutter,
              16,
              SearchTokens.gutter,
              2,
            ),
            child: Text(
              count == 1 ? '1 cafe' : '$count cafes',
              style: SearchTokens.text(
                context,
                size: 12,
                weight: FontWeight.w500,
                color: SearchTokens.muted,
              ),
            ),
          ),
      ],
    );
  }
}

/// The empty, ended and error states: what happened and the way on.
class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: SearchTokens.text(
                context,
                size: 18,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: SearchTokens.text(context, color: SearchTokens.muted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: SearchTokens.brand,
                minimumSize: const Size(160, 48),
              ),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
