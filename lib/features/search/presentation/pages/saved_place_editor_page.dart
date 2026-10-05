import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/presentation/widgets/confirm_sheet.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/search/data/search_location.dart';
import 'package:nook/features/search/data/spot_namer.dart';
import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/presentation/cubit/saved_places_cubit.dart';
import 'package:nook/features/search/presentation/pages/search_pick_on_map_page.dart';
import 'package:nook/features/search/presentation/widgets/find_place_sheet.dart';
import 'package:nook/features/search/presentation/widgets/saved_places_section.dart';
import 'package:nook/features/search/presentation/widgets/search_filters.dart';
import 'package:nook/features/search/presentation/widgets/search_option_row.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// Where a saved place is, before it is saved.
typedef _Spot = ({String address, double lat, double lng});

/// Builds the small map under the address. Tests pass a plain box: a
/// MapLibre view needs a platform.
typedef MapPreviewBuilder = Widget Function(double lat, double lng);

/// Add or change a saved place: a name (custom places only), where it is
/// (search, current location, or a pin), and Save. An existing place can
/// be deleted here too.
///
/// Pops the stored [SavedPlace], or null when closed or deleted.
class SavedPlaceEditorPage extends StatefulWidget {
  const SavedPlaceEditorPage({
    super.key,
    required this.cubit,
    required this.kind,
    this.place,
    required this.search,
    required this.places,
    this.mapPreview,
    this.currentPosition,
  });

  final SavedPlacesCubit cubit;
  final SavedPlaceKind kind;

  /// Null when adding.
  final SavedPlace? place;
  final IPlaceSearchRepository search;
  final Future<SearchPlaceIndex> places;
  final MapPreviewBuilder? mapPreview;

  /// The phone's position, asking for it if needed. Defaults to
  /// [DeviceLocation]; tests pass a fake.
  final Future<({double lat, double lng})?> Function()? currentPosition;

  @override
  State<SavedPlaceEditorPage> createState() => _SavedPlaceEditorPageState();
}

class _SavedPlaceEditorPageState extends State<SavedPlaceEditorPage> {
  late final TextEditingController _name;
  _Spot? _spot;
  bool _saving = false;
  bool _locating = false;
  bool _tried = false;
  String? _error;
  String? _locationNote;

