import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/data/home_layout_repository.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';

/// The layout Home last drew and the cafes it loaded for it, so the shelf
/// page opened from Home shows the same shelf without asking again. Written
/// by the Home bloc; empty until Home has loaded once.
class CurrentHomeLayout {
  HomeLayout? layout;
  Map<String, List<CafeSummary>> shelves = const {};
}

/// One shelf of the layout, in full, for the shelf page.
class HomeShelf {
  const HomeShelf({required this.section, required this.cafes});

  final HomeSection section;
  final List<CafeSummary> cafes;

  /// The admin's title; null for House picks under its default name.
  String? get title => section.title;
}

/// Loads one shelf of the published layout by its section id
/// (`custom:<id>`, or `featured` when it is hand-picked) for
/// `nook://shelf/<id>`.
///
/// - The layout is the one Home drew, else the cached one, else the
///   server's. A section missing from the first one found is looked up once
///   more on the server, so a link to a shelf published a moment ago works.
/// - A shelf opens even when the layout hides it on Home or it is outside
///   its schedule: a banner can land on a shelf made only for it.
/// - Picked shelves: the cafes Home already loaded, else `get_cafes_by_ids`.
///   Rule shelves: the rule again with [pageLimit] cafes, not the shelf's
///   limit, since this is the shelf's "See all".
/// - Returns null for an id the layout does not have, a built-in shelf
///   other than hand-picked House picks, or no layout. Throws when the
///   cafes fail to load.
class GetHomeShelfUseCase {
  GetHomeShelfUseCase({
    required this.current,
    required this.loadShelves,
    this.repository,
  });

  static const pageLimit = 50;

  final CurrentHomeLayout current;
  final HomeLayoutRepository? repository;

  /// [GetLayoutShelvesUseCase.call].
  final Future<Map<String, List<CafeSummary>>> Function(HomeLayout layout)
  loadShelves;

  Future<HomeShelf?> call(String id) async {
    var layout = current.layout ?? await repository?.cached();
    if (layout?.sectionById(id) == null && repository != null) {
      final fresh = await repository!.refresh();
      if (fresh.ok) layout = fresh.layout;
    }
    final section = layout?.sectionById(id);
    if (layout == null || section == null) return null;

    final picked = section.isCustom
        ? section.source == HomeShelfSource.picked
        : section.builtin == HomeBuiltin.featured && section.cafeIds.isNotEmpty;
    final rule = section.isCustom && section.source == HomeShelfSource.rule
        ? section.rule
        : null;
    if (!picked && rule == null) return null;

    if (picked) {
      final loaded = identical(layout, current.layout)
          ? current.shelves[id]
          : null;
      if (loaded != null) return HomeShelf(section: section, cafes: loaded);
      if (section.cafeIds.isEmpty) {
        return HomeShelf(section: section, cafes: const []);
      }
    }

    final query = HomeSection(
      id: section.id,
      builtin: section.builtin,
      title: section.title,
      cafeIds: section.cafeIds,
      source: section.source,
      rule: rule == null
          ? null
          : HomeShelfRule(tag: rule.tag, sort: rule.sort, limit: pageLimit),
    );
    final out = await loadShelves(
      HomeLayout(version: layout.version, sections: [query]),
    );
    final cafes = out[id];
    if (cafes == null) throw StateError('Shelf $id did not load');
    return HomeShelf(section: section, cafes: cafes);
  }
}
