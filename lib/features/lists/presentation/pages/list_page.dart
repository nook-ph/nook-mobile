import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/lists/presentation/pages/list_detail_page.dart';
import 'package:nook/features/lists/presentation/widgets/create_list_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Design tokens for this screen, straight from the Claude Design doc
/// ("Lists & Been Ranking"). Kept local rather than themed because the rest of
/// the app has not adopted the corrected palette yet — notably [_muted], which
/// replaces the `#848586` this page used to ship and which failed WCAG AA.
class _T {
  const _T._();

  static const brand = Color(0xFF344E41);
  static const brandHover = Color(0xFF2F4833);
  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF767574);
  static const border = Color(0xFFE0E0E0);
  static const surface = Color(0xFFFEFEFE);
  static const sage = Color(0xFFDAD7CD);

  static const gutter = 22.0;
  static const radius = 12.0;

  /// `--tracking-headline: -0.02em`, resolved per size.
  static double tracking(double fontSize) => fontSize * -0.02;
}

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
    context.read<ListsBloc>().add(LoadUserLists());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListsBloc, ListsState>(
      listener: (context, state) {
        if (state is ListsError) {
          final info = AppErrorCopy.fromException(state.error);
          showPrimaryToast(context, '${info.title} · ${info.subtitle}');
          _pendingCreateName = null;
          if (mounted) setState(() => _isCreating = false);
          return;
        }

        if (state is ListsLoaded && _pendingCreateName != null) {
          showPrimaryToast(context, 'List created.');
          _pendingCreateName = null;
          if (mounted) setState(() => _isCreating = false);
        }
      },
      child: Scaffold(
        backgroundColor: _T.surface,
        appBar: AppBar(
          backgroundColor: _T.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: _T.surface,
          automaticallyImplyLeading: widget.showBackButton,
          leading: widget.showBackButton
              ? AdaptiveTap(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back, color: _T.ink),
                  ),
                )
              : null,
        ),
        body: BlocBuilder<ListsBloc, ListsState>(
          builder: (context, state) {
            final listsBloc = context.read<ListsBloc>();
            final lists = state is ListsLoaded
                ? state.lists
                : listsBloc.userLists;

            if (state is ListsLoading && lists.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: _T.brand),
              );
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

            // Want to Try first — it is the actionable one ("where should I
            // go?"); Been, the ranked archive, second.
            final systemLists = lists.where((list) => list.isSystem).toList()
              ..sort((a, b) {
                int rank(CafeList l) => l.listType == 'want_to_try' ? 0 : 1;
                return rank(a).compareTo(rank(b));
              });

            // Everything else, most recently touched first. Favorites is no
            // longer pinned to the front: it is labelled "Default" in its own
            // card instead, which explains the one thing that was odd about it.
            final regularLists =
                lists.where((list) => !list.isSystem).toList()
                  ..sort((a, b) => _recencyOf(b).compareTo(_recencyOf(a)));

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                _T.gutter,
                0,
                _T.gutter,
                120, // clears the extended FAB and the tab bar
              ),
              children: [
                Text(
                  'Your Lists',
                  style: context.textTheme.titleLargeSemi.copyWith(
                    color: _T.ink,
                    letterSpacing: _T.tracking(24),
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < systemLists.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _SystemListCard(
                    list: systemLists[i],
                    previews: listsBloc.listPreviews[systemLists[i].id] ?? const [],
                    onTap: () => _openList(context, systemLists[i]),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'All Lists',
                  style: context.textTheme.titleMediumSemi.copyWith(
                    color: _T.brand,
                    letterSpacing: _T.tracking(18),
                  ),
                ),
                const SizedBox(height: 12),
                if (regularLists.isEmpty)
                  _NoListsCard(
                    onCreate: _isCreating
                        ? null
                        : () => _showCreateListDialog(context),
                  )
                else
                  _ListsGrid(
                    lists: regularLists,
                    previews: listsBloc.listPreviews,
                    onOpen: (list) => _openList(context, list),
                  ),
              ],
            );
          },
        ),
        // Hidden while the "make your first list" card is on screen — it
        // already carries the same button, and two of them read as two actions.
        floatingActionButton: BlocBuilder<ListsBloc, ListsState>(
          builder: (context, state) {
            final lists = state is ListsLoaded
                ? state.lists
                : context.read<ListsBloc>().userLists;
            final hasCustomLists = lists.any((list) => !list.isSystem);
            if (!hasCustomLists) return const SizedBox.shrink();

            return _NewListButton(
              onTap: _isCreating ? null : () => _showCreateListDialog(context),
            );
          },
        ),
      ),
    );
  }

  static DateTime _recencyOf(CafeList list) =>
      list.lastSavedAt ?? list.updatedAt;

  Future<void> _showCreateListDialog(BuildContext context) async {
    final listsBloc = context.read<ListsBloc>();

    final input = await showDialog<CreateListInput>(
      context: context,
      builder: (_) => const CreateListDialog(),
    );

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

// ── Been / Want to Try ─────────────────────────────────────────────────────

/// The two lists every user has, given the weight they earn: a full-width card
/// with an 18pt name, a live preview of what's inside, and recency. They used
/// to be thin icon rows sitting under photo cards for "Weekend spots", which
/// inverted the hierarchy.
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

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_T.radius),
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.radius),
          border: Border.all(color: _T.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    list.name,
                    style: context.textTheme.titleMediumSemi.copyWith(
                      color: _T.ink,
                      letterSpacing: _T.tracking(18),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(list),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: _T.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (previews.isNotEmpty) ...[
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < previews.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _PreviewThumb(imageUrl: previews[i]),
                  ],
                ],
              ),
            ],
            const SizedBox(width: 12),
            Icon(
              PhosphorIcons.caretRight(),
              size: 16,
              color: _T.muted,
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
    // No "added" prefix: with three preview thumbnails alongside it, the
    // longer phrasing wraps to a second line on a 390pt screen.
    return '${_placeCountText(list.cafeCount)} · '
        '${_relativeDay(list.lastSavedAt ?? list.updatedAt)}';
  }
}

