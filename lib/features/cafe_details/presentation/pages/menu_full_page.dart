import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_category_section.dart';

/// Groups menu items by category, keeping the order categories first appear
/// in. Items without a category go under "Others".
Map<String, List<MenuItemEntity>> groupMenuByCategory(
  List<MenuItemEntity> items,
) {
  final map = <String, List<MenuItemEntity>>{};
  for (final item in items) {
    final name = item.categoryName?.trim() ?? '';
    map.putIfAbsent(name.isEmpty ? 'Others' : name, () => []).add(item);
  }
  return map;
}

/// The cafe's whole menu: category chips pinned under the title that jump to
/// a section, then every category with one line per item.
class MenuFullPage extends StatefulWidget {
  const MenuFullPage({super.key, required this.menuItems, this.cafeName});

  final List<MenuItemEntity> menuItems;
  final String? cafeName;

  @override
  State<MenuFullPage> createState() => _MenuFullPageState();
}

class _MenuFullPageState extends State<MenuFullPage> {
  late Map<String, List<MenuItemEntity>> _categories;
  late List<GlobalKey> _sectionKeys;
  final GlobalKey _bodyKey = GlobalKey();
  int _selected = 0;

  /// While a chip tap is scrolling the page, the scroll listener must not
  /// move the selection through every category on the way.
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _group();
  }

  @override
  void didUpdateWidget(covariant MenuFullPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuItems != widget.menuItems) _group();
  }

  void _group() {
    _categories = groupMenuByCategory(widget.menuItems);
    _sectionKeys = [for (final _ in _categories.keys) GlobalKey()];
    if (_selected >= _sectionKeys.length) _selected = 0;
  }

  Future<void> _jumpTo(int index) async {
    final target = _sectionKeys[index].currentContext;
    if (target == null) return;
    setState(() {
      _selected = index;
      _jumping = true;
    });
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (mounted) _jumping = false;
  }

  /// Selects the last category whose heading has reached the top of the list.
  bool _onScroll(ScrollNotification notification) {
    if (_jumping || notification.depth != 0) return false;
    final body = _bodyKey.currentContext?.findRenderObject();
    if (body is! RenderBox || !body.hasSize) return false;
    final top = body.localToGlobal(Offset.zero).dy;

    var current = 0;
    for (var i = 0; i < _sectionKeys.length; i++) {
      final box = _sectionKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      if (box.localToGlobal(Offset.zero).dy - top <= 24) current = i;
    }
    if (current != _selected) setState(() => _selected = current);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cafeName = widget.cafeName?.trim() ?? '';
    final names = _categories.keys.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: AdaptiveTap(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: CafeDetailsTokens.ink),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Menu',
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CafeDetailsTokens.ink,
              ),
            ),
            if (cafeName.isNotEmpty)
              Text(
                cafeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: CafeDetailsTokens.muted,
                ),
              ),
          ],
        ),
      ),
      body: names.isEmpty
          ? const _EmptyMenu()
          : Column(
              children: [
                // One category needs no jump bar.
                if (names.length > 1)
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(
                        CafeDetailsTokens.gutter,
                        4,
                        CafeDetailsTokens.gutter,
                        12,
                      ),
                      itemCount: names.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => _CategoryChip(
                        label: names[index],
                        selected: index == _selected,
                        onTap: () => _jumpTo(index),
                      ),
                    ),
                  ),
                const Divider(
                  color: CafeDetailsTokens.border,
                  thickness: 1,
                  height: 1,
                ),
                Expanded(
                  key: _bodyKey,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    // A Column, not a lazy list: every section must exist for
                    // a chip to scroll to it, and menus are short.
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        CafeDetailsTokens.gutter,
                        20,
                        CafeDetailsTokens.gutter,
                        24 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < names.length; i++) ...[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(
                                  color: CafeDetailsTokens.border,
                                  thickness: 1,
                                  height: 1,
                                ),
                              ),
                            MenuCategorySection(
                              key: _sectionKeys[i],
                              categoryName: names[i],
                              items: _categories[names[i]]!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? CafeDetailsTokens.brand : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? CafeDetailsTokens.brand
                  : CafeDetailsTokens.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : CafeDetailsTokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 0, 48, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No menu posted yet',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CafeDetailsTokens.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This cafe has not shared a menu. Check back later.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: CafeDetailsTokens.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
