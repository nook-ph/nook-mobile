import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_cafe_card.dart';

void main() {
  testWidgets('scrolled rows stay clear of the cafe count', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final cafes = [
      for (var i = 0; i < 12; i++)
        CafeSummary(
          id: 'c$i',
          name: 'Cafe $i',
          address: 'Lahug, Cebu City',
          rating: 4.5,
          tags: const ['Wifi', 'Outlets'],
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => FilterCubit(),
          child: Scaffold(
            body: BottomModalSheet(cafes: cafes, tags: const []),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final count = tester.getRect(find.text('12 cafes in view'));
    final list = find.byType(ListView);
    final viewport = tester.getRect(list);

    // At rest: 24 from the count to the first photo (Figma).
    final firstRow = tester.getRect(find.byType(MapSheetCafeCard).first);
    expect(firstRow.top - count.bottom, closeTo(24, 0.5));

    // The list itself starts below the count, so nothing can reach the label.
    expect(viewport.top - count.bottom, greaterThanOrEqualTo(12));

    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));

    for (final element in find.byType(MapSheetCafeCard).evaluate()) {
      final box = element.renderObject! as RenderBox;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      // A row may be partly scrolled off, but whatever shows is clipped to
      // the viewport, which starts 12 below the count.
      if (bottom > viewport.top) {
        expect(viewport.top - count.bottom, greaterThanOrEqualTo(12));
      }
    }
    expect(tester.takeException(), isNull);
  });
}
