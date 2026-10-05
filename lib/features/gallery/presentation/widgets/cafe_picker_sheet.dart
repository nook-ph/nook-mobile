import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// How many rows each suggestion section shows. Search covers the rest;
/// four sections of long lists would be too many choices (finding 6).
const cafePickerSectionLimit = 6;

/// Opens "Which cafe?" and returns the chosen cafe, or null when dismissed.
/// [takenHere] is the cafe the photo's EXIF position matched, if any.
Future<PickedCafe?> showCafePickerSheet(
  BuildContext context, {
  required ICafePickerSource source,
  Future<CafeSummary?>? takenHere,
  int photoCount = 1,
}) {
  return ListsSheet.show<PickedCafe>(
    context,
    builder: (_) => CafePickerSheet(
      source: source,
      takenHere: takenHere,
      photoCount: photoCount,
    ),
  );
}

/// The picker: a search field, then one "Taken here?" suggestion, then the
/// person's Been cafes, then Nearby. Typing replaces the sections with
/// results (Gowalla's rows, Google Maps' section labels, Shazam's search
/// field; docs/references/coffee-gallery).
class CafePickerSheet extends StatefulWidget {
  const CafePickerSheet({
    super.key,
    required this.source,
    this.takenHere,
    this.photoCount = 1,
    this.searchDelay = const Duration(milliseconds: 300),
  });

  final ICafePickerSource source;
  final Future<CafeSummary?>? takenHere;
  final int photoCount;
  final Duration searchDelay;

  @override
  State<CafePickerSheet> createState() => _CafePickerSheetState();
}

class _CafePickerSheetState extends State<CafePickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;

  CafeSummary? _takenHere;
  List<CafeSummary>? _been;
  List<CafeSummary>? _nearby;
  bool _nearbyLoaded = false;
  bool _locating = false;

  String _query = '';
  List<CafeSummary>? _results;
  bool _searchFailed = false;
  int _searchSerial = 0;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final takenHere = widget.takenHere;
    if (takenHere != null) {
      takenHere
          .then((cafe) {
            if (mounted) setState(() => _takenHere = cafe);
          })
          .catchError((Object _) {});
    }
    widget.source
        .beenCafes()
        .then((cafes) {
          if (mounted) setState(() => _been = cafes);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _been = const []);
        });
    _loadNearby();
  }

  Future<void> _loadNearby({bool ask = false}) async {
    if (ask) setState(() => _locating = true);
    List<CafeSummary>? cafes;
    try {
      cafes = await widget.source.nearby(ask: ask);
    } catch (_) {
      cafes = const [];
    }
    if (!mounted) return;
    setState(() {
      _nearby = cafes;
      _nearbyLoaded = true;
      _locating = false;
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() {
      _query = query;
      if (query.isEmpty) {
        _results = null;
        _searchFailed = false;
      }
    });
    if (query.isEmpty) return;
    _debounce = Timer(widget.searchDelay, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final serial = ++_searchSerial;
    try {
      final results = await widget.source.search(query);
      if (!mounted || serial != _searchSerial) return;
      setState(() {
        _results = results;
        _searchFailed = false;
      });
    } catch (_) {
      if (!mounted || serial != _searchSerial) return;
      setState(() {
        _results = const [];
        _searchFailed = true;
      });
    }
  }

  void _pick(CafeSummary cafe) =>
      Navigator.of(context).pop(PickedCafe.fromSummary(cafe));

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListsSheet(
        title: widget.photoCount > 1
            ? 'Which cafe are these from?'
            : 'Which cafe is this from?',
        gap: 12,
        children: [
          _SearchField(controller: _search, onChanged: _onQueryChanged),
          ..._query.isEmpty ? _sections() : _searchResults(),
        ],
      ),
    );
  }

  List<Widget> _searchResults() {
    final results = _results;
    if (results == null) return const [_RowsSkeleton(count: 3)];
    if (_searchFailed) {
      return [
        _Note(
          "Couldn't search right now. Check your connection and try again.",
        ),
      ];
    }
    if (results.isEmpty) {
      return [_Note('No cafes match "$_query". Try its name or the area.')];
    }
    return [for (final cafe in results) _CafeRow(cafe: cafe, onTap: _pick)];
  }

  List<Widget> _sections() {
    final been = _been;
    final nearby = _nearby;
    final suggestion = _takenHere;
    final beenIds = {...?been?.map((c) => c.id), ?suggestion?.id};
    final nearbyRows = nearby
        ?.where((c) => !beenIds.contains(c.id))
        .take(cafePickerSectionLimit)
        .toList();

    return [
      if (suggestion != null) ...[
        const _SectionLabel('Taken here?'),
        _CafeRow(cafe: suggestion, onTap: _pick, highlighted: true),
      ],
      const _SectionLabel('Your Been cafes'),
      if (been == null)
        const _RowsSkeleton(count: 3)
      else if (been.isEmpty)
        _Note('Cafes you mark as Been show up here.')
      else
        for (final cafe
            in been
                .where((c) => c.id != suggestion?.id)
                .take(cafePickerSectionLimit))
          _CafeRow(cafe: cafe, onTap: _pick),
      const _SectionLabel('Nearby'),
      if (!_nearbyLoaded)
        const _RowsSkeleton(count: 2)
      else if (nearby == null)
        _UseLocation(busy: _locating, onTap: () => _loadNearby(ask: true))
      else if (nearbyRows!.isEmpty)
        _Note('No other cafes close by. Search for the one you want.')
      else
        for (final cafe in nearbyRows) _CafeRow(cafe: cafe, onTap: _pick),
    ];
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(100),
      borderSide: BorderSide.none,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: listsText(16),
        decoration: InputDecoration(
          hintText: 'Search cafes',
          hintStyle: listsText(16, color: ListsTokens.muted),
          filled: true,
          fillColor: ListsTokens.tint,
          prefixIcon: const Icon(
            LucideIcons.search,
            size: 20,
            color: ListsTokens.muted,
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(
                    LucideIcons.x,
                    size: 18,
                    color: ListsTokens.muted,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: listsText(
            12,
            weight: FontWeight.w600,
            color: ListsTokens.muted,
          ),
        ),
      ),
    );
  }
}

