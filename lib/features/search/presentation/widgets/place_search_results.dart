import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/presentation/cubit/place_search_cubit.dart';
import 'package:nook/features/search/presentation/widgets/search_option_row.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// The icon a place row leads with. Areas that have cafes on Nook get the
/// cup, so the places worth searching near stand out from the map's.
IconData placeIcon(PlaceType type) => switch (type) {
  PlaceType.nookArea => LucideIcons.coffee,
  PlaceType.area => LucideIcons.mapPin,
  PlaceType.street => LucideIcons.signpost,
  PlaceType.landmark => LucideIcons.building2,
  PlaceType.address => LucideIcons.house,
};

/// The rows under a place field while typing: matching places (Nook's
/// areas first, then the map's), a status line when there is something to
/// say, and the map data credit when map places are shown.
///
/// [leading] goes above the places (saved places that match); [trailing]
/// below the credit ("Pick on the map").
class PlaceSearchResults extends StatelessWidget {
  const PlaceSearchResults({
    super.key,
    required this.state,
    required this.onPick,
    this.leading = const [],
    this.trailing,
    this.onRetry,
  });

  final PlaceSearchState state;
  final ValueChanged<PlaceSuggestion> onPick;
  final List<Widget> leading;
  final Widget? trailing;

  /// Asks the map again after it didn't answer. Null hides Try again.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final results = state.results;
    final muted12 = SearchTokens.text(
      context,
      size: 12,
      color: SearchTokens.muted,
    );
    final q = state.query;
    final busy = state.status == PlaceSearchStatus.loading;
    final nothing = results.isEmpty && leading.isEmpty;

    Widget? status;
    if (state.status == PlaceSearchStatus.unavailable) {
      // Usually a slow or busy geocoder, not a broken map: say so, and let
      // them ask again.
      status = _Note(
        title: nothing ? 'Place search is slow right now' : null,
        body: nothing
            ? 'Try again, or pick the spot on the map.'
            : 'Place search is slow right now, so only areas with cafes on '
                  'Nook are shown.',
        onRetry: onRetry,
      );
    } else if (nothing && busy) {
      status = _Note(body: 'Looking for places…');
    } else if (nothing && state.status == PlaceSearchStatus.done) {
      status = _Note(
        title: 'No places match “$q”',
        body: 'Check the spelling, or drop a pin on the map instead.',
      );
    } else if (nothing && q.length < PlaceSearchCubit.minRemoteLength) {
      status = _Note(body: 'Keep typing to search for a place.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...leading,
        if (results.isNotEmpty) Text('Places', style: muted12),
        for (final place in results)
          SearchOptionRow(
            icon: placeIcon(place.type),
            iconColor: place.fromNook ? SearchTokens.brand : SearchTokens.ink,
            title: place.origin.label,
            subtitle: place.origin.subtitle,
            onTap: () => onPick(place),
          ),
        ?status,
        if (state.showsAttribution)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              state.attribution!,
              textAlign: TextAlign.right,
              style: SearchTokens.text(
                context,
                size: 11,
                color: SearchTokens.muted,
              ),
            ),
          ),
        if (trailing != null) ...[
          const SizedBox(height: 14),
          const SearchDivider(),
          trailing!,
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({this.title, required this.body, this.onRetry});

  final String? title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = title;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t != null) ...[
            Text(t, style: SearchTokens.text(context, weight: FontWeight.w600)),
            const SizedBox(height: 4),
          ],
          Text(
            body,
            style: SearchTokens.text(
              context,
              size: t == null ? 14 : 12,
              color: SearchTokens.muted,
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 44),
                foregroundColor: SearchTokens.brand,
              ),
              child: const Text('Try again'),
            ),
        ],
      ),
    );
  }
}
