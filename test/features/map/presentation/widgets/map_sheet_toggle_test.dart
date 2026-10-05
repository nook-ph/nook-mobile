import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_toggle.dart';

/// The map page's wiring in miniature: the toggle drives one animation that
/// slides the real sheet away and back.
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
  bool _hidden = false;

  @override
  void dispose() {
    _hide.dispose();
    _metrics.dispose();
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
          child: ValueListenableBuilder<BottomSheetMetrics?>(
            valueListenable: _metrics,
            builder: (context, m, sheet) => MapSheetSlide(
              hidden: _hide,
              sheetTop: m?.topFromBottom,
              child: sheet!,
            ),
            child: BottomModalSheet(
              cafes: widget.cafes,
              tags: const [],
              onMetricsChanged: (m) => WidgetsBinding.instance
                  .addPostFrameCallback((_) => _metrics.value = m),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: MapListToggleButton(
            listHidden: _hidden,
            onTap: () {
              setState(() => _hidden = !_hidden);
              _hidden ? _hide.forward() : _hide.reverse();
            },
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('the toggle slides the cafe sheet away and brings it back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    final cafes = [
      for (var i = 0; i < 3; i++)
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
    await tester.pump(const Duration(milliseconds: 500));

    final count = find.text('3 cafes in view');
    final toggle = find.byKey(const ValueKey('map-list-toggle'));
    final restingTop = tester.getRect(count).top;

    expect(count.hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('Hide list'), findsOneWidget);
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));

    // Hide: the sheet leaves the screen and takes no touches.
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getRect(count).top, greaterThanOrEqualTo(844));
    expect(count.hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Show list'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide list'), findsNothing);

    // Show: it comes back where it was.
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getRect(count).top, closeTo(restingTop, 0.5));
    expect(count.hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('Hide list'), findsOneWidget);

    semantics.dispose();
  });
}
