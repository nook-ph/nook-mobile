import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/crawls/domain/crawl_stats.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_builder_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_detail_page.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/injection_container.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The toast shown when a seventh stop is tapped.
const crawlStopLimitMessage =
    'A crawl has up to ${CreateCrawlUseCase.maxStops} stops.';

/// Turns a list into a crawl: pick 3–6 of its cafes, put them in order, name
/// it. The stops are copied at creation and never change afterwards.
class CrawlBuilderPage extends StatelessWidget {
  const CrawlBuilderPage({
    super.key,
    required this.listId,
    required this.listName,
    required this.cafes,
  });

  final String listId;
  final String listName;
  final List<CafeSummary> cafes;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CrawlBuilderCubit(
        createCrawlUseCase: sl<CreateCrawlUseCase>(),
        analytics: sl<AnalyticsService>(),
        initialCafeIds: cafes.map((c) => c.id).toList(),
      ),
      child: _CrawlBuilderView(
        listId: listId,
        listName: listName,
        cafes: cafes,
      ),
    );
  }
}

class _CrawlBuilderView extends StatefulWidget {
  const _CrawlBuilderView({
    required this.listId,
    required this.listName,
    required this.cafes,
  });

  final String listId;
  final String listName;
  final List<CafeSummary> cafes;

  @override
  State<_CrawlBuilderView> createState() => _CrawlBuilderViewState();
}

class _CrawlBuilderViewState extends State<_CrawlBuilderView> {
  late final TextEditingController _title;