class _CafeRow extends StatelessWidget {
  const _CafeRow({
    required this.cafe,
    required this.onTap,
    this.highlighted = false,
  });

  final CafeSummary cafe;
  final ValueChanged<CafeSummary> onTap;

  /// The EXIF suggestion: outlined, so it reads as the likely answer.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final area = cafe.locationLabel;
    return Semantics(
      button: true,
      label: area.isEmpty ? cafe.name : '${cafe.name}, $area',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: () => onTap(cafe),
        borderRadius: BorderRadius.circular(ListsTokens.radius),
        child: Container(
          padding: highlighted
              ? const EdgeInsets.all(10)
              : const EdgeInsets.symmetric(vertical: 2),
          decoration: highlighted
              ? BoxDecoration(
                  border: Border.all(color: ListsTokens.brand, width: 1.5),
                  borderRadius: BorderRadius.circular(ListsTokens.radius),
                )
              : null,
          child: Row(
            children: [
              ListsThumb(imageUrl: cafe.coverImage, size: 48, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: listsText(14, weight: FontWeight.w500),
                    ),
                    if (area.isNotEmpty)
                      Text(
                        area,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: listsText(12, color: ListsTokens.muted),
                      ),
                  ],
                ),
              ),
              if (highlighted)
                const Icon(
                  LucideIcons.check,
                  size: 18,
                  color: ListsTokens.brand,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UseLocation extends StatelessWidget {
  const _UseLocation({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ListsTokens.brand,
                    ),
                  )
                : const Icon(
                    LucideIcons.locate,
                    size: 18,
                    color: ListsTokens.brand,
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Use my location to see cafes near you',
                style: listsText(
                  14,
                  weight: FontWeight.w500,
                  color: ListsTokens.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: listsText(13, color: ListsTokens.muted));
}

class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: const Row(
              children: [
                ListsSkeleton(width: 48, height: 48, radius: 10),
                SizedBox(width: 12),
                Expanded(child: ListsSkeleton(height: 14)),
              ],
            ),
          ),
      ],
    );
  }
}
