import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_content.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_ui.dart';

void main() {
  test('a sub-sheet replaces only its own group of tags', () {
    final next = mergeTagsReplacingCategory(
      {'Free WiFi', 'Cash', 'Date Spot'},
      kMapFilterPaymentLabels.toSet(),
      {'Card'},
    );
    expect(next, {'Free WiFi', 'Date Spot', 'Card'});
  });

  test('section titles are sentence case', () {
    expect(kMapFilterSectionSortBy, 'Sort by');
    expect(kMapFilterSectionPaymentAccepted, 'Payment accepted');
  });

  testWidgets('sheet frame shows title, chips and footer at 360pt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final selected = <String>{'Free WiFi'};
    var applied = false;
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (context, setState) => MapFilterSheetFrame(
                title: kMapFilterSectionAmenities,
                body: SingleChildScrollView(
                  child: MapFilterChipWrap(
                    labels: kMapFilterAmenityLabels,
                    isSelected: selected.contains,
                    onTap: (l) => setState(() {
                      if (!selected.remove(l)) selected.add(l);
                    }),
                  ),
                ),
                footer: MapFilterFooter(
                  onClear: () => cleared = true,
                  onApply: () => applied = true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Amenities'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Power Outlets'));
    await tester.pump();
    expect(selected, {'Free WiFi', 'Power Outlets'});

    await tester.tap(find.text('Apply'));
    await tester.tap(find.text('Clear all'));
    expect(applied, isTrue);
    expect(cleared, isTrue);
  });

  testWidgets('chips hug their label instead of filling the row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MapFilterChoiceChip(
                  label: 'Nearby',
                  selected: true,
                  onTap: () {},
                ),
                MapFilterChoiceChip(
                  label: 'Top rated',
                  selected: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final nearby = tester.getRect(find.byType(MapFilterChoiceChip).first);
    final topRated = tester.getRect(find.byType(MapFilterChoiceChip).last);
    expect(nearby.width, lessThan(150));
    expect(nearby.height, 34);
    // Both fit on one line.
    expect(topRated.top, nearby.top);
  });

  testWidgets('footer says Apply until a count arrives, then Show N cafes', (
    tester,
  ) async {
    final count = ValueNotifier<int?>(null);
    addTearDown(count.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapFilterFooter(onClear: () {}, onApply: () {}, count: count),
        ),
      ),
    );
    expect(find.text('Apply'), findsOneWidget);

    count.value = 54;
    await tester.pump();
    expect(find.text('Show 54 cafes'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);

    count.value = 1;
    await tester.pump();
    expect(find.text('Show 1 cafe'), findsOneWidget);

    // Counting again (or a failed count) goes back to Apply.
    count.value = null;
    await tester.pump();
    expect(find.text('Apply'), findsOneWidget);

    final pill = tester.getSize(
      find
          .ancestor(of: find.text('Apply'), matching: find.byType(Container))
          .first,
    );
    expect(pill.height, 48);
  });
}
