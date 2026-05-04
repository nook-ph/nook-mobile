import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_bottom_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_content.dart';

/// One section of the map filter, opened from a quick filter chip.
enum MapFilterSubSection {
  sort,
  bestFor,
  amenities,
  payment,
}

class MapFilterSubSheet extends StatefulWidget {
  const MapFilterSubSheet({
    super.key,
    required this.section,
    required this.initialFilter,
  });

  final MapFilterSubSection section;
  final CafeFilter initialFilter;

  static String titleFor(MapFilterSubSection section) {
    return switch (section) {
      MapFilterSubSection.sort => 'Sort',
      MapFilterSubSection.bestFor => 'Best for',
      MapFilterSubSection.amenities => 'Amenities',
      MapFilterSubSection.payment => 'Payment Option',
    };
  }

  static Future<void> show(BuildContext context, MapFilterSubSection section) {
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
        child: MapFilterSubSheet(
          section: section,
          initialFilter: initial,
        ),
      ),
    );
  }

  @override
  State<MapFilterSubSheet> createState() => _MapFilterSubSheetState();
}

class _MapFilterSubSheetState extends State<MapFilterSubSheet> {
  late String _selectedSortId;
  final Set<String> _selectedBestFor = <String>{};
  final Set<String> _selectedAmenities = <String>{};
  final Set<String> _selectedPayment = <String>{};

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
    late final CafeFilter next;
    switch (widget.section) {
      case MapFilterSubSection.sort:
        next = prev.copyWith(sort: _selectedSortId);
      case MapFilterSubSection.bestFor:
        next = prev.copyWith(
          tagNames: mergeTagsReplacingCategory(
            prev.tagNames,
            kMapFilterBestForLabels.toSet(),
            _selectedBestFor,
          ),
        );
      case MapFilterSubSection.amenities:
        next = prev.copyWith(
          tagNames: mergeTagsReplacingCategory(
            prev.tagNames,
            kMapFilterAmenityLabels.toSet(),
            _selectedAmenities,
          ),
        );
      case MapFilterSubSection.payment:
        next = prev.copyWith(
          tagNames: mergeTagsReplacingCategory(
            prev.tagNames,
            kMapFilterPaymentLabels.toSet(),
            _selectedPayment,
          ),
        );
    }
    context.read<FilterCubit>().setFilter(next);
    context.read<MapBloc>().add(LoadMapDataEvent(filter: next));
    Navigator.of(context).pop();
  }

  void _clearForSection(BuildContext context) {
    final prev = context.read<FilterCubit>().state;
    late final CafeFilter next;
    switch (widget.section) {
      case MapFilterSubSection.sort:
        next = prev.copyWith(sort: 'nearby');
        setState(() => _selectedSortId = 'nearby');
      case MapFilterSubSection.bestFor:
        next = prev.copyWith(
          tagNames: mergeTagsReplacingCategory(
            prev.tagNames,
            kMapFilterBestForLabels.toSet(),
            {},
          ),
        );
        setState(() => _selectedBestFor.clear());
      case MapFilterSubSection.amenities:
        next = prev.copyWith(
          tagNames: mergeTagsReplacingCategory(
            prev.tagNames,
            kMapFilterAmenityLabels.toSet(),
            {},
          ),
        );
        setState(() => _selectedAmenities.clear());
      case MapFilterSubSection.payment:
        next = prev.copyWith(
          tagNames: mergeTagsReplacingCategory(
            prev.tagNames,
            kMapFilterPaymentLabels.toSet(),
            {},
          ),
        );
        setState(() => _selectedPayment.clear());
    }
    context.read<FilterCubit>().setFilter(next);
    context.read<MapBloc>().add(LoadMapDataEvent(filter: next));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final title = MapFilterSubSheet.titleFor(widget.section);
    final maxScrollBody = (media.size.height * 0.55).clamp(160.0, 520.0);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
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
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxScrollBody),
            child: ListView(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              children: [
                _buildSectionContent(),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _clearForSection(context),
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

  Widget _buildSectionContent() {
    switch (widget.section) {
      case MapFilterSubSection.sort:
        return MapFilterSortGrid(
          options: mapFilterSortOptions(),
          selectedId: _selectedSortId,
          onSelect: (id) => setState(() => _selectedSortId = id),
        );
      case MapFilterSubSection.bestFor:
        return MapFilterTagWrap(
          labels: kMapFilterBestForLabels,
          selected: _selectedBestFor,
          onToggle: (label) => setState(() {
            if (_selectedBestFor.contains(label)) {
              _selectedBestFor.remove(label);
            } else {
              _selectedBestFor.add(label);
            }
          }),
        );
      case MapFilterSubSection.amenities:
        return MapFilterTagWrap(
          labels: kMapFilterAmenityLabels,
          selected: _selectedAmenities,
          onToggle: (label) => setState(() {
            if (_selectedAmenities.contains(label)) {
              _selectedAmenities.remove(label);
            } else {
              _selectedAmenities.add(label);
            }
          }),
        );
      case MapFilterSubSection.payment:
        return MapFilterTagWrap(
          labels: kMapFilterPaymentLabels,
          selected: _selectedPayment,
          onToggle: (label) => setState(() {
            if (_selectedPayment.contains(label)) {
              _selectedPayment.remove(label);
            } else {
              _selectedPayment.add(label);
            }
          }),
        );
    }
  }
}
