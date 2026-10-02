import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/debounced_count.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_content.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_ui.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// One section of the map filter, opened from a quick filter chip.
enum MapFilterSubSection { sort, bestFor, amenities, payment }

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
      MapFilterSubSection.bestFor => kMapFilterSectionBestFor,
      MapFilterSubSection.amenities => kMapFilterSectionAmenities,
      MapFilterSubSection.payment => kMapFilterSectionPaymentAccepted,
    };
  }

  static Future<void> show(BuildContext context, MapFilterSubSection section) {
    final mapBloc = context.read<MapBloc>();
    final initial = context.read<FilterCubit>().state;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider<MapBloc>.value(
        value: mapBloc,
        child: MapFilterSubSheet(section: section, initialFilter: initial),
      ),
    );
  }

  @override
  State<MapFilterSubSheet> createState() => _MapFilterSubSheetState();
}

class _MapFilterSubSheetState extends State<MapFilterSubSheet> {
  late final Set<String> _selected;
  final _count = DebouncedCount();

  List<String> get _pool => switch (widget.section) {
    MapFilterSubSection.bestFor => kMapFilterBestForLabels,
    MapFilterSubSection.amenities => kMapFilterAmenityLabels,
    MapFilterSubSection.payment => kMapFilterPaymentLabels,
    MapFilterSubSection.sort => const [],
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.initialFilter.tagNames.intersection(_pool.toSet());
    if (widget.section != MapFilterSubSection.sort) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recount());
    }
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  /// Counts what Apply would show: the filter in force with this group's
  /// tags swapped for the ones picked here.
  void _recount() {
    if (!mounted) return;
    final bloc = context.read<MapBloc>();
    final prev = context.read<FilterCubit>().state;
    final draft = prev.copyWith(
      tagNames: mergeTagsReplacingCategory(prev.tagNames, _pool.toSet(), {
        ..._selected,
      }),
    );
    _count.request(() => bloc.countFor(draft));
  }

  void _commit(BuildContext context, CafeFilter next) {
    context.read<FilterCubit>().setFilter(next);
    context.read<MapBloc>().add(LoadMapDataEvent(filter: next));
  }

  /// Sort applies the moment a row is tapped, then closes.
  void _pickSort(BuildContext context, String id) {
    final prev = context.read<FilterCubit>().state;
    if (prev.sort != id) _commit(context, prev.copyWith(sort: id));
    Navigator.of(context).pop();
  }

  void _apply(BuildContext context) {
    final prev = context.read<FilterCubit>().state;
    _commit(
      context,
      prev.copyWith(
        tagNames: mergeTagsReplacingCategory(
          prev.tagNames,
          _pool.toSet(),
          _selected,
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  /// Clears this group straight away and keeps the sheet open.
  void _clear(BuildContext context) {
    final prev = context.read<FilterCubit>().state;
    setState(_selected.clear);
    _commit(
      context,
      prev.copyWith(
        tagNames: mergeTagsReplacingCategory(prev.tagNames, _pool.toSet(), {}),
      ),
    );
    _recount();
  }

  @override
  Widget build(BuildContext context) {
    final title = MapFilterSubSheet.titleFor(widget.section);

    if (widget.section == MapFilterSubSection.sort) {
      final current = widget.initialFilter.sort;
      return MapFilterSheetFrame(
        title: title,
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            MapTokens.gutter,
            0,
            MapTokens.gutter,
            MediaQuery.viewPaddingOf(context).bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in mapFilterSortOptions())
                _SortRow(
                  label: option.label,
                  selected: option.id == current,
                  onTap: () => _pickSort(context, option.id),
                ),
            ],
          ),
        ),
      );
    }

    return MapFilterSheetFrame(
      title: title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          MapTokens.gutter,
          0,
          MapTokens.gutter,
          16,
        ),
        child: MapFilterChipWrap(
          labels: _pool,
          isSelected: _selected.contains,
          onTap: (label) {
            setState(() {
              if (!_selected.remove(label)) _selected.add(label);
            });
            _recount();
          },
        ),
      ),
      footer: MapFilterFooter(
        onClear: () => _clear(context),
        onApply: () => _apply(context),
        count: _count.value,
      ),
    );
  }
}

/// A sort option: the label, and a tick when it is the current sort.
class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AdaptiveTap(
        onTap: onTap,
        child: SizedBox(
          height: 47,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    color: MapTokens.ink,
                  ),
                ),
              ),
              if (selected)
                const Icon(LucideIcons.check, size: 18, color: MapTokens.brand),
            ],
          ),
        ),
      ),
    );
  }
}
