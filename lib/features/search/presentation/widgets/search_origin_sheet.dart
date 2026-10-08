import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/presentation/widgets/confirm_sheet.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/presentation/cubit/place_search_cubit.dart';
import 'package:nook/features/search/presentation/cubit/saved_places_cubit.dart';
import 'package:nook/features/search/presentation/widgets/place_search_results.dart';
import 'package:nook/features/search/presentation/widgets/saved_places_section.dart';
import 'package:nook/features/search/presentation/widgets/search_option_row.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// What the "Search near" sheet was closed with.
sealed class SearchOriginChoice {
  const SearchOriginChoice();
}

class UseCurrentLocation extends SearchOriginChoice {
  const UseCurrentLocation();
}

class UsePlace extends SearchOriginChoice {
  const UsePlace(this.place, {this.justSaved = false});
  final SearchOrigin place;

  /// The place was saved a moment ago, from the sheet.
  final bool justSaved;
}

class PickOnMap extends SearchOriginChoice {
  const PickOnMap();
}

/// A guest tapped "Save Home and School or work".
class SignInToSave extends SearchOriginChoice {
  const SignInToSave();
}

/// Opens the saved-place editor over the sheet and resolves with the stored
/// place, or null when it was closed, or the place was deleted.
typedef SavedPlaceEditorOpener =
    Future<SavedPlace?> Function(
      BuildContext context, {
      SavedPlace? place,
      required SavedPlaceKind kind,
    });

/// "Search near": a place field, current location, pick on the map, the
/// user's saved places and the places searched near before. Typing swaps
/// the options for matching places: saved ones, Nook's areas, then the
/// map's.
Future<SearchOriginChoice?> showSearchOriginSheet(
  BuildContext context, {
  required SearchOrigin? current,
  required String? currentLocationLabel,
  required List<SearchOrigin> recentPlaces,
  required PlaceSearchCubit search,
  required SavedPlacesCubit saved,
  required SavedPlaceEditorOpener openEditor,
}) {
  return showModalBottomSheet<SearchOriginChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: search),
        BlocProvider.value(value: saved),
      ],
      child: SearchOriginSheet(
        current: current,
        currentLocationLabel: currentLocationLabel,
        recentPlaces: recentPlaces,
        openEditor: openEditor,
      ),
    ),
  );
}

/// The sheet body. Reads [PlaceSearchCubit] and [SavedPlacesCubit] from
/// the tree.
class SearchOriginSheet extends StatefulWidget {
  const SearchOriginSheet({
    super.key,
    required this.current,
    required this.currentLocationLabel,
    required this.recentPlaces,
    required this.openEditor,
  });

  final SearchOrigin? current;
  final String? currentLocationLabel;
  final List<SearchOrigin> recentPlaces;
  final SavedPlaceEditorOpener openEditor;

  @override
  State<SearchOriginSheet> createState() => _SearchOriginSheetState();
}

