import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_preview_section.dart';
import 'package:nook/features/public_profile/presentation/widgets/review_author_link.dart';

import '../profile/profile_test_support.dart' show FakeBlockCubit;

/// Holds a fixed [ReviewsState] for the section to read.
class _StubReviewsBloc extends Cubit<ReviewsState> implements ReviewsBloc {
  _StubReviewsBloc(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReviewEntity _review(String id, String userId, String name) => ReviewEntity(
  id: id,
  cafeId: 'cafe-1',
  userId: userId,
  rating: 5,
  content: 'Quiet upstairs.',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
  name: name,
);

/// The cafe page's review cards link a reviewer's name to their profile.
/// Your own name opened a visitor's view of yourself (Share "Find me on
/// Nook", no Edit, nothing saying it was you); like the full review list,
/// it is not a link.
void main() {
  testWidgets('your own review card does not link to a profile', (
    tester,
  ) async {
    final bloc = _StubReviewsBloc(
      ReviewsLoaded(
        cafeId: 'cafe-1',
        reviews: [
          _review('r1', 'me', 'Cris Lucero'),
          _review('r2', 'bea-id', 'Bea Santos'),
        ],
      ),
    );
    addTearDown(bloc.close);
    final block = FakeBlockCubit();
    addTearDown(block.close);
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MultiBlocProvider(
              providers: [
                BlocProvider<ReviewsBloc>.value(value: bloc),
                BlocProvider<BlockCubit>.value(value: block),
              ],
              child: ReviewsPreviewSection(
                onSeeAllTap: () {},
                onWriteReviewTap: () {},
                currentUserId: 'me',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cris Lucero'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Open Cris Lucero’s profile')),
      findsNothing,
    );
    // Someone else's still links.
    expect(
      find.bySemanticsLabel(RegExp('^Open Bea Santos’s profile')),
      findsOneWidget,
    );
    // And only theirs carries the profile chevron: on your own card it
    // promised a link that isn't there.
    Finder chevronOn(String name) => find.descendant(
      of: find.ancestor(
        of: find.text(name),
        matching: find.byType(ReviewAuthorLink),
      ),
      matching: find.byIcon(LucideIcons.chevronRight),
    );
    expect(chevronOn('Cris Lucero'), findsNothing);
    expect(chevronOn('Bea Santos'), findsOneWidget);
  });
}