  bool get _custom => widget.kind == SavedPlaceKind.custom;
  bool get _editing => widget.place != null;

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    _name = TextEditingController(text: _custom ? p?.label ?? '' : '');
    if (p != null) {
      _spot = (address: p.address ?? '', lat: p.lat, lng: p.lng);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _title {
    if (_custom) return _editing ? 'Edit place' : 'Add a place';
    final name = widget.kind.presetLabel;
    return _editing ? 'Change $name' : 'Set $name';
  }

  String get _saveLabel {
    if (_saving) return 'Saving…';
    if (_editing) return 'Save changes';
    return _custom ? 'Save place' : 'Save as ${widget.kind.presetLabel}';
  }

  ({double lat, double lng})? _bias() {
    final s = _spot;
    if (s != null) return (lat: s.lat, lng: s.lng);
    final d = DeviceLocation.instance.position.value;
    return d == null ? null : (lat: d.latitude, lng: d.longitude);
  }

  Future<void> _find() async {
    final picked = await showFindPlaceSheet(
      context,
      repository: widget.search,
      places: widget.places,
      bias: _bias,
    );
    if (picked == null || !mounted) return;
    final o = picked.origin;
    setState(() {
      _spot = (address: o.fullLabel, lat: o.lat, lng: o.lng);
      _locationNote = null;
    });
  }

  Future<({double lat, double lng})?> _position() async {
    final custom = widget.currentPosition;
    if (custom != null) return custom();
    final status = await searchLocationStatus();
    if (status != SearchLocationStatus.available) {
      await turnOnSearchLocation();
    }
    final p = await DeviceLocation.instance.ensure(forceRefresh: true);
    return p == null ? null : (lat: p.latitude, lng: p.longitude);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationNote = null;
    });
    final at = await _position();
    if (!mounted) return;
    if (at == null) {
      setState(() {
        _locating = false;
        _locationNote =
            'Your location is off. Turn it on in Settings, or search for '
            'the place instead.';
      });
      return;
    }
    final name = await SpotNamer(
      widget.search,
      widget.places,
    ).name(at.lat, at.lng);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _spot = (
        address: _addressOf(name) ?? 'Your current location',
        lat: at.lat,
        lng: at.lng,
      );
    });
  }

  static String? _addressOf(SpotName? name) {
    if (name == null) return null;
    final sub = name.subtitle;
    return sub == null || sub.isEmpty ? name.label : '${name.label}, $sub';
  }

  Future<void> _pickOnMap() async {
    final s = _spot;
    final d = DeviceLocation.instance.position.value;
    final start = s != null
        ? LatLng(s.lat, s.lng)
        : d != null
        ? LatLng(d.latitude, d.longitude)
        : const LatLng(10.3157, 123.8854);
    final pin = await Navigator.of(context).push<SearchOrigin>(
      MaterialPageRoute(
        builder: (_) => SearchPickOnMapPage(
          start: start,
          places: widget.places,
          namer: SpotNamer(widget.search, widget.places),
          heading: 'Move the map to the spot',
          confirmLabel: 'Use this spot',
          caption: !_custom
              ? widget.kind.presetLabel
              : (_name.text.trim().isEmpty ? 'Where it is' : _name.text.trim()),
        ),
      ),
    );
    if (pin == null || !mounted) return;
    setState(() {
      _spot = (
        address: pin.label == SearchOrigin.pinnedLabel
            ? 'Pinned on the map'
            : _addressOf((label: pin.label, subtitle: pin.subtitle))!,
        lat: pin.lat,
        lng: pin.lng,
      );
      _locationNote = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final spot = _spot;
    final name = _name.text.trim();
    setState(() {
      _tried = true;
      _error = null;
    });
    if (spot == null || (_custom && name.isEmpty)) return;
    setState(() => _saving = true);
    try {
      final stored = await widget.cubit.save(
        SavedPlace(
          id: widget.place?.id,
          kind: widget.kind,
          label: _custom ? name : widget.kind.presetLabel,
          address: spot.address,
          lat: spot.lat,
          lng: spot.lng,
        ),
      );
      if (mounted) Navigator.of(context).pop(stored);
    } on SavedPlacesLimitReached {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'You can keep up to ${ISavedPlacesRepository.maxPlaces} places. '
            'Delete one to add another.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Couldn’t save. Check your connection and try again.';
      });
    }
  }

  Future<void> _delete() async {
    final place = widget.place;
    if (place == null) return;
    final ok = await showConfirmSheet(
      context,
      title: 'Delete ${place.label}?',
      message: 'It comes off your saved places.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await widget.cubit.delete(place);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t delete. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final muted12 = SearchTokens.text(
      context,
      size: 12,
      color: SearchTokens.muted,
    );
    final danger12 = SearchTokens.text(
      context,
      size: 12,
      color: SearchTokens.closed,
    );
    final spot = _spot;
    final nameMissing = _tried && _custom && _name.text.trim().isEmpty;
    final spotMissing = _tried && spot == null;

    return Scaffold(
      backgroundColor: SearchTokens.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 8, 20, 8),
            child: Row(
              children: [
                SearchIconButton(
                  icon: LucideIcons.arrowLeft,
                  label: 'Back',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SearchTokens.text(
                      context,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (_custom) ...[
                  Text('Name', style: muted12),
                  const SizedBox(height: 6),
                  _FieldShell(
                    icon: savedPlaceIcon(SavedPlaceKind.custom),
                    error: nameMissing,
                    child: TextField(
                      controller: _name,
                      maxLength: SavedPlace.maxLabelLength,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: SearchTokens.brand,
                      style: SearchTokens.text(context),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        counterText: '',
                        hintText: 'Lola’s house, the gym…',
                        hintStyle: SearchTokens.text(
                          context,
                          color: SearchTokens.muted,
                        ),
                      ),
                    ),
                  ),
                  if (nameMissing) ...[
                    const SizedBox(height: 4),
                    Text('Give it a name.', style: danger12),
                  ],
                  const SizedBox(height: 20),
                ],
                Text('Where it is', style: muted12),
                const SizedBox(height: 6),
                Semantics(
                  button: true,
                  label: spot == null
                      ? 'Search for a place'
                      : 'Address: ${spot.address}. Tap to search again',
                  excludeSemantics: true,
                  child: AdaptiveTap(
                    onTap: _find,
                    borderRadius: BorderRadius.circular(24),
                    child: _FieldShell(
                      icon: LucideIcons.mapPin,
                      iconColor: spot == null
                          ? SearchTokens.muted
                          : SearchTokens.brand,
                      error: spotMissing,
                      child: Text(
                        spot?.address ?? 'Search for a place',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SearchTokens.text(
                          context,
                          color: spot == null
                              ? SearchTokens.muted
                              : SearchTokens.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (spotMissing) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Search for the place, use where you are, or pin it.',
                    style: danger12,
                  ),
                ],
                const SizedBox(height: 4),
                SearchOptionRow(
                  icon: LucideIcons.locate,
                  iconColor: SearchTokens.brand,
                  title: _locating ? 'Finding you…' : 'Use current location',
                  subtitle: _locationNote,
                  subtitleColor: SearchTokens.closed,
                  onTap: _locating ? null : _useCurrentLocation,
                ),
                SearchOptionRow(
                  icon: LucideIcons.map,
                  iconColor: SearchTokens.ink,
                  title: spot == null ? 'Pick on the map' : 'Adjust on the map',
                  trailing: const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: SearchTokens.muted,
                  ),
                  onTap: _pickOnMap,
                ),
                if (spot != null) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Map of the place. Tap to move the pin',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: _pickOnMap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 160,
                          child: (widget.mapPreview ?? _defaultPreview)(
                            spot.lat,
                            spot.lng,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Tap the map to move the pin.', style: muted12),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.lock,
                      size: 14,
                      color: SearchTokens.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Only you can see your saved places. They never '
                        'show on your profile.',
                        style: muted12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: SearchTokens.surface,
              border: Border(top: BorderSide(color: SearchTokens.border)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              bottom > 26 ? bottom + 8 : 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: danger12),
                  const SizedBox(height: 8),
                ],
                SearchPillButton(label: _saveLabel, onTap: _save),
                if (_editing)
                  Semantics(
                    button: true,
                    child: AdaptiveTap(
                      onTap: _saving ? null : _delete,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        child: Text(
                          'Delete place',
                          style: SearchTokens.text(
                            context,
                            weight: FontWeight.w500,
                            color: SearchTokens.closed,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultPreview(double lat, double lng) =>
      _MapPreview(key: ValueKey('$lat,$lng'), lat: lat, lng: lng);
}

/// The 48pt grey pill a field sits in, with a leading icon; a red edge when
/// [error].
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.icon,
    this.iconColor = SearchTokens.muted,
    required this.child,
    this.error = false,
  });

  final IconData icon;
  final Color iconColor;
  final Widget child;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SearchTokens.field,
        borderRadius: BorderRadius.circular(24),
        border: error ? Border.all(color: SearchTokens.closed) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A still map centred on the place, with the brand pin on it.
class _MapPreview extends StatefulWidget {
  const _MapPreview({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  State<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<_MapPreview> {
  static const _fallbackStyle = 'https://tiles.openfreemap.org/styles/bright';
  String? _style;

  @override
  void initState() {
    super.initState();
    rootBundle
        .loadString('assets/mapstyle.json')
        .then((s) => mounted ? setState(() => _style = s) : null)
        .catchError((Object _) {
          if (mounted) setState(() => _style = _fallbackStyle);
        });
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: SearchTokens.field),
        if (style != null)
          IgnorePointer(
            child: MapLibreMap(
              styleString: style,
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.lat, widget.lng),
                zoom: 15,
              ),
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              compassEnabled: false,
            ),
          ),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 32),
            child: Icon(
              LucideIcons.mapPin,
              size: 32,
              color: SearchTokens.brand,
            ),
          ),
        ),
      ],
    );
  }
}
