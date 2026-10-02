import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_rankings_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/log_cafe_comparison_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/remove_cafe_ranking_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_ranking_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/utils/theme/theme.dart';

final _day = DateTime(2026, 9, 1);

CafeList cafeList({
  required String id,
  String? name,
  String listType = 'custom',
  int cafeCount = 0,
  bool isDefault = false,
  bool isPublic = false,
  String? description,
  DateTime? lastSavedAt,
}) => CafeList(
  id: id,
  name: name ?? id,
  description: description,
  isDefault: isDefault,
  isPublic: isPublic,
  cafeCount: cafeCount,
  createdAt: _day,
  updatedAt: _day,
  lastSavedAt: lastSavedAt,
  listType: listType,
);

/// A cafe with no photo, so nothing in a test reaches for the network.
CafeSummary cafe(
  String id, {
  String? name,
  String neighborhood = 'Lahug',
  double rating = 4.8,
  int reviewCount = 12,
  String? note,
}) => CafeSummary(
  id: id,
  name: name ?? id,
  neighborhood: neighborhood,
  city: 'Cebu City',
  rating: rating,
  reviewCount: reviewCount,
  note: note,
);

CafeRanking ranking(String id, RankBucket bucket, int position, double score) =>
    CafeRanking(cafeId: id, bucket: bucket, position: position, score: score);

/// Ranking-only fake; everything else on ICafeRepository throws.
class FakeRankingRepository implements ICafeRepository {
  List<CafeRanking> serverRankings = [];
  bool failSet = false;

  @override
  Future<List<CafeRanking>> getCafeRankings() async => List.of(serverRankings);

  @override
  Future<List<CafeRanking>> setCafeRanking({
    required String cafeId,
    required RankBucket bucket,
    required int position,
  }) async {
    if (failSet) throw Exception('offline');
    serverRankings =
        [
          for (final x in serverRankings)
            if (x.cafeId != cafeId)
              x.bucket == bucket && x.position >= position
                  ? ranking(x.cafeId, x.bucket, x.position + 1, x.score - 0.5)
                  : x,
          ranking(cafeId, bucket, position, 8.5),
        ]..sort((a, b) {
          final byBucket = a.bucket.sortOrder.compareTo(b.bucket.sortOrder);
          return byBucket != 0 ? byBucket : a.position.compareTo(b.position);
        });
    return List.of(serverRankings);
  }

  @override
  Future<void> logCafeComparison({
    required String winnerCafeId,
    required String loserCafeId,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

CafeRankingCubit rankingCubit(ICafeRepository repo) => CafeRankingCubit(
  getCafeRankingsUseCase: GetCafeRankingsUseCase(repo),
  setCafeRankingUseCase: SetCafeRankingUseCase(repo),
  removeCafeRankingUseCase: RemoveCafeRankingUseCase(repo),
  logCafeComparisonUseCase: LogCafeComparisonUseCase(repo),
);

/// A 390 x 844 phone, the size the frames are drawn at.
void usePhone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget host(Widget child) => MaterialApp(
  theme: TAppTheme.lightTheme,
  home: Scaffold(body: child),
);

/// A page with one button that opens [sheet] and records what it popped.
class SheetOpener<T> extends StatelessWidget {
  const SheetOpener({super.key, required this.sheet, required this.onResult});

  final Widget sheet;
  final ValueChanged<T?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: TAppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await ListsSheet.show<T>(context, builder: (_) => sheet),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The pill carrying [label], to read whether it is enabled.
ListsPillButton pill(WidgetTester tester, String label) =>
    tester.widget<ListsPillButton>(find.widgetWithText(ListsPillButton, label));
