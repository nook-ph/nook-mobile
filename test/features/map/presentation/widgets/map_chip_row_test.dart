import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';

void main() {
  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('chip row spans the screen at ${width}pt, text x$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              home: BlocProvider(
                create: (_) => FilterCubit(),
                child: const Scaffold(
                  body: BottomModalSheet(cafes: [], tags: []),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);

        final scroll = find
            .ancestor(
              of: find.text('Nearby'),
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        final box = tester.getRect(scroll);
        // Edge to edge: the row is as wide as the screen.
        expect(box.left, 0);
        expect(box.right, width);

        // At the end of the scroll the last chip sits 20pt from the edge.
        await tester.drag(scroll, const Offset(-2000, 0));
        await tester.pumpAndSettle();
        final payment = tester.getRect(
          find
              .ancestor(
                of: find.text('Payment'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(width - payment.right, closeTo(20, 0.5));
        expect(payment.height, 34);
      });
    }
  }
}
