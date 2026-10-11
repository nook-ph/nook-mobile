import 'package:nook/features/cups/data/demo_cups_repository.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';

/// What [FakeCupsRepository.postCup] was asked to post.
typedef PostedCup = ({
  String cafeId,
  int? rating,
  String? note,
  DateTime? visitedAt,
  List<CupItemDraft> items,
});

/// The demo's fixtures, recording writes instead of keeping them, on the
/// backend [mode] says. [failure] makes the next write throw.
class FakeCupsRepository extends DemoCupsRepository {
  FakeCupsRepository({
    this.backend = CupsMode.cups,
    this.markBeen = true,
    super.me,
    super.now,
  });

  CupsMode backend;
  bool markBeen;
  Object? failure;
  final posts = <PostedCup>[];
  final updates = <({CupCard cup, int? rating, String? note})>[];
  final removed = <List<String>>[];
  final deleted = <CupCard>[];

  @override
  CupsMode get mode => backend;

  @override
  Future<CupsMode> resolveMode() async => backend;

  @override
  Future<CupPostResult> postCup({
    required String cafeId,
    int? rating,
    String? note,
    DateTime? visitedAt,
    required List<CupItemDraft> items,
    void Function(int index)? onPhotoUploaded,
  }) async {
    final error = failure;
    if (error != null) throw error;
    posts.add((
      cafeId: cafeId,
      rating: rating,
      note: note,
      visitedAt: visitedAt,
      items: items,
    ));
    for (var i = 0; i < items.length; i++) {
      if (items[i].hasPhoto) onPhotoUploaded?.call(i);
    }
    return CupPostResult(itemsAdded: items.length, markedBeen: markBeen);
  }

  @override
  Future<CupPostResult> updateCup(
    CupCard cup, {
    int? rating,
    String? note,
    DateTime? visitedAt,
    List<CupItemDraft> addItems = const [],
    List<String> removeItemIds = const [],
    void Function(int index)? onPhotoUploaded,
  }) async {
    final error = failure;
    if (error != null) throw error;
    updates.add((cup: cup, rating: rating, note: note));
    removed.add(removeItemIds);
    return CupPostResult(itemsAdded: addItems.length);
  }

  @override
  Future<void> deleteCup(CupCard cup) async {
    final error = failure;
    if (error != null) throw error;
    deleted.add(cup);
  }
}
