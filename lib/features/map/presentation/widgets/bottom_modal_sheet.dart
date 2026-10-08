import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sliding_panel_kit/sliding_panel_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_states.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_cafe_card.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_bottom_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_content.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_sub_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Where the page can send the sheet: its full list, or down to its chips.
enum MapSheetSnap { open, collapsed }

/// Lets the map page move the sheet between its snaps from outside.
class MapSheetCommands extends ChangeNotifier {
  MapSheetSnap? _requested;

  /// The last snap asked for; the sheet reads it when notified.
  MapSheetSnap? get requested => _requested;

  /// Slides the sheet up to its open snap, the full list.
  void expand() => _request(MapSheetSnap.open);

  /// Lowers the sheet to its chips, so a pin's card has room over the map.
  void collapse() => _request(MapSheetSnap.collapsed);

  void _request(MapSheetSnap snap) {
    _requested = snap;
    notifyListeners();
  }
}

class BottomModalSheet extends StatefulWidget {
  final List<CafeSummary> cafes;
  final List<CafeTagsEntity> tags;
  final ValueChanged<BottomSheetMetrics>? onMetricsChanged;
  final bool isLoadingCafes;

  /// A failed load. The sheet shows the failure in place of its chips and
  /// list, so the map and search field stay usable above it.
  final Object? error;
  final VoidCallback? onRetry;

  /// The place distances are measured from; null means the phone.
  final GeoPoint? distanceFrom;

  /// The list hit its fetch limit, so the count reads "20+".
  final bool isCapped;

  /// Requests from the page, such as the map/list button opening the list.
  final MapSheetCommands? commands;

  const BottomModalSheet({
    super.key,
    required this.cafes,
    required this.tags,
    this.onMetricsChanged,
    this.isLoadingCafes = false,
    this.error,
    this.onRetry,
    this.distanceFrom,
    this.isCapped = false,
    this.commands,
  });

  @override
  State<BottomModalSheet> createState() => _BottomModalSheetState();
}

class _BottomModalSheetState extends State<BottomModalSheet> {
  /// 36x4 grabber, 8 above and 10 below it.
  static const _handle = SlidingPanelHandle(
    width: 36,
    color: MapTokens.border,
    padding: EdgeInsets.only(top: 8, bottom: 10),
  );

  final controller = SlidingPanelController();
  final _handleKey = GlobalKey();
  final _tagsRowKey = GlobalKey();
  final _countKey = GlobalKey();

  static const double _maxExtent = 0.80;
  static const double _fallbackMinExtent = 0.10;
  static const double _tagsBottomGap = 10.0;

  /// Figma: 24 from the count to the first photo. Half of it is a fixed gap
  /// outside the list, so scrolled rows stop clear of the label instead of
  /// sliding up against it; the other half is the list's own top padding.
  static const double _countGap = 12.0;
  static const double _listTopPad = 24.0 - _countGap;

  /// Collapsed, 16 shows under the count; [_countGap] is part of it.
  static const double _collapsedBottomPad = 16.0 - _countGap;
  static const double _estimatedTagsRowHeight = 52.0;

  double _minExtent = _fallbackMinExtent;
  double _panelMaxHeight = 0.0;
  double _handleHeight = 0.0;

  // [OPT-1] Cache last emitted metrics to skip redundant parent setState calls.
  BottomSheetMetrics? _lastMetrics;

  /// Set by [MapSheetCommands]: the asked-for snap becomes the only one, so
  /// the panel springs to it through its own snap logic (which is what keeps
  /// the list scrollable once it arrives). The usual snaps come back on the
  /// next touch, when the panel's velocity reading is fresh; restoring them
  /// earlier would re-snap on the stale fling that last moved it.
  MapSheetSnap? _forcedSnap;

  @override
  void initState() {
    super.initState();
    controller.addListener(_notifyMetrics);
    widget.commands?.addListener(_onCommand);
  }

