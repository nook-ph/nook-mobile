import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_states.dart';
import 'package:nook/features/search/presentation/widgets/search_empty_view.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(height: 600, child: child)),
);

void main() {
  testWidgets('the map says Nook is Cebu-only and offers the city ask', (
    tester,
  ) async {
    var asked = 0;
    await tester.pumpWidget(
      _host(MapSheetStateView.outsideCebu(onRequestCity: () => asked++)),
    );

    expect(find.text(MapSheetStateView.outsideCebuTitle), findsOneWidget);
    expect(find.text(MapSheetStateView.outsideCebuSubtitle), findsOneWidget);
    await tester.tap(find.text(MapSheetStateView.requestCityLabel));
    expect(asked, 1);
  });

  testWidgets('search swaps its copy only when outside Cebu', (tester) async {
    await tester.pumpWidget(
      _host(const SearchEmptyView(line: 'Nothing for "latte" near IT Park.')),
    );
    expect(find.text('No cafes found'), findsOneWidget);
    expect(find.text(SearchEmptyView.requestCityLabel), findsNothing);

    var asked = 0;
    await tester.pumpWidget(
      _host(SearchEmptyView(line: 'x', onRequestCity: () => asked++)),
    );
    expect(find.text(SearchEmptyView.outsideCebuTitle), findsOneWidget);
    await tester.tap(find.text(SearchEmptyView.requestCityLabel));
    expect(asked, 1);
  });
}
