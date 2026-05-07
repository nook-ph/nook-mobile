import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:sliding_panel_kit/sliding_panel_kit.dart';
import 'package:nook/core/widgets/error/full_page_empty_widget.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_cafe_card.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_bottom_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_content.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_sub_sheet.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BottomModalSheet extends StatefulWidget {
  final List<CafeSummary> cafes;
  final List<CafeTagsEntity> tags;
  final ValueChanged<BottomSheetMetrics>? onMetricsChanged;

  /// True while [MapBloc] is fetching; empty [cafes] then means loading, not zero results.
  final bool isLoadingCafes;

  const BottomModalSheet({
    super.key,
    required this.cafes,
    required this.tags,
    this.onMetricsChanged,
    this.isLoadingCafes = false,
  });

  @override
  State<BottomModalSheet> createState() => _BottomModalSheetState();
}

class _BottomModalSheetState extends State<BottomModalSheet> {
  final controller = SlidingPanelController();
  final _handleKey = GlobalKey();
  final _tagsRowKey = GlobalKey();

  static const double _maxExtent = 0.80;

  /// Conservative floor before tags are laid out (fraction of content below handle).
  static const double _fallbackMinExtent = 0.10;
  static const double _tagsBottomGap = 12.0;
  static const double _estimatedTagsRowHeight = 52.0;

  double _minExtent = _fallbackMinExtent;
  double _panelMaxHeight = 0.0;
  double _handleHeight = 0.0;

  static const Color _activeChipBorder = Color(0xFF344E41);

  @override
  void initState() {
    super.initState();
    controller.addListener(_notifyMetrics);
  }

  @override
  void dispose() {
    controller.removeListener(_notifyMetrics);
    controller.dispose();
    super.dispose();
  }