  @override
  void didUpdateWidget(BottomModalSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commands != widget.commands) {
      oldWidget.commands?.removeListener(_onCommand);
      widget.commands?.addListener(_onCommand);
    }
  }

  void _onCommand() {
    final snap = widget.commands?.requested;
    if (!mounted || snap == null) return;
    setState(() => _forcedSnap = snap);
  }

  @override
  void dispose() {
    widget.commands?.removeListener(_onCommand);
    controller.removeListener(_notifyMetrics);
    controller.dispose();
    super.dispose();
  }

  void _scheduleMinExtentUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _panelMaxHeight <= 0) return;

      const handleWidget = _handle;
      final handleBox =
          _handleKey.currentContext?.findRenderObject() as RenderBox?;
      final tagsBox =
          _tagsRowKey.currentContext?.findRenderObject() as RenderBox?;

      final handleHeight =
          handleBox?.size.height ?? handleWidget.preferredSize.height;
      final tagsHeight = tagsBox?.size.height ?? _estimatedTagsRowHeight;
      // Collapsed, the sheet still shows the count under the chips.
      final countBox =
          _countKey.currentContext?.findRenderObject() as RenderBox?;
      final countHeight = countBox?.size.height ?? 18;
      _handleHeight = handleHeight;

      final contentHeight = (_panelMaxHeight - handleHeight).clamp(
        1.0,
        _panelMaxHeight,
      );
      final target =
          (tagsHeight +
              _tagsBottomGap +
              countHeight +
              _countGap +
              _collapsedBottomPad) /
          contentHeight;
      final clamped = target.clamp(0.0, _maxExtent).toDouble();

      if ((clamped - _minExtent).abs() > 0.001) {
        setState(() => _minExtent = clamped);
      }
      _notifyMetrics();
    });
  }

  double _normalizedExtent(double extent, double minExtent) {
    final range = 1 - minExtent;
    if (range == 0) return 1;
    return (extent - minExtent) / range;
  }

  void _notifyMetrics() {
    final callback = widget.onMetricsChanged;
    if (callback == null || _panelMaxHeight <= 0) return;

    final minExtent = _minExtent.clamp(0.0, _maxExtent).toDouble();
    final extent = controller.extent.clamp(minExtent, 1.0);
    final contentPixels = _panelMaxHeight - _handleHeight;
    final minContentPixels = contentPixels * minExtent;
    final travel = contentPixels - minContentPixels;
    final normalized = _normalizedExtent(extent, minExtent);
    final dy = (1 - normalized) * travel;
    final topFromBottom = _panelMaxHeight - dy;

    // [OPT-1] Skip emission if neither extent nor position changed meaningfully.
    // This prevents per-frame parent setState during panel drag.
    final last = _lastMetrics;
    if (last != null &&
        (last.topFromBottom - topFromBottom).abs() < 0.5 &&
        last.extent == extent) {
      return;
    }

    final metrics = BottomSheetMetrics(
      extent: extent,
      minExtent: minExtent,
      maxExtent: _maxExtent,
      topFromBottom: topFromBottom,
      panelHeight: _panelMaxHeight,
    );
    _lastMetrics = metrics;
    callback(metrics);
  }

  @override
  Widget build(BuildContext context) {
    // [OPT-2] Hoist textScale here — it only changes with accessibility
    // settings, not on every panel drag or list scroll.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final cardHeight = 360 * textScale;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_panelMaxHeight != constraints.maxHeight) {
          _panelMaxHeight = constraints.maxHeight;
          _scheduleMinExtentUpdate();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _notifyMetrics();
          });
        }

        // [OPT-3] Derive cardWidth from the outer LayoutBuilder constraints
        // so we don't need a second nested LayoutBuilder just for width.
        final cardWidth = (constraints.maxWidth - 32).clamp(
          0.0,
          double.infinity,
        );

        final minExtent = _minExtent.clamp(0.0, _maxExtent).toDouble();

        return Listener(
          onPointerDown: (_) {
            if (_forcedSnap != null) setState(() => _forcedSnap = null);
          },
          child: SlidingPanelBuilder(
            controller: controller,
            minExtent: minExtent,
            initialExtent: _maxExtent,
            snapConfig: SlidingPanelSnapConfig(
              extents: switch (_forcedSnap) {
                MapSheetSnap.open => [_maxExtent],
                MapSheetSnap.collapsed => [minExtent],
                null => [minExtent, _maxExtent],
              },
              includeBoundaryExtents: _forcedSnap == null,
              velocityRange: (400, 2400),
              animation: SpringSnapAnimation.fixed(
                SpringDescription(mass: 1, stiffness: 350, damping: 30),
              ),
            ),
            handle: _handle,
            builder: (context, handle) {
              return SlidingPanelBody(
                shadowColor: Colors.black.withValues(alpha: 0.1),
                color: MapTokens.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Column(
                  children: [
                    if (handle != null)
                      SizedBox(key: _handleKey, child: handle),

                    // [OPT-4] Extracted to its own widget so FilterCubit rebuilds
                    // are isolated here and don't invalidate the list below.
                    if (widget.error != null)
                      Flexible(
                        child: MapSheetStateView.error(
                          error: widget.error!,
                          onRetry: widget.onRetry ?? () {},
                          onSignIn: () => context.push('/login'),
                        ),
                      )
                    else ...[
                      _FilterChipRow(tagsRowKey: _tagsRowKey),

                      const SizedBox(height: _tagsBottomGap),

                      // "0 cafes in view" says nothing the empty state under it
                      // does not, so the count shows only with cafes.
                      if (!widget.isLoadingCafes && widget.cafes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MapTokens.gutter,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              key: _countKey,
                              '${widget.cafes.length}${widget.isCapped ? '+' : ''} '
                              '${widget.cafes.length == 1 && !widget.isCapped ? 'cafe' : 'cafes'} in view',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 12,
                                    color: MapTokens.muted,
                                  ),
                            ),
                          ),
                        ),

                      if (!widget.isLoadingCafes && widget.cafes.isNotEmpty)
                        const SizedBox(height: _countGap),

                      // [OPT-3] Replaced inner LayoutBuilder with Flexible + direct
                      // use of cardWidth/cardHeight derived above.
                      Flexible(
                        child: _CafeList(
                          topPadding: _listTopPad,
                          cafes: widget.cafes,
                          isLoadingCafes: widget.isLoadingCafes,
                          cardWidth: cardWidth,
                          cardHeight: cardHeight,
                          distanceFrom: widget.distanceFrom,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// [OPT-4] Isolated BlocBuilder so filter state changes only rebuild the chip
// row, not the SlidingPanelBody or the cafe list.
class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.tagsRowKey});

  final GlobalKey tagsRowKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: tagsRowKey,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MapTokens.gutter),
        child: BlocBuilder<FilterCubit, CafeFilter>(
          // [OPT-4] Only rebuild when the values this widget actually uses change.
          buildWhen: (prev, next) =>
              prev.sort != next.sort ||
              prev.tagNames != next.tagNames ||
              prev.openNow != next.openNow,
          builder: (context, filter) {
            final fadersActive = _anyMapFilterActive(filter);
            final bestForActive = _hasTagInPool(
              filter,
              kMapFilterBestForLabels,
            );
            final amenitiesActive = _hasTagInPool(
              filter,
              kMapFilterAmenityLabels,
            );
            final paymentActive = _hasTagInPool(
              filter,
              kMapFilterPaymentLabels,
            );
            final sortActive = filter.sort != 'nearby';

            final total =
                filter.tagNames.length +
                (sortActive ? 1 : 0) +
                (filter.openNow ? 1 : 0);

            // Sliders first, then sort, then the tag groups. A chip with a
            // choice in it fills green and carries its count.
            return Row(
              children: [
                _QuickFilterChip(
                  icon: LucideIcons.slidersHorizontal,
                  semanticLabel: 'All filters',
                  active: fadersActive,
                  count: total,
                  showCaret: false,
                  onTap: () => MapFilterBottomSheet.show(context),
                ),
                const SizedBox(width: 8),
                // "Can I go now" in one tap, first after the sliders
                // (docs/ux/find-a-cafe.md, finding 2).
                _QuickFilterChip(
                  title: 'Open now',
                  active: filter.openNow,
                  showCaret: false,
                  onTap: () {
                    final cubit = context.read<FilterCubit>()..toggleOpenNow();
                    context.read<MapBloc>().add(
                      LoadMapDataEvent(filter: cubit.state),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  title: mapFilterSortLabel(filter.sort),
                  active: sortActive,
                  onTap: () =>
                      MapFilterSubSheet.show(context, MapFilterSubSection.sort),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  title: 'Best for',
                  active: bestForActive,
                  count: _countInPool(filter, kMapFilterBestForLabels),
                  onTap: () => MapFilterSubSheet.show(
                    context,
                    MapFilterSubSection.bestFor,
                  ),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  title: 'Amenities',
                  active: amenitiesActive,
                  count: _countInPool(filter, kMapFilterAmenityLabels),
                  onTap: () => MapFilterSubSheet.show(
                    context,
                    MapFilterSubSection.amenities,
                  ),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  title: 'Payment',
                  active: paymentActive,
                  count: _countInPool(filter, kMapFilterPaymentLabels),
                  onTap: () => MapFilterSubSheet.show(
                    context,
                    MapFilterSubSection.payment,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// [OPT-3] Extracted cafe list into its own StatelessWidget. Receives
// pre-computed cardWidth/cardHeight so it never needs its own LayoutBuilder.
class _CafeList extends StatelessWidget {
  const _CafeList({
    required this.topPadding,
    required this.cafes,
    required this.isLoadingCafes,
    required this.cardWidth,
    required this.cardHeight,
    this.distanceFrom,
  });

  final GeoPoint? distanceFrom;

  final double topPadding;
  final List<CafeSummary> cafes;
  final bool isLoadingCafes;
  final double cardWidth;
  final double cardHeight;

  static const _skeletonCafe = CafeSummary(
    id: 'temp',
    name: 'Loading cafe...',
    address: 'Location...',
    rating: 0,
    tags: [],
  );

  @override
  Widget build(BuildContext context) {
    final showSkeleton = isLoadingCafes && cafes.isEmpty;
    final showEmpty = !isLoadingCafes && cafes.isEmpty;

    if (showSkeleton) return const MapSheetSkeleton();

    if (showEmpty) {
      final filtered = _anyMapFilterActive(context.watch<FilterCubit>().state);
      return MapSheetStateView.noCafes(
        onClearFilters: filtered
            ? () {
                context.read<FilterCubit>().reset();
                context.read<MapBloc>().add(
                  LoadMapDataEvent(filter: const CafeFilter()),
                );
              }
            : null,
      );
    }

    // "Nearby" lists the cafes by distance from where distances are
    // measured (the chosen place, else the phone), the same point the rows
    // show; the fetch order read 1.7, 1.2, 3.7, 1.5 km. (UX S7)
    final sort = context.select<FilterCubit, String>((c) => c.state.sort);
    final phone = DeviceLocation.instance.position.value;
    final origin =
        distanceFrom ??
        (phone == null
            ? null
            : GeoPoint(lat: phone.latitude, lng: phone.longitude));
    final rows = sort == 'nearby' && origin != null
        ? sortByDistance(cafes, origin)
        : cafes;
    final itemCount = showSkeleton ? 4 : rows.length;

    // Rows scrolling up fade out over the first [_fade] points of the list
    // instead of being cut flat just under the count.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00000000), Color(0xFF000000)],
        stops: [0, bounds.height <= 0 ? 0 : (_fade / bounds.height)],
      ).createShader(bounds),
      child: Skeletonizer(
        enabled: showSkeleton,
        effect: const PulseEffect(),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            MapTokens.gutter,
            topPadding,
            MapTokens.gutter,
            24,
          ),
          itemCount: itemCount,
          // Figma: each row is padded 14 above and below its content, and the
          // 1pt divider sits between rows, so 14 / divider / 14.
          separatorBuilder: (context, _) =>
              const Divider(height: 29, thickness: 1, color: MapTokens.border),
          itemBuilder: (context, index) {
            final cafe = showSkeleton ? _skeletonCafe : rows[index];
            return MapSheetCafeCard(
              width: cardWidth,
              cafe: cafe,
              isSkeleton: showSkeleton,
              distanceFrom: distanceFrom,
            );
          },
        ),
      ),
    );
  }

  static const double _fade = 12;
}

class BottomSheetMetrics {
  final double extent;
  final double minExtent;
  final double maxExtent;
  final double topFromBottom;

  /// Height of the box the sheet slides in; its top edge at full extent.
  final double panelHeight;

  const BottomSheetMetrics({
    required this.extent,
    required this.minExtent,
    required this.maxExtent,
    required this.topFromBottom,
    this.panelHeight = 0,
  });

  /// Open past its collapsed snap, so list rows show.
  bool get isExpanded => extent > minExtent + 0.01;
}

/// [cafes] nearest to [from] first; cafes without coordinates go last, in
/// their original order.
List<CafeSummary> sortByDistance(List<CafeSummary> cafes, GeoPoint from) {
  double key(CafeSummary c) {
    final lat = c.lat, lng = c.lng;
    if (lat == null || lng == null) return double.infinity;
    return haversineMeters(from, GeoPoint(lat: lat, lng: lng));
  }

  final indexed =
      [for (var i = 0; i < cafes.length; i++) (i: i, d: key(cafes[i]))]
        ..sort((a, b) {
          final byDistance = a.d.compareTo(b.d);
          return byDistance != 0 ? byDistance : a.i.compareTo(b.i);
        });
  return [for (final e in indexed) cafes[e.i]];
}

bool _anyMapFilterActive(CafeFilter f) =>
    f.sort != 'nearby' || f.tagNames.isNotEmpty || f.openNow;

bool _hasTagInPool(CafeFilter f, List<String> pool) =>
    f.tagNames.any(pool.contains);

int _countInPool(CafeFilter f, List<String> pool) =>
    f.tagNames.where(pool.contains).length;

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    this.title,
    this.icon,
    this.semanticLabel,
    required this.onTap,
    this.active = false,
    this.count = 0,
    this.showCaret = true,
  });

  final String? title;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;
  final bool active;

  /// How many choices are made inside this chip; shown when above zero.
  final int count;
  final bool showCaret;

  @override
  Widget build(BuildContext context) {
    final label = title;
    final leading = icon;
    // The sliders chip shows its total as a green number on white with a
    // green outline; a group chip with a choice fills green.
    final iconOnly = leading != null && label == null;
    final filled = active && !iconOnly;
    final foreground = filled ? MapTokens.surface : MapTokens.ink;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: foreground,
    );
    final text = label == null ? null : (count > 0 ? '$label · $count' : label);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: filled ? MapTokens.brand : MapTokens.surface,
            borderRadius: BorderRadius.circular(100),
            border: filled
                ? null
                : Border.all(
                    color: active ? MapTokens.brand : MapTokens.border,
                    width: active ? 1.5 : 1,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null)
                Icon(leading, size: 16, color: MapTokens.ink),
              if (iconOnly && count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: style?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MapTokens.brand,
                  ),
                ),
              ],
              if (text != null) Text(text, style: style),
              if (showCaret) ...[
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown, size: 14, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
