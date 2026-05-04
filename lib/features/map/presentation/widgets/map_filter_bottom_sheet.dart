import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_content.dart';

/// Placeholder filter sheet for the map cafe list.
class MapFilterBottomSheet extends StatefulWidget {
  const MapFilterBottomSheet({super.key, required this.initialFilter});

  final CafeFilter initialFilter;

  /// Matches [CafeInfo] section headers.
  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Color(0xFF848685),
  );

  static Future<void> show(BuildContext context) {
    final mapBloc = context.read<MapBloc>();
    final initial = context.read<FilterCubit>().state;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider<MapBloc>.value(
        value: mapBloc,
        child: MapFilterBottomSheet(initialFilter: initial),
      ),
    );
  }

  @override
  State<MapFilterBottomSheet> createState() => _MapFilterBottomSheetState();
}

class _MapFilterBottomSheetState extends State<MapFilterBottomSheet> {
  late String _selectedSortId;
  final Set<String> _selectedBestFor = {};
  final Set<String> _selectedAmenities = {};
  final Set<String> _selectedPayment = {};

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilter;
    _selectedSortId = f.sort;
    _selectedBestFor.addAll(
      f.tagNames.intersection(kMapFilterBestForLabels.toSet()),
    );
    _selectedAmenities.addAll(
      f.tagNames.intersection(kMapFilterAmenityLabels.toSet()),
    );
    _selectedPayment.addAll(
      f.tagNames.intersection(kMapFilterPaymentLabels.toSet()),
    );
  }

  void _apply(BuildContext context) {
    final prev = context.read<FilterCubit>().state;
    final next = CafeFilter(
      tagNames: {
        ..._selectedBestFor,
        ..._selectedAmenities,
        ..._selectedPayment,
      },
      sort: _selectedSortId,
      query: prev.query,
      lat: prev.lat,
      lng: prev.lng,
    );
    context.read<FilterCubit>().setFilter(next);
    context.read<MapBloc>().add(LoadMapDataEvent(filter: next));
    Navigator.of(context).pop();
  }

  void _clearAll(BuildContext context) {
    context.read<FilterCubit>().reset();
    context.read<MapBloc>().add(LoadMapDataEvent(filter: const CafeFilter()));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close, color: Colors.black, size: 24),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(kMapFilterSectionSortBy, style: MapFilterBottomSheet.sectionTitleStyle),
                  const Gap(12),
                  MapFilterSortGrid(
                    options: mapFilterSortOptions(),
                    selectedId: _selectedSortId,
                    onSelect: (id) => setState(() => _selectedSortId = id),
                  ),
                  const Gap(28),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE0E0E0),
                  ),
                  const Gap(28),
                  const Text(kMapFilterSectionBestFor, style: MapFilterBottomSheet.sectionTitleStyle),
                  const Gap(12),
                  MapFilterTagWrap(
                    labels: kMapFilterBestForLabels,
                    selected: _selectedBestFor,
                    onToggle: (label) => setState(() {
                      if (_selectedBestFor.contains(label)) {
                        _selectedBestFor.remove(label);
                      } else {
                        _selectedBestFor.add(label);
                      }
                    }),
                  ),
                  const Gap(28),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE0E0E0),
                  ),
                  const Gap(28),
                  const Text(kMapFilterSectionAmenities, style: MapFilterBottomSheet.sectionTitleStyle),
                  const Gap(12),
                  MapFilterTagWrap(
                    labels: kMapFilterAmenityLabels,
                    selected: _selectedAmenities,
                    onToggle: (label) => setState(() {
                      if (_selectedAmenities.contains(label)) {
                        _selectedAmenities.remove(label);
                      } else {
                        _selectedAmenities.add(label);
                      }
                    }),
                  ),
                  const Gap(28),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE0E0E0),
                  ),
                  const Gap(28),
                  const Text(
                    kMapFilterSectionPaymentAccepted,
                    style: MapFilterBottomSheet.sectionTitleStyle,
                  ),
                  const Gap(12),
                  MapFilterTagWrap(
                    labels: kMapFilterPaymentLabels,
                    selected: _selectedPayment,
                    onToggle: (label) => setState(() {
                      if (_selectedPayment.contains(label)) {
                        _selectedPayment.remove(label);
                      } else {
                        _selectedPayment.add(label);
                      }
                    }),
                  ),
                  const Gap(28),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _clearAll(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _apply(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF344E41),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
}

/// Same structure and styling as [_BestForTag] in [cafe_info.dart].
class MapFilterTagChip extends StatelessWidget {
  const MapFilterTagChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  static const Color _border = Color(0xFF868584);
  static const Color _selectedBg = Color(0xFF344E41);

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? _selectedBg : _border;
    final contentColor = selected ? Colors.white : _border;

    final chip = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected ? _selectedBg : Colors.transparent,
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: contentColor),
            const Gap(4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: contentColor,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: chip,
      ),
    );
  }
}

class MapFilterTagWrap extends StatelessWidget {
  const MapFilterTagWrap({
    required this.labels,
    required this.selected,
    required this.onToggle,
  });

  final List<String> labels;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: labels
          .map(
            (label) => MapFilterTagChip(
              label: label,
              icon: resolveTagIcon(label),
              selected: selected.contains(label),
              onTap: () => onToggle(label),
            ),
          )
          .toList(),
    );
  }
}

class MapFilterSortGrid extends StatelessWidget {
  const MapFilterSortGrid({
    required this.options,
    required this.selectedId,
    required this.onSelect,
  });

  final List<({String id, String label, IconData icon})> options;
  final String selectedId;
  final ValueChanged<String> onSelect;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = (constraints.maxWidth - _gap) / 2;
        const cellH = 80.0;
        final o = options;
        return Column(
          children: [
            Row(
              children: [
                MapFilterSortSquareCard(
                  width: cellW,
                  height: cellH,
                  icon: o[0].icon,
                  label: o[0].label,
                  selected: selectedId == o[0].id,
                  onTap: () => onSelect(o[0].id),
                ),
                const SizedBox(width: _gap),
                MapFilterSortSquareCard(
                  width: cellW,
                  height: cellH,
                  icon: o[1].icon,
                  label: o[1].label,
                  selected: selectedId == o[1].id,
                  onTap: () => onSelect(o[1].id),
                ),
              ],
            ),
            const SizedBox(height: _gap),
            Row(
              children: [
                MapFilterSortSquareCard(
                  width: cellW,
                  height: cellH,
                  icon: o[2].icon,
                  label: o[2].label,
                  selected: selectedId == o[2].id,
                  onTap: () => onSelect(o[2].id),
                ),
                const SizedBox(width: _gap),
                MapFilterSortSquareCard(
                  width: cellW,
                  height: cellH,
                  icon: o[3].icon,
                  label: o[3].label,
                  selected: selectedId == o[3].id,
                  onTap: () => onSelect(o[3].id),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Outlined “skeleton” square card for sort options.
class MapFilterSortSquareCard extends StatelessWidget {
  const MapFilterSortSquareCard({
    required this.width,
    required this.height,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final double height;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _outline = Color(0xFFE0E0E0);
  static const Color _selectedBorder = Color(0xFF344E41);
  static const Color _selectedBg = Color(0x14344E41);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? _selectedBg : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _selectedBorder : _outline,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? _selectedBorder : const Color(0xFF6B6B6B),
                  ),
                  const Gap(6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: selected ? _selectedBorder : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