class _SearchOriginSheetState extends State<SearchOriginSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      context.read<PlaceSearchCubit>().queryChanged(_controller.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(SearchOriginChoice choice) => Navigator.of(context).pop(choice);

  /// The keyboard's Search key: the first saved match, else the first
  /// place.
  void _takeFirst() {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return;
    for (final p in context.read<SavedPlacesCubit>().state.places) {
      if (p.label.toLowerCase().contains(q)) {
        _close(UsePlace(p.toOrigin()));
        return;
      }
    }
    final first = context.read<PlaceSearchCubit>().state.results.firstOrNull;
    if (first != null) _close(UsePlace(first.origin));
  }

  /// A new place is set to be searched near: that is what it was made for.
  /// An edit leaves the sheet open on the updated list.
  Future<void> _edit({SavedPlace? place, required SavedPlaceKind kind}) async {
    final stored = await widget.openEditor(context, place: place, kind: kind);
    if (!mounted || stored == null) return;
    if (place == null) _close(UsePlace(stored.toOrigin(), justSaved: true));
  }

  Future<void> _more(SavedPlace place) async {
    final action = await showModalBottomSheet<_SavedAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _SavedActionsSheet(place: place),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SavedAction.edit:
        await _edit(place: place, kind: place.kind);
      case _SavedAction.delete:
        final confirmed = await showConfirmSheet(
          context,
          title: 'Delete ${place.label}?',
          message:
              'It comes off your saved places. Cafes you’ve found '
              'near it stay where they are.',
          confirmLabel: 'Delete',
        );
        if (!confirmed || !mounted) return;
        try {
          await context.read<SavedPlacesCubit>().delete(place);
        } catch (_) {
          if (mounted) {
            showPrimaryToast(context, 'Couldn’t delete. Try again.');
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typing = _controller.text.trim().isNotEmpty;
    final muted12 = SearchTokens.text(
      context,
      size: 12,
      color: SearchTokens.muted,
    );
    final saved = context.watch<SavedPlacesCubit>().state;

    final pickOnMap = SearchOptionRow(
      icon: LucideIcons.map,
      iconColor: SearchTokens.ink,
      title: 'Pick on the map',
      subtitle: 'Move a pin to anywhere',
      trailing: const Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: SearchTokens.muted,
      ),
      onTap: () => _close(const PickOnMap()),
    );

    Widget check(bool on) => on
        ? const Icon(LucideIcons.check, size: 18, color: SearchTokens.brand)
        : const SizedBox.shrink();

    List<Widget> typingChildren() {
      final q = _controller.text.trim().toLowerCase();
      final savedMatches = saved.places
          .where(
            (p) =>
                p.label.toLowerCase().contains(q) ||
                (p.address?.toLowerCase().contains(q) ?? false),
          )
          .toList();
      return [
        BlocBuilder<PlaceSearchCubit, PlaceSearchState>(
          builder: (context, state) => PlaceSearchResults(
            state: state,
            onPick: (p) => _close(UsePlace(p.origin)),
            onRetry: context.read<PlaceSearchCubit>().retry,
            leading: [
              if (savedMatches.isNotEmpty) Text('Saved places', style: muted12),
              for (final p in savedMatches)
                SearchOptionRow(
                  icon: savedPlaceIcon(p.kind),
                  iconColor: SearchTokens.brand,
                  title: p.label,
                  subtitle: p.address,
                  onTap: () => _close(UsePlace(p.toOrigin())),
                ),
              if (savedMatches.isNotEmpty) const SizedBox(height: 14),
            ],
            trailing: pickOnMap,
          ),
        ),
      ];
    }

    List<Widget> idleChildren() => [
      SearchOptionRow(
        icon: LucideIcons.locate,
        iconColor: SearchTokens.brand,
        title: 'Current location',
        subtitle: widget.currentLocationLabel,
        trailing: widget.current == null ? check(true) : null,
        onTap: () => _close(const UseCurrentLocation()),
      ),
      const SearchDivider(),
      pickOnMap,
      const SizedBox(height: 14),
      SavedPlacesSection(
        state: saved,
        current: widget.current,
        onUse: (p) => _close(UsePlace(p.toOrigin())),
        onSet: (kind) => _edit(kind: kind),
        onAdd: () => _edit(kind: SavedPlaceKind.custom),
        onMore: _more,
        onSignIn: () => _close(const SignInToSave()),
        onRetry: () => context.read<SavedPlacesCubit>().load(),
      ),
      const SizedBox(height: 14),
      Text('Recent places', style: muted12),
      if (widget.recentPlaces.isEmpty) ...[
        const SizedBox(height: 8),
        Text(
          'Places you search near will be kept here.',
          style: SearchTokens.text(context, color: SearchTokens.muted),
        ),
      ],
      for (final place in widget.recentPlaces)
        SearchOptionRow(
          icon: LucideIcons.clock,
          iconColor: SearchTokens.ink,
          title: place.label,
          subtitle: place.subtitle,
          trailing: widget.current == place ? check(true) : null,
          onTap: () => _close(UsePlace(place)),
        ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: SearchTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // The keyboard inset sits inside the surface, so the sheet's colour
      // runs under the keyboard's rounded top corners.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: sheetMaxHeight(context)),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          // 34 under the content, which is the home-indicator area; above
          // the keyboard 16 is enough.
          MediaQuery.viewInsetsOf(context).bottom > 0
              ? 16
              : (MediaQuery.viewPaddingOf(context).bottom > 26
                    ? MediaQuery.viewPaddingOf(context).bottom + 8
                    : 34),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            const SizedBox(height: SheetTitleRow.gap),
            SheetTitleRow(title: 'Search near'),
            const SizedBox(height: SheetTitleRow.gap),
            PlaceField(
              controller: _controller,
              hint: 'Place, landmark or street',
              onSubmitted: _takeFirst,
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: typing ? typingChildren() : idleChildren(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 85% of the screen, but never so tall that the sheet's top runs under
/// the status bar once the keyboard is up. A modal sheet's own MediaQuery
/// has the status bar removed, so it is read from the view.
double sheetMaxHeight(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  final statusBar = MediaQueryData.fromView(View.of(context)).padding.top;
  return math.min(size.height * 0.85, size.height - keyboard - statusBar - 16);
}

/// 36 x 4 grabber at the top of a sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: SearchTokens.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// SemiBold 16 title with a close X at the end.
///
/// 44 tall (the close target), growing with the title at large text; a
/// fixed 24 clipped the title from about 1.1x. Callers keep 4 above and
/// below, which puts the title where the old 14 + 24 + 14 did.
class SheetTitleRow extends StatelessWidget {
  const SheetTitleRow({super.key, required this.title});

  final String title;

  /// The gap callers leave above and below.
  static const gap = 4.0;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 44),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: SearchTokens.text(
              context,
              size: 16,
              weight: FontWeight.w600,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Close',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            // 44 x 44 target; the glyph stays at the row's end.
            child: const SizedBox.square(
              dimension: 44,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(LucideIcons.x, size: 20, color: SearchTokens.ink),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The 48pt grey pill field with a search glyph, and a clear X once there
/// is text.
class PlaceField extends StatelessWidget {
  const PlaceField({
    super.key,
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  /// The keyboard's Search key: takes the first result.
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: SearchTokens.field,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 18, color: SearchTokens.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              cursorColor: SearchTokens.brand,
              style: SearchTokens.text(context),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmitted?.call(),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: SearchTokens.text(
                  context,
                  color: SearchTokens.muted,
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox(width: 16)
                : SearchIconButton(
                    icon: LucideIcons.circleX,
                    label: 'Clear',
                    color: SearchTokens.muted,
                    onTap: controller.clear,
                  ),
          ),
        ],
      ),
    );
  }
}

enum _SavedAction { edit, delete }

/// Edit or delete one saved place.
class _SavedActionsSheet extends StatelessWidget {
  const _SavedActionsSheet({required this.place});

  final SavedPlace place;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: SearchTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottom > 26 ? bottom + 8 : 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetGrabber(),
          const SizedBox(height: 14),
          Text(
            place.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SearchTokens.text(
              context,
              size: 16,
              weight: FontWeight.w600,
            ),
          ),
          if ((place.address ?? '').isNotEmpty)
            Text(
              place.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SearchTokens.text(
                context,
                size: 12,
                color: SearchTokens.muted,
              ),
            ),
          const SizedBox(height: 8),
          SearchOptionRow(
            icon: LucideIcons.pencil,
            iconColor: SearchTokens.ink,
            title: place.kind == SavedPlaceKind.custom
                ? 'Edit name or place'
                : 'Change address',
            onTap: () => Navigator.of(context).pop(_SavedAction.edit),
          ),
          SearchOptionRow(
            icon: LucideIcons.trash2,
            iconColor: SearchTokens.closed,
            title: 'Delete',
            onTap: () => Navigator.of(context).pop(_SavedAction.delete),
          ),
        ],
      ),
    );
  }
}
