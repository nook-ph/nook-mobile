import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_toggle.dart';

/// The map page's wiring in miniature: the button slides the real sheet
/// away, or brings it up to the full list.
class _Harness extends StatefulWidget {
  const _Harness({required this.cafes});

  final List<CafeSummary> cafes;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  late final _hide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  final _metrics = ValueNotifier<BottomSheetMetrics?>(null);
  final _commands = MapSheetCommands();
  bool _hidden = false;

  bool get _listOpen => !_hidden && (_metrics.value?.isExpanded ?? false);

  void _toggle() {
    if (_listOpen) {
      setState(() => _hidden = true);
      _hide.forward();
      return;
    }
    _commands.expand();
    if (_hidden) {
      setState(() => _hidden = false);
      _hide.reverse();
    }
  }

  @override
  void dispose() {
    _hide.dispose();
    _metrics.dispose();
    _commands.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          bottom: 0,
          child: MapSheetSlide(
            hidden: _hide,
            child: BottomModalSheet(
              cafes: widget.cafes,
              tags: const [],
              commands: _commands,
              onMetricsChanged: (m) => WidgetsBinding.instance
                  .addPostFrameCallback((_) => _metrics.value = m),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: ValueListenableBuilder<BottomSheetMetrics?>(
            valueListenable: _metrics,
            builder: (context, _, _) =>
                MapListToggleButton(listOpen: _listOpen, onTap: _toggle),
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('the button switches between the map and the full list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    final cafes = [
      for (var i = 0; i < 12; i++)
        CafeSummary(
          id: 'c$i',
          name: 'Cafe $i',
          address: 'Lahug, Cebu City',
          rating: 4.5,
          tags: const [],
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => FilterCubit(),
          child: Scaffold(body: _Harness(cafes: cafes)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final count = find.text('12 cafes in view');
    final toggle = find.byKey(const ValueKey('map-list-toggle'));
    final openTop = tester.getRect(count).top;

    // Opens on the full list.
    expect(count.hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('Hide list'), findsOneWidget);
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));

    // Full list -> map: the sheet leaves the screen and takes no touches.
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getRect(count).top, greaterThanOrEqualTo(844));
    expect(count.hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Show list'), findsOneWidget);

    // Map -> full list.
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getRect(count).top, closeTo(openTop, 0.5));
    expect(find.bySemanticsLabel('Hide list'), findsOneWidget);

    // Dragged down to the chips, the list counts as closed.
    await tester.fling(count, const Offset(0, 500), 2000);
    await tester.pumpAndSettle();
    final collapsedTop = tester.getRect(count).top;
    expect(collapsedTop, greaterThan(openTop + 200));
    expect(find.bySemanticsLabel('Show list'), findsOneWidget);

    // Collapsed -> full list, not hidden.
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getRect(count).top, closeTo(openTop, 0.5));
    expect(find.bySemanticsLabel('Hide list'), findsOneWidget);

    // The opened list scrolls instead of dragging the sheet.
    final row = find.text('Cafe 3');
    final rowTop = tester.getRect(row).top;
    await tester.drag(row, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getRect(count).top, closeTo(openTop, 0.5));
    expect(tester.getRect(row).top, lessThan(rowTop - 50));

    semantics.dispose();
  });
}
