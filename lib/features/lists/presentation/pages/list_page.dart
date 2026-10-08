import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/cafe_list_display_title.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:nook/features/crawls/presentation/widgets/my_crawls_section.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/lists/presentation/pages/list_detail_page.dart';
import 'package:nook/features/lists/presentation/utils/lists_format.dart';
import 'package:nook/features/lists/presentation/widgets/list_form_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// The Saved tab (Figma "Lists — overview"): Want to try and Been as cards,
/// the Crawls block, then every other list as one row style.
class ListsPage extends StatefulWidget {
  const ListsPage({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  String? _pendingCreateName;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Sign-in loads the lists, and every change to one reloads them, so they
    // are usually here already (or on their way).
    final listsBloc = context.read<ListsBloc>();
    if (listsBloc.userLists.isEmpty && listsBloc.state is! ListsLoading) {
      listsBloc.add(LoadUserLists());
    }
    context.read<MyCrawlsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListsBloc, ListsState>(
      listener: (context, state) {
        if (state is ListsError) {
          final info = AppErrorCopy.fromException(state.error);
          // A toast only when it adds something: not over this page's own
          // full-page error (no lists to show), and not from a hidden tab
          // (the page is kept alive behind Profile and Home, where it
          // stacked an offline toast over their own offline state).
          final failedCreate = _pendingCreateName != null;
          final showsFullPageError = context
              .read<ListsBloc>()
              .userLists
              .isEmpty;
          final visible =
              TickerMode.valuesOf(context).enabled &&
              (ModalRoute.of(context)?.isCurrent ?? true);
          if (visible && (failedCreate || !showsFullPageError)) {
            showPrimaryToast(context, '${info.title} · ${info.subtitle}');
          }
          _pendingCreateName = null;
          if (mounted) setState(() => _isCreating = false);
          return;
        }

        // The lists reload on every sign-in; this page is built once and may
        // have been built for a guest, or before a sign-out cleared the
        // crawls. Load them whenever they are not in.
        if (state is ListsLoaded) {
          final crawls = context.read<MyCrawlsCubit>();
          final status = crawls.state.status;
          if (status == MyCrawlsStatus.initial ||
              status == MyCrawlsStatus.error) {
            crawls.load();
          }
        }

        if (state is ListsLoaded && _pendingCreateName != null) {
          showPrimaryToast(context, 'List created.');
          _pendingCreateName = null;
          if (mounted) setState(() => _isCreating = false);
        }
      },
      child: Scaffold(
        backgroundColor: ListsTokens.surface,
        appBar: widget.showBackButton ? const ListsNavBar() : null,
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<ListsBloc, ListsState>(
            builder: (context, state) {
              final listsBloc = context.read<ListsBloc>();
              final lists = state is ListsLoaded
                  ? state.lists
                  : listsBloc.userLists;

              if ((state is ListsLoading || state is ListsInitial) &&
                  lists.isEmpty) {
                return const ListsPageSkeleton();
              }

              if (state is ListsError && lists.isEmpty) {
                final info = AppErrorCopy.fromException(state.error);
                return FullPageErrorWidget(
                  error: info,
                  onRetry: info.type == ErrorType.sessionExpired
                      ? () => context.push('/login')
                      : () => listsBloc.add(LoadUserLists()),
                );
              }

              return ListsOverview(
                lists: lists,
                previews: listsBloc.listPreviews,
                onOpenList: (list) => _openList(context, list),
                onCreate: _isCreating
                    ? null
                    : () => _showCreateListSheet(context),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateListSheet(BuildContext context) async {
    final listsBloc = context.read<ListsBloc>();

    final input = await showCreateListSheet(context);
    if (input == null || !mounted) return;

    setState(() => _isCreating = true);
    _pendingCreateName = input.name;
    listsBloc.add(
      CreateList(
        name: input.name,
        description: input.description,
        isPublic: false,
      ),
    );
  }

  void _openList(BuildContext context, CafeList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListDetailPage(
          listId: list.id,
          title: list.name,
          listType: list.listType,
        ),
      ),
    );
  }
}

/// The loaded Saved tab: system list cards, the Crawls block, then All lists.
class ListsOverview extends StatelessWidget {
  const ListsOverview({
    super.key,
    required this.lists,
    required this.previews,
    required this.onOpenList,
    required this.onCreate,
  });

  final List<CafeList> lists;

  /// list id → up to three cafe images from inside it.
  final Map<String, List<String>> previews;
  final ValueChanged<CafeList> onOpenList;

  /// Null while a create is in flight.
  final VoidCallback? onCreate;

  static DateTime _recencyOf(CafeList list) =>
      list.lastSavedAt ?? list.updatedAt;

  @override
  Widget build(BuildContext context) {
    // Want to Try first — it is the actionable one ("where should I go?");
    // Been, the ranked archive, second.
    final systemLists = lists.where((list) => list.isSystem).toList()
      ..sort((a, b) {
        int rank(CafeList l) => l.listType == 'want_to_try' ? 0 : 1;
        return rank(a).compareTo(rank(b));
      });

    // The default list leads, since its row says "Default" instead of a
    // date; the rest follow, most recently touched first.
    final regularLists = lists.where((list) => !list.isSystem).toList()
      ..sort((a, b) {
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        return _recencyOf(b).compareTo(_recencyOf(a));
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ListsTokens.gutter,
        8,
        ListsTokens.gutter,
        40,
      ),
      children: [
        Text('Your lists', style: listsText(24, weight: FontWeight.w600)),
        const SizedBox(height: 20),
        for (var i = 0; i < systemLists.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _SystemListCard(
            list: systemLists[i],
            previews: previews[systemLists[i].id] ?? const [],
            onTap: () => onOpenList(systemLists[i]),
          ),
        ],
        const SizedBox(height: 20),
        const MyCrawlsSection(),
        // The crawls block ends on its own 12 gap.
        const SizedBox(height: 8),
        _AllListsHeader(
          onCreate: onCreate,
          showCreate: regularLists.isNotEmpty,
        ),
        const SizedBox(height: 6),
        if (regularLists.isEmpty)
          _MakeAListCard(onCreate: onCreate)
        else
          for (var i = 0; i < regularLists.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 6),
              const ListsDivider(),
              const SizedBox(height: 6),
            ],
            _ListRow(
              list: regularLists[i],
              previews: previews[regularLists[i].id] ?? const [],
              onTap: () => onOpenList(regularLists[i]),
            ),
          ],
      ],
    );
  }
}

// ── Been / Want to Try ─────────────────────────────────────────────────────

/// The two lists every user has. They keep a bordered card because they
/// behave differently from the lists below: neither can be renamed or
/// deleted, and Been is ranked.
class _SystemListCard extends StatelessWidget {
  const _SystemListCard({
    required this.list,
    required this.previews,
    required this.onTap,
  });

  final CafeList list;

  /// Up to three cafe images from inside the list. Empty is a supported state,
  /// not a bug — an empty list has nothing to preview.
  final List<String> previews;
  final VoidCallback onTap;

  bool get _isWantToTry => list.listType == 'want_to_try';

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ListsTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ListsTokens.border),
        ),
        child: Row(
          children: [
            if (previews.isEmpty)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ListsTokens.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isWantToTry ? LucideIcons.bookmark : LucideIcons.check,
                  size: 18,
                  color: ListsTokens.muted,
                ),
              )
            else
              _PreviewStack(previews: previews),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isWantToTry ? 'Want to try' : list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listsText(16, weight: FontWeight.w600),
                  ),
                  Text(
                    _subtitle(list),
                    style: listsText(12, color: ListsTokens.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: ListsTokens.ink,
            ),
          ],
        ),
      ),
    );
  }

  /// A count is not a reason to tap. When there is something inside, the line
  /// carries recency; when there isn't, it explains what the list is *for*.
  static String _subtitle(CafeList list) {
    if (list.cafeCount == 0) {
      return list.listType == 'want_to_try'
          ? 'Cafes you want to visit wait here.'
          : 'Cafes you visit rank themselves here.';
    }
    return '${placeCountText(list.cafeCount)} · '
        '${relativeDay(list.lastSavedAt ?? list.updatedAt)}';
  }
}

