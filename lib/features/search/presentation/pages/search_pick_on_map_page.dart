import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/search/data/spot_namer.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/presentation/widgets/search_filters.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// Move the map under a fixed pin, then "Search here". Pops a pin origin.
///
/// The spot is named by [namer] once the map stops ("Near Ayala Center
/// Cebu"), else after the Nook neighbourhood it is in when [places] knows
/// one nearby, and "Pinned location" otherwise.
class SearchPickOnMapPage extends StatefulWidget {
  const SearchPickOnMapPage({
    super.key,
    required this.start,
    this.places,
    this.namer,
    this.heading = 'Move the map to set the spot',
    this.confirmLabel = 'Search here',
    this.caption = 'Search near',
  });

  /// The small line above the spot's name.
  final String caption;

  /// Names the spot from the map service, falling back to [places].
  final SpotNamer? namer;

  /// The hint in the pill at the top.
  final String heading;

  /// The button that takes the spot.
  final String confirmLabel;

  /// The places Nook knows, to name the spot under the pin.
  final Future<SearchPlaceIndex>? places;

  /// "Banilad, Cebu City" when [index] has a neighbourhood near the point,
  /// else null.
  static String? nearLabel(SearchPlaceIndex index, double lat, double lng) =>
      index.nearest(lat, lng)?.fullLabel;

  /// Where the map opens: the current origin, the phone, or Cebu City.
  final LatLng start;

  @override
  State<SearchPickOnMapPage> createState() => _SearchPickOnMapPageState();
}

class _SearchPickOnMapPageState extends State<SearchPickOnMapPage> {
  static const _fallbackStyle = 'https://tiles.openfreemap.org/styles/bright';
  static const double _pinSize = 40;

  String? _style;
  MapLibreMapController? _controller;
  SearchPlaceIndex _index = SearchPlaceIndex.empty;

  /// What is under the pin, or null for "Pinned location".
  String? _near;
  String? _nearSubtitle;

  /// Waits for the map to settle before asking the map service.
  Timer? _nameTimer;
  int _nameGeneration = 0;

  @override
  void initState() {
    super.initState();
    rootBundle
        .loadString('assets/mapstyle.json')
        .then((s) => mounted ? setState(() => _style = s) : null)
        .catchError((Object _) {
          if (mounted) setState(() => _style = _fallbackStyle);
        });
    widget.places
        ?.then((index) {
          if (!mounted) return;
          _index = index;
          _rename();
        })
        .catchError((Object _) {});
  }

  LatLng get _target => _controller?.cameraPosition?.target ?? widget.start;

  @override
  void dispose() {
    _nameTimer?.cancel();
    super.dispose();
  }

  /// Names the spot under the pin again, once the map stops moving: the
  /// Nook neighbourhood at once, then the map service's name when it
  /// answers.
  void _rename() {
    final target = _target;
    final near = SearchPickOnMapPage.nearLabel(
      _index,
      target.latitude,
      target.longitude,
    );
    final namer = widget.namer;
    if (namer == null) {
      if (near != _near && mounted) setState(() => _near = near);
      return;
    }
    final generation = ++_nameGeneration;
    _nameTimer?.cancel();
    _nameTimer = Timer(const Duration(milliseconds: 600), () async {
      final name = await namer.name(target.latitude, target.longitude);
      if (!mounted || generation != _nameGeneration) return;
      setState(() {
        _near = name?.label ?? near;
        _nearSubtitle = name?.subtitle;
      });
    });
  }

  void _confirm() {
    final target = _target;
    Navigator.of(context).pop(
      SearchOrigin.pin(
        lat: target.latitude,
        lng: target.longitude,
        near:
            _near ??
            SearchPickOnMapPage.nearLabel(
              _index,
              target.latitude,
              target.longitude,
            ),
        subtitle: _nearSubtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final top = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: SearchTokens.field,
      body: Stack(
        children: [
          if (style != null)
            Positioned.fill(
              child: MapLibreMap(
                styleString: style,
                initialCameraPosition: CameraPosition(
                  target: widget.start,
                  zoom: 15,
                ),
                trackCameraPosition: true,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                onMapCreated: (c) => _controller = c,
                onCameraIdle: _rename,
              ),
            ),
          // The pin's tip marks the map centre, which is the point picked.
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: _pinSize),
              child: IgnorePointer(
                child: Icon(
                  LucideIcons.mapPin,
                  size: _pinSize,
                  color: SearchTokens.brand,
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Back',
                  excludeSemantics: true,
                  child: AdaptiveTap(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: SearchTokens.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.arrowLeft,
                        size: 20,
                        color: SearchTokens.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: SearchTokens.surface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      widget.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SearchTokens.text(
                        context,
                        size: 12,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: SearchTokens.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                bottomInset > 26 ? bottomInset + 8 : 34,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.caption,
                    style: SearchTokens.text(
                      context,
                      size: 12,
                      color: SearchTokens.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _near ?? SearchOrigin.pinnedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SearchTokens.text(
                      context,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if ((_nearSubtitle ?? '').isNotEmpty)
                    Text(
                      _nearSubtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SearchTokens.text(
                        context,
                        size: 12,
                        color: SearchTokens.muted,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SearchPillButton(label: widget.confirmLabel, onTap: _confirm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
