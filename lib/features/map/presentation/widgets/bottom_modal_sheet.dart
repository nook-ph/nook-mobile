import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:sliding_panel_kit/sliding_panel_kit.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/features/map/presentation/widgets/cafe_card.dart';
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

  const BottomModalSheet({super.key, required this.cafes, required this.tags});

  @override
  State<BottomModalSheet> createState() => _BottomModalSheetState();
}

class _BottomModalSheetState extends State<BottomModalSheet> {
  final controller = SlidingPanelController();

  static const Color _activeChipBorder = Color(0xFF344E41);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SlidingPanelBuilder(
      controller: controller,
      initialExtent: 0.80,
      snapConfig: SlidingPanelSnapConfig(
        extents: [0.045, 0.80],
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
              if (handle != null) handle,
              Padding(
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
              Flexible(
                child: Skeletonizer(
                  enabled: widget.cafes.isEmpty,
                  effect: const PulseEffect(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    itemCount: widget.cafes.isEmpty ? 3 : widget.cafes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 24),
                    itemBuilder: (BuildContext context, int index) {
                      if (widget.cafes.isEmpty) {
                        return const CafeCard(
                          isSkeleton: true,
                          cafe: CafeSummary(
                            id: 'temp',
                            name: 'Loading cafe...',
                            address: 'Location...',
                            rating: 0,
                            tags: [],
                          ),
                        );
                      }
                      return CafeCard(cafe: widget.cafes[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
      visualDensity: const VisualDensity(
        horizontal: -4,
        vertical: -4,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
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
          Icon(
            PhosphorIcons.caretDown(),
            size: 20,
            color: colors.primary100,
          ),
        ],
      ),
      backgroundColor: colors.surface,
      selectedColor: colors.primary60,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
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