  /// Set by a refused submit; cleared as soon as the title is edited.
  CrawlTitleProblem? _titleProblem;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _suggestTitle(widget.listName));
  }

  void _onTitleChanged(String _) {
    if (_titleProblem != null) setState(() => _titleProblem = null);
    context.read<CrawlBuilderCubit>().dismissFailure();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// "Want to Try" → "Want to Try Crawl". Clipped so the suggestion is always
  /// a valid title.
  static String _suggestTitle(String listName) {
    final base = listName.trim();
    if (base.isEmpty) return '';
    final title = base.toLowerCase().endsWith('crawl') ? base : '$base Crawl';
    return title.length > CreateCrawlUseCase.maxTitleLength
        ? title.substring(0, CreateCrawlUseCase.maxTitleLength)
        : title;
  }

  void _submit(BuildContext context) {
    final title = _title.text.trim();
    final problem = CrawlBuilderCubit.checkTitle(title);
    if (problem != null) {
      setState(() => _titleProblem = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<CrawlBuilderCubit>().submit(
      title: title,
      sourceListId: widget.listId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final cafe in widget.cafes) cafe.id: cafe};

    return BlocConsumer<CrawlBuilderCubit, CrawlBuilderState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CrawlBuilderStatus.failed && !state.titleRefused) {
          // A refused title is said on the field; everything else is about
          // the crawl as a whole and goes in a toast.
          showPrimaryToast(
            context,
            _failureCopy(state.error),
            bottomOffset: _barHeight,
          );
          return;
        }
        if (state.status == CrawlBuilderStatus.created) {
          final crawl = state.created!;
          context.read<MyCrawlsCubit>().load();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  CrawlDetailPage(shareCode: crawl.shareCode, initial: crawl),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<CrawlBuilderCubit>();
        final selected = [
          for (final id in state.selectedIds)
            if (byId[id] != null) byId[id]!,
        ];
        final unselected = widget.cafes
            .where((c) => !state.selectedIds.contains(c.id))
            .toList();
        final submitting = state.status == CrawlBuilderStatus.submitting;
        final titleError = _titleError(state);

        return Scaffold(
          backgroundColor: ListsTokens.surface,
          appBar: AppBar(
            backgroundColor: ListsTokens.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: ListsTokens.surface,
            titleSpacing: 0,
            leading: AdaptiveTap(
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  LucideIcons.arrowLeft,
                  size: 24,
                  color: ListsTokens.ink,
                ),
              ),
            ),
            title: Text(
              'New crawl',
              style: crawlText(16, weight: FontWeight.w600),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(crawlGutter, 4, crawlGutter, 24),
            children: [
              IgnorePointer(
                ignoring: submitting,
                child: CrawlTextField(
                  controller: _title,
                  label: 'Title',
                  quietLabel: true,
                  counterInside: true,
                  gap: 10,
                  emphasisWidth: 1,
                  hint: 'e.g. IT Park Study Crawl',
                  errorText: titleError,
                  maxLength: CreateCrawlUseCase.maxTitleLength,
                  textCapitalization: TextCapitalization.words,
                  onChanged: _onTitleChanged,
                ),
              ),
              // Figma: 10 between blocks plus the header's own 8 on top.
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pick ${CreateCrawlUseCase.minStops}–'
                      '${CreateCrawlUseCase.maxStops} stops',
                      style: crawlText(16, weight: FontWeight.w600),
                    ),
                  ),
                  CrawlChip(
                    label:
                        '${selected.length} of ${CreateCrawlUseCase.maxStops}',
                    neutral: !state.hasEnoughStops,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'From ${widget.listName} · hold and drag to reorder',
                style: crawlText(12, color: ListsTokens.muted),
              ),
              // How far the order walks, and the shortest one, so a route
              // that criss-crosses shows before it is created
              // (docs/ux/core-loops.md, finding 4).
              if (selected.length >= 2) ...[
                const SizedBox(height: 6),
                _RouteLine(
                  stops: selected,
                  onShortest: submitting ? null : (ids) => cubit.setOrder(ids),
                ),
              ],
              const SizedBox(height: 10),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: selected.length,
                onReorder: cubit.reorder,
                itemBuilder: (context, index) {
                  final cafe = selected[index];
                  return _CafeRow(
                    key: ValueKey(cafe.id),
                    cafe: cafe,
                    order: index + 1,
                    showDivider: index > 0,
                    onTap: submitting ? null : () => cubit.toggle(cafe.id),
                    // Drag the handle, or tap it for Move up / Move down.
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: PopupMenuButton<int>(
                        tooltip: 'Reorder ${cafe.name}',
                        color: ListsTokens.surface,
                        surfaceTintColor: Colors.transparent,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabled: !submitting,
                        onSelected: (delta) => cubit.move(index, delta),
                        itemBuilder: (_) => [
                          if (index > 0)
                            const PopupMenuItem(
                              value: -1,
                              child: Text('Move up'),
                            ),
                          if (index < selected.length - 1)
                            const PopupMenuItem(
                              value: 1,
                              child: Text('Move down'),
                            ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(12, 10, 0, 10),
                          child: Icon(
                            LucideIcons.equal,
                            size: 20,
                            color: ListsTokens.muted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              for (final cafe in unselected)
                _CafeRow(
                  cafe: cafe,
                  showDivider: true,
                  // At the limit the rest of the list dims; tapping a dimmed
                  // row says why in a toast.
                  dimmed: state.isFull,
                  onTap: submitting
                      ? null
                      : state.isFull
                      ? () => showPrimaryToast(
                          context,
                          crawlStopLimitMessage,
                          bottomOffset: _barHeight,
                        )
                      : () => cubit.toggle(cafe.id),
                ),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: ListsTokens.surface,
              border: Border(top: BorderSide(color: ListsTokens.border)),
            ),
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                crawlGutter,
                12,
                crawlGutter,
                8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!state.hasEnoughStops) ...[
                    Text(
                      'Pick at least ${CreateCrawlUseCase.minStops} stops',
                      textAlign: TextAlign.center,
                      style: crawlText(12, color: ListsTokens.muted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  CrawlPrimaryButton(
                    label: 'Create crawl',
                    busy: submitting,
                    onTap: state.hasEnoughStops ? () => _submit(context) : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Lifts toasts clear of the sticky Create bar.
  static const _barHeight = 80.0;

  /// The line under the title field, from the local check or the server.
  String? _titleError(CrawlBuilderState state) {
    final problem = _titleProblem;
    if (problem == CrawlTitleProblem.rejected) {
      return 'Please pick a different title.';
    }
    final error = state.error;
    final serverLength =
        state.titleRefused &&
        error is CrawlInvalid &&
        error.code == 'crawl_title_length';
    if (problem == CrawlTitleProblem.length || serverLength) {
      return 'Title must be ${CreateCrawlUseCase.minTitleLength} to '
          '${CreateCrawlUseCase.maxTitleLength} characters.';
    }
    return state.titleRefused ? 'Please pick a different title.' : null;
  }

  /// What the toast says when the crawl as a whole was refused.
  static String _failureCopy(Object? error) {
    if (error is CrawlRateLimited) {
      return "You've made a lot of crawls today. Try again tomorrow.";
    }
    if (error is CrawlInvalid) {
      return error.code == 'crawl_unknown_cafe'
          ? 'One of these cafes is no longer listed.'
          : "That crawl couldn't be created. Check the title and stops.";
    }
    final info = AppErrorCopy.fromException(error ?? Exception());
    return '${info.title}. ${info.subtitle}';
  }
}

class _CafeRow extends StatelessWidget {
  const _CafeRow({
    super.key,
    required this.cafe,
    required this.showDivider,
    required this.onTap,
    this.order,
    this.trailing,
    this.dimmed = false,
  });

  final CafeSummary cafe;

  /// Stop number when picked; null shows an empty circle.
  final int? order;
  final bool showDivider;
  final bool dimmed;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ListsTokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(top: BorderSide(color: ListsTokens.border))
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              CrawlNumberBadge(
                number: order,
                size: 28,
                outlined: order == null,
              ),
              const SizedBox(width: 12),
              Opacity(
                opacity: dimmed ? 0.4 : 1,
                child: CrawlStopThumb(imageUrl: cafe.coverImage),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: dimmed ? 0.4 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cafe.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: crawlText(14, weight: FontWeight.w500),
                      ),
                      if (cafe.locationLabel.isNotEmpty)
                        Text(
                          cafe.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: crawlText(12, color: ListsTokens.muted),
                        ),
                    ],
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// "About 5.5 km between stops", with "Shortest order" when another order of
/// the same stops walks less.
class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.stops, required this.onShortest});

  final List<CafeSummary> stops;
  final ValueChanged<List<String>>? onShortest;

  static double _length(List<CafeSummary> order) {
    var total = 0.0;
    for (var i = 1; i < order.length; i++) {
      final a = order[i - 1], b = order[i];
      if (a.lat == null || a.lng == null || b.lat == null || b.lng == null) {
        continue;
      }
      total += haversineMeters(
        GeoPoint(lat: a.lat!, lng: a.lng!),
        GeoPoint(lat: b.lat!, lng: b.lng!),
      );
    }
    return total;
  }

  /// Every order of at most six stops (720), keeping the shortest.
  static List<CafeSummary> _shortest(List<CafeSummary> stops) {
    var best = stops;
    var bestLength = _length(stops);
    void permute(List<CafeSummary> prefix, List<CafeSummary> rest) {
      if (rest.isEmpty) {
        final length = _length(prefix);
        if (length < bestLength - 1) {
          best = List.of(prefix);
          bestLength = length;
        }
        return;
      }
      for (var i = 0; i < rest.length; i++) {
        permute([...prefix, rest[i]], [...rest]..removeAt(i));
      }
    }

    permute(const [], stops);
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final length = _length(stops);
    if (length <= 0) return const SizedBox.shrink();
    final shortest = _shortest(stops);
    final saves = length - _length(shortest);
    // Only worth a button when it saves a real walk.
    final offer = onShortest != null && saves >= 300;
    return Row(
      children: [
        Expanded(
          child: Text(
            'About ${CrawlStats.formatDistance(length)} between stops',
            style: crawlText(12, color: ListsTokens.muted),
          ),
        ),
        if (offer)
          AdaptiveTap(
            onTap: () => onShortest!([for (final c in shortest) c.id]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Shortest order · saves ${CrawlStats.formatDistance(saves)}',
                style: crawlText(
                  12,
                  weight: FontWeight.w600,
                  color: ListsTokens.brand,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
