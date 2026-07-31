import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/presentation/widgets/cafe_status_control.dart';

/// The bar has to keep both controls legible in every state: unranked (two
/// full labels) and ranked, where the Been pill grows a score and Want to Try
/// compresses. It previously compressed to a bare bookmark glyph — the same
/// icon as the unrelated save-to-list control in the header.
Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

CafeStatusControl control({
  CafeStatus status = CafeStatus.none,
  String? score,
  String? rankLabel,
}) => CafeStatusControl(
  status: status,
  score: score,
  rankLabel: rankLabel,
  onTapBeen: () {},
  onTapWantToTry: () {},
);

void main() {
  testWidgets('shows both full labels when the cafe is unranked', (
    tester,
  ) async {
    await tester.pumpWidget(host(control(status: CafeStatus.been)));

    expect(find.text('Been'), findsOneWidget);
    expect(find.text('Want to Try'), findsOneWidget);
  });

  testWidgets('merges the score into the Been pill once ranked', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        control(status: CafeStatus.been, score: '9.3', rankLabel: '#2 of 8'),
      ),
    );

    expect(find.textContaining('9.3'), findsOneWidget);
    expect(find.textContaining('#2 of 8'), findsOneWidget);
    expect(find.text('Been'), findsNothing);
  });

  testWidgets('keeps a word on Want to Try when the ranked bar compresses it', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        control(status: CafeStatus.been, score: '9.3', rankLabel: '#2 of 8'),
      ),
    );

    // Compressed, not stripped to an icon.
    expect(find.text('Try'), findsOneWidget);
    expect(find.text('Want to Try'), findsNothing);
  });

  testWidgets('speaks the full name even when the label is compressed', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        control(status: CafeStatus.been, score: '9.3', rankLabel: '#2 of 8'),
      ),
    );

    expect(
      find.bySemanticsLabel('Want to Try'),
      findsOneWidget,
      reason: 'the spoken name must not abbreviate with the visual label',
    );
    handle.dispose();
  });

  testWidgets('only the Been pill carries the score', (tester) async {
    // A want-to-try cafe has no ranking, so no score should surface at all.
    await tester.pumpWidget(
      host(control(status: CafeStatus.wantToTry, score: '9.3')),
    );

    expect(find.textContaining('9.3'), findsNothing);
    expect(find.text('Want to Try'), findsOneWidget);
  });
}
