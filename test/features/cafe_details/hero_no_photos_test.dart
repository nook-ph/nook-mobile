import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/cafe_photo_placeholder.dart';
import 'package:nook/features/cafe_details/presentation/widgets/hero_image_slider.dart';

Widget _hero({VoidCallback? onClaimTap}) => MaterialApp(
  home: Scaffold(
    body: HeroImageSlider(
      images: const [],
      isLoading: false,
      placeholderSeed: 'Abaca',
      onClaimTap: onClaimTap,
    ),
  ),
);

void main() {
  testWidgets('a cafe with no photos shows a labelled sample photo', (
    tester,
  ) async {
    await tester.pumpWidget(_hero());
    expect(find.byType(CafePhotoPlaceholder), findsOneWidget);
    expect(find.text('Sample photo'), findsOneWidget);
    expect(find.textContaining('Add photos'), findsNothing);
    expect(find.textContaining(' / '), findsNothing, reason: 'no counter');
  });

  testWidgets('an unclaimed cafe also asks the owner to add photos', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_hero(onClaimTap: () => taps++));
    expect(find.text('Sample photo'), findsOneWidget);
    await tester.tap(find.textContaining('Add photos'));
    expect(taps, 1);
  });
}
