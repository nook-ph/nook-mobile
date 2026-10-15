import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';

/// Cafes a custom shelf needs before it shows, like the built-in ones.
const minCustomShelfCafes = 3;

/// The cafes a layout adds to Home, keyed by section id: hand-picked House
/// picks (`featured`) and every custom shelf. A section that fails to load
/// is left out: House picks then fall back to the automatic ones, a custom
/// shelf stays hidden.
///
/// - Hand-picked cafes: one `get_cafes_by_ids` call for every id in the
///   layout, split back per section.
/// - Rule shelves: `get_cafes` with the rule's tag in `p_tag_names` and its
///   sort, the same call the built-in tag shelves (Specialty coffee, Local
///   beans) make. A `nearby` rule without a position falls back to
///   `top_rated`, as Local beans does.
class GetLayoutShelvesUseCase {
  /// `get_cafes_by_ids` raises above 100 ids.
  static const maxIdsPerCall = 100;

  GetLayoutShelvesUseCase({
    required this.repository,
    required Future<List<CafeSummary>> Function(List<String> ids) cafesByIds,
    Future<Position?> Function()? position,
  }) : _cafesByIds = cafesByIds,
       _position = position ?? _devicePosition;

  /// The phone's position when location is already allowed; never prompts.
  static Future<Position?> _devicePosition() async {
    final access = await DeviceLocation.instance.access();
    if (access.servicesOff || access.denied) return null;
    return DeviceLocation.instance.first();
  }

  final ICafeRepository repository;
  final Future<List<CafeSummary>> Function(List<String> ids) _cafesByIds;
  final Future<Position?> Function() _position;

  Future<Map<String, List<CafeSummary>>> call(HomeLayout? layout) async {
    if (layout == null) return const {};
    final picked = <HomeSection>[];
    final rules = <HomeSection>[];
    for (final s in layout.sections) {
      if (!s.visible) continue;
      if (s.builtin == HomeBuiltin.featured && s.cafeIds.isNotEmpty) {
        picked.add(s);
      } else if (s.isCustom) {
        if (s.source == HomeShelfSource.picked && s.cafeIds.isNotEmpty) {
          picked.add(s);
        } else if (s.source == HomeShelfSource.rule && s.rule != null) {
          rules.add(s);
        }
      }
    }

    final out = <String, List<CafeSummary>>{};
    final futures = <Future<void>>[];

    if (picked.isNotEmpty) {
      // One call per [maxIdsPerCall] distinct ids (the RPC refuses more
      // than 100). A section whose ids were in a failed call is left out.
      final ids = <String>{for (final s in picked) ...s.cafeIds}.toList();
      futures.add(() async {
        final byId = <String, CafeSummary>{};
        final failed = <String>{};
        await Future.wait([
          for (var i = 0; i < ids.length; i += maxIdsPerCall)
            () async {
              final chunk = ids.sublist(
                i,
                (i + maxIdsPerCall).clamp(0, ids.length),
              );
              try {
                for (final c in await _cafesByIds(chunk)) {
                  byId[c.id] = c;
                }
              } catch (_) {
                failed.addAll(chunk);
              }
            }(),
        ]);
        for (final s in picked) {
          // Left out: House picks go automatic, custom shelves hide.
          if (s.cafeIds.any(failed.contains)) continue;
          out[s.id] = [for (final id in s.cafeIds) ?byId[id]];
        }
      }());
    }

    if (rules.isNotEmpty) {
      final needsPosition = rules.any((s) => s.rule!.sort == 'nearby');
      final positionFuture = needsPosition
          ? _safePosition()
          : Future<Position?>.value();
      for (final s in rules) {
        futures.add(() async {
          final rule = s.rule!;
          final at = rule.sort == 'nearby' ? await positionFuture : null;
          try {
            out[s.id] = await repository.getCafes(
              CafeQuery(
                sort: rule.sort == 'nearby' && at == null
                    ? 'top_rated'
                    : rule.sort,
                tags: [rule.tag],
                lat: at?.latitude,
                lng: at?.longitude,
                limit: rule.limit,
              ),
            );
          } catch (_) {
            // Hidden.
          }
        }());
      }
    }

    await Future.wait(futures);
    final all = [for (final cafes in out.values) ...cafes];
    if (all.isNotEmpty) {
      try {
        await repository.warmCache(all);
      } catch (_) {}
    }
    return out;
  }

  Future<Position?> _safePosition() async {
    try {
      return await _position();
    } catch (_) {
      return null;
    }
  }
}
