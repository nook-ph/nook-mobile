import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/domain/use_cases/get_share_card_data_usecase.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_state.dart';
import 'package:nook/features/crawl/presentation/pages/share_activity_page.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/crawl_share_card.dart';

@GenerateNiceMocks([MockSpec<GetShareCardDataUseCase>()])
import 'share_activity_page_test.mocks.dart';

CrawlShareCardData _stubData() {
  return CrawlShareCardData(
    userName: 'Test User',
    crawlTitle: 'Test Crawl',
    crawlPeriod: 'Jul 2026',
    totalStamps: 2,
    totalStops: 5,
    stops: [
      CrawlStopShareItem(
        stopOrder: 1, tier: 'city', cafeName: 'Cafe A',
        isClaimed: true, claimedAt: DateTime(2026, 7, 10),
      ),
      CrawlStopShareItem(
        stopOrder: 2, tier: 'city', cafeName: 'Cafe B',
        isClaimed: false,
      ),
    ],
  );
}

Widget _buildTestWidget(ShareCardCubit cubit) {
  return MaterialApp(
    home: ShareActivityPage(
      crawlId: 'test-crawl',
      crawlTitle: 'Test Crawl',
      cubit: cubit,
    ),
  );
}

void main() {
  group('ShareActivityPage', () {
    late MockGetShareCardDataUseCase useCase;
    late ShareCardCubit cubit;

    setUp(() {
      useCase = MockGetShareCardDataUseCase();
      cubit = ShareCardCubit(getShareCardDataUseCase: useCase);
    });

    tearDown(() {
      cubit.close();
    });

    testWidgets('renders AppBar with Share Activity title',
        (WidgetTester tester) async {
      final completer = Completer<Either<Failure, CrawlShareCardData>>();
      when(useCase.call(any)).thenAnswer((_) => completer.future);

      await tester.pumpWidget(_buildTestWidget(cubit));

      expect(find.text('Share Activity'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
    });

    testWidgets('renders shimmer placeholder during loading',
        (WidgetTester tester) async {
      final completer = Completer<Either<Failure, CrawlShareCardData>>();
      when(useCase.call(any)).thenAnswer((_) => completer.future);

      await tester.pumpWidget(_buildTestWidget(cubit));

      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final shimmer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration
            && (c.decoration as BoxDecoration).color == const Color(0xFF0F1F0F),
        orElse: () => Container(),
      );
      expect(shimmer.decoration, isNotNull);
    });

    testWidgets('renders CrawlShareCard on ready',
        (WidgetTester tester) async {
      when(useCase.call(any)).thenAnswer(
        (_) async => Right(_stubData()),
      );

      await tester.pumpWidget(_buildTestWidget(cubit));
      await tester.pumpAndSettle();

      expect(find.byType(CrawlShareCard), findsWidgets);
    });

    testWidgets('renders all 5 share destination buttons',
        (WidgetTester tester) async {
      when(useCase.call(any)).thenAnswer(
        (_) async => Right(_stubData()),
      );

      await tester.pumpWidget(_buildTestWidget(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Share to'), findsOneWidget);
      expect(find.text('Instagram\nStories'), findsAtLeast(1));
      expect(find.text('Copy to\nClipboard'), findsAtLeast(1));
      expect(find.text('Download'), findsAtLeast(1));
      expect(find.text('Copy Link'), findsAtLeast(1));
      expect(find.text('More'), findsAtLeast(1));
    });

    testWidgets('shows SnackBar on ShareCardError',
        (WidgetTester tester) async {
      when(useCase.call(any)).thenAnswer(
        (_) async => Left(Failure('Something went wrong')),
      );

      await tester.pumpWidget(_buildTestWidget(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsAtLeast(1));
    });

    testWidgets('download button renders and is tappable',
        (WidgetTester tester) async {
      when(useCase.call(any)).thenAnswer(
        (_) async => Right(_stubData()),
      );

      await tester.pumpWidget(_buildTestWidget(cubit));
      await tester.pumpAndSettle();

      final downloadIcons = find.byIcon(LucideIcons.download);
      expect(downloadIcons, findsAtLeast(1));

      await tester.tap(downloadIcons.last);
      await tester.pump();
    });
  });
}
