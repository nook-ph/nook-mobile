import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/debounced_count.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_content.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_ui.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// Every map filter in one sheet: sort, Best for, Amenities and Payment.
/// Choices are held here and applied together by the footer button.
class MapFilterBottomSheet extends StatefulWidget {
  const MapFilterBottomSheet({super.key, required this.initialFilter});

  final CafeFilter initialFilter;

  static Future<void> show(BuildContext context) {
    final mapBloc = context.read<MapBloc>();
    final initial = context.read<FilterCubit>().state;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
  late final Set<String> _selectedTags;
  final _count = DebouncedCount();

  @override
  void initState() {
    super.initState();
    _selectedSortId = widget.initialFilter.sort;
    final known = {
      ...kMapFilterBestForLabels,
      ...kMapFilterAmenityLabels,
      ...kMapFilterPaymentLabels,
    };
    _selectedTags = widget.initialFilter.tagNames.intersection(known);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recount());
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  /// What Apply would commit.
  CafeFilter _draft() {
    final prev = widget.initialFilter;
    return CafeFilter(
      tagNames: {..._selectedTags},
      sort: _selectedSortId,
      query: prev.query,
      lat: prev.lat,
      lng: prev.lng,
    );
  }

  void _recount() {
    if (!mounted) return;
    final bloc = context.read<MapBloc>();
    final draft = _draft();
    _count.request(() => bloc.countFor(draft));
  }

  void _toggle(String label) {
    setState(() {
      if (!_selectedTags.remove(label)) _selectedTags.add(label);
    });
    _recount();
  }

  void _apply(BuildContext context) {
    final next = _draft();
    context.read<FilterCubit>().setFilter(next);
    context.read<MapBloc>().add(LoadMapDataEvent(filter: next));
    Navigator.of(context).pop();
  }

  void _clearAll(BuildContext context) {
    context.read<FilterCubit>().reset();
    context.read<MapBloc>().add(LoadMapDataEvent(filter: const CafeFilter()));
    Navigator.of(context).pop();
  }

  Widget _tagSection(String title, List<String> labels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MapFilterSectionTitle(title),
        const SizedBox(height: 10),
        MapFilterChipWrap(
          labels: labels,
          isSelected: _selectedTags.contains,
          onTap: _toggle,
        ),
      ],
    );
  }

  static const _divider = Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(height: 1, thickness: 1, color: MapTokens.border),
  );

  @override
  Widget build(BuildContext context) {
    final sorts = mapFilterSortOptions();
    return MapFilterSheetFrame(
      title: 'Filters',
      // Near full height, as drawn: the map shows only as a strip above it.
      height: MediaQuery.sizeOf(context).height * 0.92,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          MapTokens.gutter,
          4,
          MapTokens.gutter,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MapFilterSectionTitle(kMapFilterSectionSortBy),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in sorts)
                  MapFilterChoiceChip(
                    label: option.label,
                    selected: option.id == _selectedSortId,
                    onTap: () {
                      setState(() => _selectedSortId = option.id);
                      _recount();
                    },
                  ),
              ],
            ),
            _divider,
            _tagSection(kMapFilterSectionBestFor, kMapFilterBestForLabels),
            _divider,
            _tagSection(kMapFilterSectionAmenities, kMapFilterAmenityLabels),
            _divider,
            _tagSection(
              kMapFilterSectionPaymentAccepted,
              kMapFilterPaymentLabels,
            ),
          ],
        ),
      ),
      footer: MapFilterFooter(
        onClear: () => _clearAll(context),
        onApply: () => _apply(context),
        count: _count.value,
      ),
    );
  }
}
