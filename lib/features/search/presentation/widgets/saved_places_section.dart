import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';
import 'package:nook/features/search/presentation/cubit/saved_places_cubit.dart';
import 'package:nook/features/search/presentation/widgets/search_option_row.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

IconData savedPlaceIcon(SavedPlaceKind kind) => switch (kind) {
  SavedPlaceKind.home => LucideIcons.house,
  SavedPlaceKind.work => LucideIcons.briefcase,
  SavedPlaceKind.custom => LucideIcons.bookmark,
};

/// "Saved places" in the "Search near" sheet: Home and School or work
/// always (set or not), the user's own places, then "Add a place".
///
/// One tap on a set place searches near it; the ⋯ beside it edits or
/// deletes. An unset Home or Work opens the editor instead.
class SavedPlacesSection extends StatelessWidget {
  const SavedPlacesSection({
    super.key,
    required this.state,
    required this.current,
    required this.onUse,
    required this.onSet,
    required this.onAdd,
    required this.onMore,
    required this.onSignIn,
    required this.onRetry,
  });

  final SavedPlacesState state;

  /// The origin in use, to tick the saved place it came from.
  final SearchOrigin? current;
  final ValueChanged<SavedPlace> onUse;

  /// Opens the editor for an unset Home or Work.
  final ValueChanged<SavedPlaceKind> onSet;
  final VoidCallback onAdd;
  final ValueChanged<SavedPlace> onMore;
  final VoidCallback onSignIn;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final muted12 = SearchTokens.text(
      context,
      size: 12,
      color: SearchTokens.muted,
    );
    final children = <Widget>[Text('Saved places', style: muted12)];

    if (!state.canSave && state.status != SavedPlacesStatus.loading) {
      children.add(
        SearchOptionRow(
          icon: LucideIcons.house,
          iconColor: SearchTokens.ink,
          title: 'Save Home and School or work',
          subtitle: 'Sign in to search near them in one tap',
          trailing: const Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: SearchTokens.muted,
          ),
          onTap: onSignIn,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (state.status == SavedPlacesStatus.error && state.places.isEmpty) {
      children.add(
        SearchOptionRow(
          icon: LucideIcons.refreshCw,
          iconColor: SearchTokens.ink,
          title: 'Couldn’t load your places',
          subtitle: 'Tap to try again',
          onTap: onRetry,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    final loading = state.status == SavedPlacesStatus.loading;
    Widget preset(SavedPlaceKind kind, SavedPlace? place) {
      if (place == null) {
        return SearchOptionRow(
          icon: savedPlaceIcon(kind),
          iconColor: SearchTokens.ink,
          title: kind.presetLabel,
          subtitle: loading ? null : 'Set it once, search near it anytime',
          onTap: loading ? null : () => onSet(kind),
        );
      }
      return _savedRow(place);
    }

    children
      ..add(preset(SavedPlaceKind.home, state.home))
      ..add(preset(SavedPlaceKind.work, state.work))
      ..addAll(state.custom.map(_savedRow));

    if (!loading) {
      if (state.atLimit) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'You’ve saved ${ISavedPlacesRepository.maxPlaces} places, the '
              'most you can keep. Delete one to add another.',
              style: muted12,
            ),
          ),
        );
      } else {
        children.add(
          SearchOptionRow(
            icon: LucideIcons.plus,
            iconColor: SearchTokens.brand,
            title: 'Add a place',
            subtitle: 'A friend’s place, the gym, anywhere you go',
            onTap: onAdd,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _savedRow(SavedPlace place) {
    final selected = current != null && current == place.toOrigin();
    return SearchOptionRow(
      icon: savedPlaceIcon(place.kind),
      iconColor: SearchTokens.brand,
      title: place.label,
      subtitle: place.address,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            const Icon(LucideIcons.check, size: 18, color: SearchTokens.brand),
          SearchIconButton(
            icon: LucideIcons.ellipsis,
            label: 'Edit or delete ${place.label}',
            color: SearchTokens.muted,
            onTap: () => onMore(place),
          ),
        ],
      ),
      onTap: () => onUse(place),
    );
  }
}
