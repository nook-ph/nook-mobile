import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/widgets/error/state_styles.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_builder_page.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/lists/presentation/utils/lists_format.dart';
import 'package:nook/features/lists/presentation/widgets/cafe_actions_bottom_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_cafe_row.dart';
import 'package:nook/features/lists/presentation/widgets/list_form_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_options_bottom_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/lists/presentation/widgets/ranked_been_list.dart';

/// One list opened from the Saved tab: Been as the ranked diary, everything
/// else as plain cafe rows (Figma "Been — ranked", "Want to try", "Custom
/// list").
class ListDetailPage extends StatefulWidget {
  final String listId;
  final String title;

  /// `lists.list_type` — 'been' switches the body to the ranked view
  /// (docs/RANKING_DESIGN.md §3.2). Callers that don't know default to the
  /// plain rows.
  final String listType;

  const ListDetailPage({
    super.key,
    required this.listId,
    required this.title,
    this.listType = 'custom',
  });

  bool get isBeenList => listType == 'been';

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  // Cache to survive bloc state changes during navigation
  List<CafeSummary>? _cachedCafes;
  CafeList? _cachedList;
  bool _isDeleting = false;

  /// The cafe whose removal is in flight, so the reload can offer Undo.
  CafeSummary? _removing;

  /// The cafe an Undo is putting back, so the reload can say it is back.
  CafeSummary? _restoring;

  /// An edit is in flight, so the reload can say it was saved.
  bool _editing = false;

  /// App-wide, and held so the Undo toast still works once this page is gone.
  late final ListsBloc _listsBloc;

  @override
  void initState() {
    super.initState();
    _listsBloc = context.read<ListsBloc>();
    final state = context.read<ListsBloc>().state;
    if (state is ListCafesLoaded && state.list.id == widget.listId) {
      _cachedCafes = state.cafes;
      _cachedList = state.list;
    } else {
      context.read<ListsBloc>().add(LoadListCafes(listId: widget.listId));
    }
    _loadRankingsIfBeen();
  }

  /// The loaded list is the authority on its own type: a caller that did not
  /// pass one must still get Been as the ranked diary, never as plain rows
  /// whose Remove would delete the ranking and note.
  String get _listType => _cachedList?.listType ?? widget.listType;

  void _loadRankingsIfBeen() {
    if (_listType != 'been') return;
    // The ranked view needs positions/scores; idempotent and cheap.
    final ranking = context.read<CafeRankingCubit>();
    if (!ranking.state.loaded) ranking.load();
  }

  String get _title {
    if (_listType == 'want_to_try') return 'Want to try';
    return _cachedList?.name ?? widget.title;
  }

  bool get _canEditList {
    final list = _cachedList;
    return list != null && !list.isSystem && !list.isDefault;
  }

  /// Any list — Been and Want to Try included — with enough cafes can become
  /// a crawl.
  bool get _canMakeCrawl =>
      (_cachedCafes?.length ?? 0) >= CreateCrawlUseCase.minStops;

