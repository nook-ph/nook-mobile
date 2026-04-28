import 'package:flutter/material.dart';
import 'package:sliding_panel_kit/sliding_panel_kit.dart';
import 'package:nook/features/map/presentation/widgets/cafe_card.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class BottomModalSheet extends StatefulWidget {
  final List<CafeSummary> cafes;
  final List<CafeTagsEntity> tags;

  BottomModalSheet({super.key, required this.cafes, required this.tags});

  @override
  State<BottomModalSheet> createState() => _BottomModalSheetState();
}

class _BottomModalSheetState extends State<BottomModalSheet> {
  final controller = SlidingPanelController();
  final ScrollController _tagScrollController = ScrollController();
  final Set<String> _selectedTags = {};
  late List<CafeTagsEntity> _orderedTags;
  String? _lastSelectedTag;

  @override
  void initState() {
    super.initState();
    _orderedTags = List.from(widget.tags);
  }

  @override
  void dispose() {
    controller.dispose();
    _tagScrollController.dispose();
    super.dispose();
  }

  List<CafeSummary> get _filteredCafes {
    if (_selectedTags.isEmpty) return widget.cafes;
    return widget.cafes.where((cafe) {
      return cafe.tags.any((tag) => _selectedTags.contains(tag));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SlidingPanelBuilder(
      controller: controller,
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _tagScrollController,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _orderedTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag.name);
                      final shouldAnimate = _lastSelectedTag == tag.name;
                      final chip = FilterChip(
                        key: ValueKey(tag.name),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        label: Text(tag.name),
                        backgroundColor: colors.surface,
                        selectedColor: colors.primary60,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : colors.primary100,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        side: BorderSide(
                          color: isSelected ? colors.primary100 : colors.border,
                          width: 1.5,
                        ),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            _lastSelectedTag = tag.name;
                            if (val) {
                              _selectedTags.add(tag.name);
                              _orderedTags.remove(tag);
                              _orderedTags.insert(0, tag);
                            } else {
                              _selectedTags.remove(tag.name);
                            }
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _tagScrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          });
                        },
                      );

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: shouldAnimate
                            ? chip
                                  .animate(key: ValueKey('${tag.name}_anim'))
                                  .scale(
                                    begin: const Offset(0.8, 0.8),
                                    end: const Offset(1.0, 1.0),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutBack,
                                  )
                                  .fadeIn(
                                    duration: const Duration(milliseconds: 200),
                                  )
                            : chip,
                      );
                    }).toList(),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  itemCount: _filteredCafes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 24),
                  itemBuilder: (BuildContext context, int index) {
                    return CafeCard(cafe: _filteredCafes[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
