import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// What the "Search near" sheet was closed with.
sealed class SearchOriginChoice {
  const SearchOriginChoice();
}

class UseCurrentLocation extends SearchOriginChoice {
  const UseCurrentLocation();
}

class UsePlace extends SearchOriginChoice {
  const UsePlace(this.place);
  final SearchOrigin place;
}

class PickOnMap extends SearchOriginChoice {
  const PickOnMap();
}

/// "Search near": a place field, current location, pick on the map, and the
/// places searched near before. Typing swaps the options for matching
/// places.
Future<SearchOriginChoice?> showSearchOriginSheet(
  BuildContext context, {
  required SearchOrigin? current,
  required String? currentLocationLabel,
  required List<SearchOrigin> recentPlaces,
  required Future<SearchPlaceIndex> places,
}) {
  return showModalBottomSheet<SearchOriginChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => _OriginSheet(
      current: current,
      currentLocationLabel: currentLocationLabel,
      recentPlaces: recentPlaces,
      places: places,
    ),
  );
}

class _OriginSheet extends StatefulWidget {
  const _OriginSheet({
    required this.current,
    required this.currentLocationLabel,
    required this.recentPlaces,
    required this.places,
  });

  final SearchOrigin? current;
  final String? currentLocationLabel;
  final List<SearchOrigin> recentPlaces;
  final Future<SearchPlaceIndex> places;

  @override
  State<_OriginSheet> createState() => _OriginSheetState();
}

class _OriginSheetState extends State<_OriginSheet> {
  final _controller = TextEditingController();
  SearchPlaceIndex _index = SearchPlaceIndex.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    widget.places
        .then((index) {
          if (!mounted) return;
          setState(() {
            _index = index;
            _loading = false;
          });
        })
        .catchError((Object _) {
          if (mounted) setState(() => _loading = false);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(SearchOriginChoice choice) => Navigator.of(context).pop(choice);

  @override
  Widget build(BuildContext context) {
    final typing = _controller.text.trim().isNotEmpty;
    final matches = _index.match(_controller.text);
    final muted12 = SearchTokens.text(
      context,
      size: 12,
      color: SearchTokens.muted,
    );

    final pickOnMap = _OptionRow(
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: SearchTokens.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SearchTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search near',
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
                      child: const Icon(
                        LucideIcons.x,
                        size: 20,
                        color: SearchTokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: SearchTokens.field,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.search,
                    size: 18,
                    color: SearchTokens.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      cursorColor: SearchTokens.brand,
                      style: SearchTokens.text(context),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Neighbourhood, city or landmark',
                        hintStyle: SearchTokens.text(
                          context,
                          color: SearchTokens.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: typing
                      ? [
                          if (matches.isNotEmpty || _loading)
                            Text('Places', style: muted12),
                          if (matches.isEmpty && _loading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Looking for places…',
                                style: SearchTokens.text(
                                  context,
                                  color: SearchTokens.muted,
                                ),
                              ),
                            ),
                          if (matches.isEmpty && !_loading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No places match “${_controller.text.trim()}”',
                                    style: SearchTokens.text(
                                      context,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Check the spelling, or drop a pin on the '
                                    'map instead.',
                                    style: muted12,
                                  ),
                                ],
                              ),
                            ),
                          for (final place in matches)
                            _OptionRow(
                              icon: LucideIcons.mapPin,
                              iconColor: SearchTokens.brand,
                              title: place.label,
                              subtitle: place.subtitle,
                              onTap: () => _close(UsePlace(place)),
                            ),
                          const SizedBox(height: 14),
                          pickOnMap,
                        ]
                      : [
                          _OptionRow(
                            icon: LucideIcons.locate,
                            iconColor: SearchTokens.brand,
                            title: 'Current location',
                            subtitle: widget.currentLocationLabel,
                            trailing: widget.current == null
                                ? const Icon(
                                    LucideIcons.check,
                                    size: 18,
                                    color: SearchTokens.brand,
                                  )
                                : null,
                            onTap: () => _close(const UseCurrentLocation()),
                          ),
                          const SearchDivider(),
                          pickOnMap,
                          const SizedBox(height: 14),
                          Text('Recent places', style: muted12),
                          if (widget.recentPlaces.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Places you search near will be kept here.',
                              style: SearchTokens.text(
                                context,
                                color: SearchTokens.muted,
                              ),
                            ),
                          ],
                          for (final place in widget.recentPlaces)
                            _OptionRow(
                              icon: LucideIcons.clock,
                              iconColor: SearchTokens.ink,
                              title: place.label,
                              subtitle: place.subtitle,
                              trailing: widget.current == place
                                  ? const Icon(
                                      LucideIcons.check,
                                      size: 18,
                                      color: SearchTokens.brand,
                                    )
                                  : null,
                              onTap: () => _close(UsePlace(place)),
                            ),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 60pt option: 40pt grey circle with an icon, title, optional subtitle,
/// optional trailing icon.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final end = trailing;
    return AdaptiveTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: SearchTokens.field,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SearchTokens.text(context, weight: FontWeight.w500),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SearchTokens.text(
                        context,
                        size: 12,
                        color: SearchTokens.muted,
                      ),
                    ),
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: 12), end],
          ],
        ),
      ),
    );
  }
}
