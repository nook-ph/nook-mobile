import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/lists/presentation/pages/list_detail_page.dart';
import 'package:nook/features/lists/presentation/widgets/list_form_sheet.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// The Lists tab of the profile: every list the user has, same as the Saved
/// tab, read from the app-wide [ListsBloc]. Creating one goes through the
/// lists feature's own create UI.
class ProfileListsTab extends StatefulWidget {
  const ProfileListsTab({super.key});

  @override
  State<ProfileListsTab> createState() => _ProfileListsTabState();
}

class _ProfileListsTabState extends State<ProfileListsTab> {
  /// Set between asking for a new list and the bloc reporting it, so the
  /// "created" toast fires once and only for a create.
  bool _creating = false;

  Future<void> _create(ListsBloc bloc) async {
    final input = await showCreateListSheet(context);
    if (input == null || !mounted) return;

    setState(() => _creating = true);
    bloc.add(
      CreateList(
        name: input.name,
        description: input.description,
        isPublic: false,
      ),
    );
  }

  void _open(CafeList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListDetailPage(listId: list.id, title: list.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ListsBloc>();
    return BlocConsumer<ListsBloc, ListsState>(
      listenWhen: (_, current) =>
          _creating && (current is ListsLoaded || current is ListsError),
      listener: (context, state) {
        setState(() => _creating = false);
        showPrimaryToast(
          context,
          state is ListsLoaded
              ? 'List created.'
              : 'Could not create the list. Please try again.',
        );
      },
      builder: (context, state) {
        final lists = state is ListsLoaded ? state.lists : bloc.userLists;
        return ProfileListsView(
          lists: lists,
          previews: bloc.listPreviews,
          loading:
              (state is ListsLoading || state is ListsInitial) && lists.isEmpty,
          failed: state is ListsError && lists.isEmpty,
          onCreate: _creating ? null : () => _create(bloc),
          onOpen: _open,
          onRetry: () => bloc.add(LoadUserLists()),
        );
      },
    );
  }
}

/// The Lists tab's body for one state: skeleton tiles while [loading], the
/// retry block when [failed], otherwise the create row over the tiles (or
/// over the empty message).
class ProfileListsView extends StatelessWidget {
  const ProfileListsView({
    super.key,
    required this.lists,
    required this.onCreate,
    required this.onOpen,
    required this.onRetry,
    this.previews = const {},
    this.loading = false,
    this.failed = false,
  });

  final List<CafeList> lists;

  /// list id → cafe images, the cover for lists that have none of their own.
  final Map<String, List<String>> previews;
  final bool loading;
  final bool failed;

  /// Null while a create is in flight.
  final VoidCallback? onCreate;
  final ValueChanged<CafeList> onOpen;
  final VoidCallback onRetry;

  static const _gap = 12.0;

  String? _coverOf(CafeList list) {
    final own = list.coverImageUrl?.trim() ?? '';
    if (own.isNotEmpty) return own;
    // System lists carry no cover of their own; use a saved cafe's photo,
    // the same fallback the Saved tab uses.
    final preview = previews[list.id];
    return preview == null || preview.isEmpty ? null : preview.first;
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return SingleChildScrollView(
        child: ProfileMessage.error(
          title: 'Could not load lists.',
          actionStyle: ProfilePillStyle.outlined,
          onAction: onRetry,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        16,
        ProfileTokens.gutter,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CreateRow(onTap: onCreate),
          if (loading) ...[
            const SizedBox(height: 16),
            _Grid(
              gap: _gap,
              children: [for (var i = 0; i < 4; i++) const _TileSkeleton()],
            ),
          ] else if (lists.isEmpty)
            const ProfileMessage(
              icon: LucideIcons.bookmark,
              title: 'No lists yet',
              subtitle: 'Save your favourite cafes into lists.',
              top: 40,
            )
          else ...[
            const SizedBox(height: 16),
            _Grid(
              gap: _gap,
              children: [
                for (final list in lists)
                  _ListTile(
                    key: ValueKey('list-${list.id}'),
                    name: list.name,
                    places: list.cafeCount,
                    imageUrl: _coverOf(list),
                    onTap: () => onOpen(list),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Create new list": a plus in a tinted circle, the label and a chevron.
class _CreateRow extends StatelessWidget {
  const _CreateRow({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: ProfileTokens.tint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.plus,
                  size: 18,
                  color: ProfileTokens.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Create new list',
                  style: ProfileTokens.text(14, weight: FontWeight.w500),
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: ProfileTokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two equal columns [gap] apart, rows 16 apart. A Wrap rather than a grid,
/// so a tile is as tall as its text needs at any text size.
class _Grid extends StatelessWidget {
  const _Grid({required this.children, required this.gap});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// One list: a 128 high cover, the name and how many places it holds.
class _ListTile extends StatelessWidget {
  const _ListTile({
    super.key,
    required this.name,
    required this.places,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final int places;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 128,
                  width: double.infinity,
                  child: url == null
                      ? const ColoredBox(
                          color: ProfileTokens.tint,
                          child: Icon(
                            LucideIcons.bookmark,
                            size: 24,
                            color: ProfileTokens.muted,
                          ),
                        )
                      : CafeCardImage(imageUrl: url),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ProfileTokens.text(14, weight: FontWeight.w500),
              ),
              Text(
                placeCountLabel(places),
                style: ProfileTokens.text(12, color: ProfileTokens.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSkeleton(height: 130, radius: 12),
        SizedBox(height: 8),
        ProfileSkeleton(width: 110, height: 12),
        SizedBox(height: 8),
        ProfileSkeleton(width: 60, height: 10, radius: 5),
      ],
    );
  }
}