class _PreviewThumb extends StatelessWidget {
  const _PreviewThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_T.radius),
      child: Image.network(
        imageUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _CoffeeTile(size: 44),
      ),
    );
  }
}

// ── Custom lists ───────────────────────────────────────────────────────────

/// Two-up grid. Full-width photo cards cost a lot of scroll for one line of
/// text each, and every card reserved a block of space it never filled.
class _ListsGrid extends StatelessWidget {
  const _ListsGrid({
    required this.lists,
    required this.previews,
    required this.onOpen,
  });

  final List<CafeList> lists;
  final Map<String, List<String>> previews;
  final void Function(CafeList) onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        const gap = 12.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final list in lists)
              SizedBox(
                width: cardWidth,
                child: _ListGridCard(
                  list: list,
                  previews: previews[list.id] ?? const [],
                  onTap: () => onOpen(list),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ListGridCard extends StatelessWidget {
  const _ListGridCard({
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
      _ => previews.isEmpty ? '' : previews.first,
    };

    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_T.radius),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.radius),
          border: Border.all(color: _T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 72,
              width: double.infinity,
              child: cover.isEmpty
                  ? const _CoffeeTile(size: double.infinity, glyphSize: 22)
                  : Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const _CoffeeTile(size: double.infinity, glyphSize: 22),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLargeMed.copyWith(
                      color: _T.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(list),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: _T.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Private" used to live here on every card. Public lists are not built —
  /// nothing ever sets `is_public` — so the slot said the same word forever.
  /// It now carries recency, and names the default list instead of leaving it
  /// silently different from its neighbours.
  static String _subtitle(CafeList list) {
    if (list.cafeCount == 0) return 'No cafes yet';

    final parts = [
      if (list.isDefault) 'Default',
      _placeCountText(list.cafeCount),
      _relativeDay(list.lastSavedAt ?? list.updatedAt),
    ];
    return parts.join(' · ');
  }
}

// ── Empty state + create ───────────────────────────────────────────────────

class _NoListsCard extends StatelessWidget {
  const _NoListsCard({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_T.radius),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Make a list of your own — best matcha, study spots, '
            'date-night nooks.',
            style: context.textTheme.bodyLarge?.copyWith(
              color: _T.ink,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          _NewListButton(onTap: onCreate),
        ],
      ),
    );
  }
}

/// Labelled rather than a bare ＋: on a first run the plus was the only action
/// on the screen and said nothing about what it would do.
class _NewListButton extends StatelessWidget {
  const _NewListButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null ? _T.brandHover : _T.brand,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.plus(), size: 18, color: _T.surface),
            const SizedBox(width: 8),
            Text(
              'New list',
              style: context.textTheme.bodyLargeMed.copyWith(color: _T.surface),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared bits ────────────────────────────────────────────────────────────

class _CoffeeTile extends StatelessWidget {
  const _CoffeeTile({required this.size, this.glyphSize = 20});

  final double size;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: _T.sage,
      alignment: Alignment.center,
      child: Icon(PhosphorIcons.coffee(), size: glyphSize, color: _T.brand),
    );
  }
}

String _placeCountText(int count) =>
    '$count ${count == 1 ? 'place' : 'places'}';

/// "yesterday" / "3 days ago" / "last week". Coarse on purpose — the point is
/// which list was touched most recently, not an audit trail.
String _relativeDay(DateTime when) {
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(when.year, when.month, when.day)).inDays;

  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'last week';
  if (days < 30) return '${days ~/ 7} weeks ago';
  if (days < 60) return 'last month';
  if (days < 365) return '${days ~/ 30} months ago';
  return 'over a year ago';
}