/// Up to three 44 photos, each overlapping the one before by 14 and ringed
/// in the surface colour so they read as a stack.
class _PreviewStack extends StatelessWidget {
  const _PreviewStack({required this.previews});

  final List<String> previews;

  static const _size = 44.0;
  static const _step = 30.0;

  @override
  Widget build(BuildContext context) {
    final shown = previews.take(3).toList();
    return SizedBox(
      width: _size + _step * (shown.length - 1),
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: _step * i,
              child: Container(
                width: _size,
                height: _size,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: ListsTokens.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListsThumb(imageUrl: shown[i], size: 40, radius: 8),
              ),
            ),
        ],
      ),
    );
  }
}

// ── All lists ──────────────────────────────────────────────────────────────

class _AllListsHeader extends StatelessWidget {
  const _AllListsHeader({required this.onCreate, required this.showCreate});

  final VoidCallback? onCreate;

  /// Hidden on a first run: the "make a list" card below carries the button,
  /// and two of them read as two actions.
  final bool showCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'All lists',
              style: listsText(16, weight: FontWeight.w600),
            ),
          ),
          if (showCreate)
            Semantics(
              button: true,
              label: 'New list',
              excludeSemantics: true,
              child: AdaptiveTap(
                onTap: onCreate,
                borderRadius: BorderRadius.circular(100),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.plus,
                        size: 14,
                        color: ListsTokens.brand,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'New list',
                        style: listsText(
                          14,
                          weight: FontWeight.w500,
                          color: ListsTokens.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One custom list: photo, name, and its count with when it was last saved to.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.list,
    required this.previews,
    required this.onTap,
  });

  final CafeList list;
  final List<String> previews;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The list's own cover when it has one; otherwise borrow the newest cafe
    // image inside it, so a list is never a blank tile just because nothing
    // set `cover_image_url`.
    final cover = switch (list.coverImageUrl?.trim()) {
      final String url when url.isNotEmpty => url,
      _ => previews.isEmpty ? null : previews.first,
    };

    return AdaptiveTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ListsThumb(
              imageUrl: cover,
              size: 56,
              placeholderIcon: LucideIcons.bookmark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cafeListDisplayTitle(list),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listsText(14, weight: FontWeight.w500),
                  ),
                  Text(
                    _subtitle(list),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listsText(12, color: ListsTokens.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: ListsTokens.ink,
            ),
          ],
        ),
      ),
    );
  }

  /// The default list says so where the others carry recency, which explains
  /// the one thing that is different about it.
  static String _subtitle(CafeList list) {
    if (list.cafeCount == 0) return 'No cafes yet';
    final tail = list.isDefault
        ? 'Default'
        : relativeDay(list.lastSavedAt ?? list.updatedAt);
    return '${placeCountText(list.cafeCount)} · $tail';
  }
}

// ── First run ──────────────────────────────────────────────────────────────

class _MakeAListCard extends StatelessWidget {
  const _MakeAListCard({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ListsTokens.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Make a list of your own — best matcha, study spots, '
            'date-night nooks.',
            style: listsText(14),
          ),
          const SizedBox(height: 14),
          ListsPillButton(
            label: 'New list',
            icon: LucideIcons.plus,
            height: 40,
            expand: false,
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

// ── Loading ────────────────────────────────────────────────────────────────

/// Figma "Lists — loading": the page's own shape in grey blocks.
class ListsPageSkeleton extends StatelessWidget {
  const ListsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your lists',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          ListsTokens.gutter,
          8,
          ListsTokens.gutter,
          0,
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: ListsSkeleton(width: 150, height: 30),
          ),
          const SizedBox(height: 20),
          const ListsSkeleton(height: 72, radius: 16),
          const SizedBox(height: 10),
          const ListsSkeleton(height: 72, radius: 16),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: ListsSkeleton(width: 100, height: 22),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            const Row(
              children: [
                ListsSkeleton(width: 56, height: 56, radius: 12),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListsSkeleton(width: 140, height: 14),
                    SizedBox(height: 8),
                    ListsSkeleton(width: 90, height: 12),
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