  void _scheduleMinExtentUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _panelMaxHeight <= 0) return;
      const handleWidget = SlidingPanelHandle(color: Color(0xFFD9D9D9));
      final handleBox =
          _handleKey.currentContext?.findRenderObject() as RenderBox?;
      final tagsBox =
          _tagsRowKey.currentContext?.findRenderObject() as RenderBox?;

      final handleHeight =
          handleBox?.size.height ?? handleWidget.preferredSize.height;
      final tagsHeight =
          tagsBox?.size.height ?? _estimatedTagsRowHeight;
      _handleHeight = handleHeight;

      final contentHeight =
          (_panelMaxHeight - handleHeight).clamp(1.0, _panelMaxHeight);
      final target =
          (tagsHeight + _tagsBottomGap) / contentHeight;
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

    callback(
      BottomSheetMetrics(
        extent: extent,
        minExtent: minExtent,
        maxExtent: _maxExtent,
        topFromBottom: topFromBottom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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

        final minExtent = _minExtent.clamp(0.0, _maxExtent).toDouble();

        return SlidingPanelBuilder(
          controller: controller,
          minExtent: minExtent,
          initialExtent: _maxExtent,
          snapConfig: SlidingPanelSnapConfig(
            extents: [minExtent, _maxExtent],
            velocityRange: (400, 2400),
            animation: SpringSnapAnimation.fixed(
              SpringDescription(mass: 1, stiffness: 350, damping: 30),
            ),
          ),
          handle: const SlidingPanelHandle(color: Color(0xFFD9D9D9)),
          builder: (context, handle) {
            return SlidingPanelBody(
              shadowColor: Colors.transparent,
              color: Colors.white,
              child: Column(
                children: [
                  if (handle != null) SizedBox(key: _handleKey, child: handle),
                  Padding(
                    key: _tagsRowKey,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: BlocBuilder<FilterCubit, CafeFilter>(
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
                          return Row(
                            children: [
                              FilterChip(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(
                                  horizontal: -4,
                                  vertical: -4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                label: Icon(
                                  PhosphorIcons.faders(),
                                  size: 20,
                                  color: colors.primary100,
                                ),
                                backgroundColor: colors.surface,
                                selectedColor: colors.primary60,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                side: BorderSide(
                                  color: fadersActive
                                      ? _activeChipBorder
                                      : colors.border,
                                  width: 1.5,
                                ),
                                selected: false,
                                onSelected: (_) =>
                                    MapFilterBottomSheet.show(context),
                              ),
                              const SizedBox(width: 8),
                              _QuickFilterChip(
                                title: 'Best for',
                                active: bestForActive,
                                onTap: () => MapFilterSubSheet.show(
                                  context,
                                  MapFilterSubSection.bestFor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _QuickFilterChip(
                                title: 'Amenities',
                                active: amenitiesActive,
                                onTap: () => MapFilterSubSheet.show(
                                  context,
                                  MapFilterSubSection.amenities,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _QuickFilterChip(
                                title: 'Payment Option',
                                active: paymentActive,
                                onTap: () => MapFilterSubSheet.show(
                                  context,
                                  MapFilterSubSection.payment,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _QuickFilterChip(
                                title: mapFilterSortLabel(filter.sort),
                                active: sortActive,
                                onTap: () => MapFilterSubSheet.show(
                                  context,
                                  MapFilterSubSection.sort,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: _tagsBottomGap),

                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale =
                            MediaQuery.textScalerOf(context).scale(1.0);
                        final cardWidth =
                            (constraints.maxWidth - 32).clamp(0.0, double.infinity);
                        final cardHeight = 312 * textScale;

                        final showSkeleton =
                            widget.isLoadingCafes && widget.cafes.isEmpty;
                        final showEmpty =
                            !widget.isLoadingCafes && widget.cafes.isEmpty;

                        if (showEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 24,
                              ),
                              child: FullPageEmptyWidget(
                                title: 'No cafes in this area',
                                subtitle:
                                    'Try zooming out or adjusting filters.',
                                icon: Icons.map_outlined,
                              ),
                            ),
                          );
                        }

                        return Skeletonizer(
                          enabled: showSkeleton,
                          effect: const PulseEffect(),
                          child: ListView.separated(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 12,
                              bottom: 24,
                            ),
                            itemCount: showSkeleton
                                ? 3
                                : widget.cafes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 18),
                            itemBuilder: (BuildContext context, int index) {
                              if (showSkeleton) {
                                return SizedBox(
                                  height: cardHeight,
                                  child: MapSheetCafeCard(
                                    width: cardWidth,
                                    cafe: const CafeSummary(
                                      id: 'temp',
                                      name: 'Loading cafe...',
                                      address: 'Location...',
                                      rating: 0,
                                      tags: [],
                                    ),
                                    isSkeleton: true,
                                  ),
                                );
                              }
                              return SizedBox(
                                height: cardHeight,
                                child: MapSheetCafeCard(
                                  width: cardWidth,
                                  cafe: widget.cafes[index],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class BottomSheetMetrics {
  final double extent;
  final double minExtent;
  final double maxExtent;
  final double topFromBottom;

  const BottomSheetMetrics({
    required this.extent,
    required this.minExtent,
    required this.maxExtent,
    required this.topFromBottom,
  });
}

bool _anyMapFilterActive(CafeFilter f) {
  return f.sort != 'nearby' || f.tagNames.isNotEmpty;
}

bool _hasTagInPool(CafeFilter f, List<String> pool) {
  return f.tagNames.any(pool.contains);
}

/// Same metrics as the main filter [FilterChip] (faders): shrinkWrap, density, padding, radius.
class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.title,
    required this.onTap,
    this.active = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool active;

  static const Color _activeChipBorder = Color(0xFF344E41);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FilterChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.primary100,
            ),
          ),
          const SizedBox(width: 6),
          Icon(PhosphorIcons.caretDown(), size: 20, color: colors.primary100),
        ],
      ),
      backgroundColor: colors.surface,
      selectedColor: colors.primary60,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      side: BorderSide(
        color: active ? _activeChipBorder : colors.border,
        width: 1.5,
      ),
      showCheckmark: false,
      selected: false,
      onSelected: (_) => onTap(),
    );
  }
}