  void _openCrawlBuilder() {
    final cafes = _cachedCafes;
    if (cafes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CrawlBuilderPage(
          listId: widget.listId,
          listName: _title,
          cafes: cafes,
        ),
      ),
    );
  }

  void _showListOptions() {
    final list = _cachedList;
    if (list == null) return;

    final bloc = context.read<ListsBloc>();
    final canEdit = _canEditList;

    dismissToasts();
    ListsSheet.show<void>(
      context,
      builder: (_) => ListOptionsBottomSheet(
        listId: list.id,
        listName: _title,
        onMakeCrawl: _canMakeCrawl ? _openCrawlBuilder : null,
        onEdit: canEdit ? () => _editList(bloc, list) : null,
        onDelete: canEdit ? () => _confirmDelete(bloc, list) : null,
      ),
    );
  }

  Future<void> _editList(ListsBloc bloc, CafeList list) async {
    final input = await showEditListSheet(
      context,
      name: list.name,
      description: list.description,
    );
    if (input == null || !mounted) return;

    bloc.add(
      UpdateList(
        listId: list.id,
        name: input.name,
        description: input.description,
        isPublic: list.isPublic,
      ),
    );
    // "List updated." waits for the reload that proves it.
    _editing = true;
  }

  Future<void> _confirmDelete(ListsBloc bloc, CafeList list) async {
    final confirmed = await showDeleteListConfirm(context, listName: list.name);
    if (!confirmed || !mounted || _isDeleting) return;

    // The list this page is showing is gone — leave before the bloc reloads
    // and this page rebuilds against a list that no longer exists.
    _isDeleting = true;
    bloc.add(DeleteList(listId: list.id));
    Navigator.of(context).pop();
  }

  void _openCafe(CafeSummary cafe) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CafeDetailsPage(cafeId: cafe.id)),
    );
  }

  void _showCafeActions(CafeSummary cafe) {
    dismissToasts();
    ListsSheet.show<void>(
      context,
      builder: (_) => CafeActionsBottomSheet(
        cafeName: cafe.name,
        listName: _title,
        onViewDetails: () => _openCafe(cafe),
        onRemove: () => _removeCafe(cafe),
      ),
    );
  }

  void _removeCafe(CafeSummary cafe) {
    _removing = cafe;
    _restoring = null;
    context.read<ListsBloc>().add(
      RemoveCafeFromList(listId: widget.listId, cafeId: cafe.id),
    );
  }

  /// Runs from the toast, which can outlive this page: no context lookups.
  void _undoRemove(CafeSummary cafe) {
    _restoring = cafe;
    _removing = null;
    _listsBloc.add(AddCafeToList(listId: widget.listId, cafeId: cafe.id));
  }

  void _onListsState(BuildContext context, ListsState state) {
    // An edit reloads the user's lists, not this list's cafes: pick the new
    // name and description up from there.
    if (state is ListsLoaded) {
      if (_editing) {
        _editing = false;
        showPrimaryToast(context, 'List updated.');
      }
      for (final list in state.lists) {
        if (list.id != widget.listId) continue;
        setState(() => _cachedList = list);
        // A cafe saved or un-saved elsewhere (its own page, the Save-to
        // sheet) changes the count but not the rows held here.
        final cafes = _cachedCafes;
        if (cafes != null && cafes.length != list.cafeCount) {
          context.read<ListsBloc>().add(LoadListCafes(listId: widget.listId));
        }
      }
      return;
    }

    if (state is ListsError) {
      // A failed remove or undo must not leave a stale toast armed.
      final failed = _removing ?? _restoring;
      final editFailed = _editing;
      _removing = null;
      _restoring = null;
      _editing = false;
      if ((failed != null || editFailed) && _cachedCafes != null) {
        showPrimaryToast(context, "Couldn't update. Please try again.");
      }
      return;
    }

    if (state is! ListCafesLoaded || state.list.id != widget.listId) return;

    final before = _cachedCafes?.length ?? 0;
    final removed = _removing;
    final restored = _restoring;
    setState(() {
      _cachedCafes = state.cafes;
      _cachedList = state.list;
    });
    _loadRankingsIfBeen();

    // Want to Try is a status: a row removed or put back here has to reach
    // the badges and pills that read CafeStatusCubit.
    final changed = removed ?? restored;
    if (changed != null && state.list.isSystem) {
      context.read<CafeStatusCubit>().loadFor([changed.id]);
    }

    if (removed != null && state.cafes.length < before) {
      _removing = null;
      showPrimaryToastWithAction(
        context,
        'Removed "${removed.name}".',
        actionLabel: 'Undo',
        onAction: () => _undoRemove(removed),
      );
    } else if (restored != null && state.cafes.length > before) {
      _restoring = null;
      showPrimaryToast(context, '"${restored.name}" is back in $_title.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShowOptions =
        _cachedList != null && (_canEditList || _canMakeCrawl);

    return Scaffold(
      backgroundColor: ListsTokens.surface,
      // Rename / delete live here. Those two are absent for system lists (the
      // server refuses both) and for the default list, whose bookmark saves
      // would be orphaned by a delete — but the menu still opens there when
      // the list is long enough to turn into a crawl.
      appBar: ListsNavBar(onMore: canShowOptions ? _showListOptions : null),
      body: BlocConsumer<ListsBloc, ListsState>(
        listener: _onListsState,
        builder: (context, state) {
          final listsBloc = context.read<ListsBloc>();

          // Serve cached data immediately — no skeleton flash on return
          final cafes = _cachedCafes;
          if (cafes != null) return _buildList(cafes);

          // No cache yet — show appropriate state
          if (state is ListsError) {
            final info = AppErrorCopy.fromException(state.error);
            return FullPageErrorWidget(
              error: info,
              onRetry: info.type == ErrorType.sessionExpired
                  ? () => context.push('/login')
                  : () => listsBloc.add(LoadListCafes(listId: widget.listId)),
            );
          }

          return const ListDetailSkeleton();
        },
      ),
    );
  }

  Widget _buildList(List<CafeSummary> cafes) {
    return ListDetailView(
      title: _title,
      listType: _listType,
      description: _cachedList?.description,
      cafes: cafes,
      onOpenCafe: _openCafe,
      onCafeMore: _showCafeActions,
      onFindCafe: () => context.push('/search'),
    );
  }
}

/// A loaded list: its title, then Been's ranked diary or plain cafe rows, or
/// the empty state when nothing is in it.
class ListDetailView extends StatelessWidget {
  const ListDetailView({
    super.key,
    required this.title,
    required this.listType,
    required this.description,
    required this.cafes,
    required this.onOpenCafe,
    required this.onCafeMore,
    required this.onFindCafe,
  });

  final String title;
  final String listType;
  final String? description;
  final List<CafeSummary> cafes;
  final ValueChanged<CafeSummary> onOpenCafe;
  final ValueChanged<CafeSummary> onCafeMore;
  final VoidCallback onFindCafe;

  bool get _isBeen => listType == 'been';

  @override
  Widget build(BuildContext context) {
    if (cafes.isEmpty) {
      // Been gets its own empty state and no title: it is the one list a
      // user never creates, so "no cafes yet" is a beginning, not an error.
      if (_isBeen) {
        return _EmptyList(
          title: 'Nowhere yet',
          subtitle:
              'Mark a cafe as Been and your diary starts here — ranked by '
              'you, not by reviews.',
          filled: true,
          onFind: onFindCafe,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListTitle(title: title, subtitle: null),
          Expanded(
            child: _EmptyList(
              title: 'No cafes in this list yet.',
              subtitle: listType == 'want_to_try'
                  ? 'Tap Want to try on a cafe and it waits here.'
                  : 'Save a cafe from its page and choose this list.',
              filled: false,
              onFind: onFindCafe,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (_isBeen)
          BlocBuilder<CafeRankingCubit, CafeRankingState>(
            builder: (context, ranking) =>
                _ListTitle(title: title, subtitle: _beenSubtitle(ranking)),
          )
        else
          _ListTitle(title: title, subtitle: _plainSubtitle()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ListsTokens.gutter),
          child: _isBeen
              ? RankedBeenList(cafes: cafes)
              : Column(
                  children: [
                    for (var i = 0; i < cafes.length; i++) ...[
                      if (i > 0) const ListsDivider(),
                      ListCafeRow(
                        cafe: cafes[i],
                        onTap: () => onOpenCafe(cafes[i]),
                        onMore: () => onCafeMore(cafes[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// "5 ranked · 1 to rank" once ranking has started, a plain count before.
  String _beenSubtitle(CafeRankingState ranking) {
    final split = splitBeenList(cafes, ranking.rankings);
    final ranked = split.ranked.length;
    final toRank = split.unranked.length;
    if (ranked == 0) return placeCountText(cafes.length);
    return toRank == 0 ? '$ranked ranked' : '$ranked ranked · $toRank to rank';
  }

  String _plainSubtitle() {
    final about = description?.trim() ?? '';
    final places = placeCountText(cafes.length);
    return about.isEmpty ? places : '$about · $places';
  }
}

/// SemiBold 24 list name with one muted line under it.
class _ListTitle extends StatelessWidget {
  const _ListTitle({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final line = subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ListsTokens.gutter,
        0,
        ListsTokens.gutter,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: listsText(24, weight: FontWeight.w600)),
          if (line != null) ...[
            const SizedBox(height: 2),
            Text(line, style: listsText(14, color: ListsTokens.muted)),
          ],
        ],
      ),
    );
  }
}

/// A list with nothing in it: what belongs here, and a way to go find one.
class _EmptyList extends StatelessWidget {
  const _EmptyList({
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onFind,
  });

  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // The design starts the block 170 under the header; on a short screen
      // it scrolls rather than overflowing.
      padding: const EdgeInsets.fromLTRB(40, 120, 40, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: listsText(16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: listsText(14, color: ListsTokens.muted),
          ),
          // The design's 8 spacer between two 8 gaps.
          const SizedBox(height: 24),
          StatePillButton(label: 'Find a cafe', filled: filled, onTap: onFind),
        ],
      ),
    );
  }
}

/// Figma "List detail — loading": a title, a line, and six rows in grey.
class ListDetailSkeleton extends StatelessWidget {
  const ListDetailSkeleton({super.key});

  static const _nameWidths = [150.0, 170.0, 190.0, 150.0, 170.0, 190.0];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading list',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: ListsTokens.gutter),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: ListsSkeleton(width: 180, height: 24, radius: 6),
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: ListsSkeleton(width: 240, height: 12, radius: 6),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _nameWidths.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            Row(
              children: [
                const ListsSkeleton(width: 44, height: 44),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListsSkeleton(width: _nameWidths[i], height: 12, radius: 6),
                    const SizedBox(height: 8),
                    const ListsSkeleton(width: 100, height: 10, radius: 6),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
