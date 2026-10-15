import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/domain/home_rail_order.dart';

/// One shelf Home shows, in order: a built-in one (with the admin's title,
/// when set) or a custom one.
class HomeSlot {
  const HomeSlot.builtin(HomeBuiltin this.builtin, {this.section})
    : custom = null;
  const HomeSlot.custom(HomeSection this.custom)
    : builtin = null,
      section = custom;

  final HomeBuiltin? builtin;
  final HomeSection? custom;

  /// The layout entry behind this slot; null for a built-in shelf the
  /// layout does not mention (or with no layout at all).
  final HomeSection? section;

  /// The admin's title, else null for the shelf's own.
  String? get titleOverride => section?.title;

  @override
  String toString() => builtin?.id ?? custom!.id;
}

/// [HomeRail] for a built-in id; null for Your places.
HomeRail? railFor(HomeBuiltin builtin) => switch (builtin) {
  HomeBuiltin.yourPlaces => null,
  HomeBuiltin.nearby => HomeRail.nearby,
  HomeBuiltin.featured => HomeRail.featured,
  HomeBuiltin.specialty => HomeRail.specialty,
  HomeBuiltin.localBeans => HomeRail.localBeans,
  HomeBuiltin.newest => HomeRail.newest,
  HomeBuiltin.laptopFriendly => HomeRail.laptopFriendly,
  HomeBuiltin.trending => HomeRail.trending,
  HomeBuiltin.topRated => HomeRail.topRated,
};

HomeBuiltin builtinFor(HomeRail rail) => switch (rail) {
  HomeRail.nearby => HomeBuiltin.nearby,
  HomeRail.featured => HomeBuiltin.featured,
  HomeRail.specialty => HomeBuiltin.specialty,
  HomeRail.localBeans => HomeBuiltin.localBeans,
  HomeRail.newest => HomeBuiltin.newest,
  HomeRail.laptopFriendly => HomeBuiltin.laptopFriendly,
  HomeRail.trending => HomeBuiltin.trending,
  HomeRail.topRated => HomeBuiltin.topRated,
};

/// Home's built-in order with no layout: Your places, then the shelves with
/// the purpose shelf moved to the top (today's Home).
List<HomeSlot> defaultHomeSlots(
  OnboardingPurpose? purpose, {
  required Set<HomeRail> available,
}) => [
  const HomeSlot.builtin(HomeBuiltin.yourPlaces),
  for (final rail in orderHomeRails(purpose, available: available))
    HomeSlot.builtin(builtinFor(rail)),
];

/// The shelves in order for [layout] at [now].
///
/// - No layout, or one with no sections: [defaultHomeSlots].
/// - Otherwise the layout's order; built-ins it leaves out follow in the
///   default order. Hidden and out-of-schedule sections are left out.
/// - With `respect_purpose`, the first purpose shelf in [available] that is
///   still shown moves to the top of the shelves (below Your places when
///   that leads), as today.
///
/// - With `pin_top` (the default), Your places and Near you (when it has
///   cafes) are pulled into the first [pinnedSlots] shelves: see
///   [pinPersonalShelves].
///
/// Whether a shelf has enough cafes is decided where it is built; this only
/// orders.
List<HomeSlot> planHomeSlots({
  required HomeLayout? layout,
  required OnboardingPurpose? purpose,
  required Set<HomeRail> available,
  required DateTime now,
}) {
  if (layout == null || layout.sections.isEmpty) {
    return defaultHomeSlots(purpose, available: available);
  }

  final slots = <HomeSlot>[];
  final mentioned = <HomeBuiltin>{};
  for (final section in layout.sections) {
    final builtin = section.builtin;
    if (builtin != null) mentioned.add(builtin);
    if (!section.visible || !section.schedule.isActiveAt(now)) continue;
    slots.add(
      builtin == null
          ? HomeSlot.custom(section)
          : HomeSlot.builtin(builtin, section: section),
    );
  }
  for (final builtin in HomeBuiltin.values) {
    if (!mentioned.contains(builtin)) slots.add(HomeSlot.builtin(builtin));
  }

  if (layout.respectPurpose) {
    for (final rail in purposeRails(purpose)) {
      if (!available.contains(rail)) continue;
      final index = slots.indexWhere((s) => s.builtin == builtinFor(rail));
      if (index < 0) continue;
      final slot = slots.removeAt(index);
      final top =
          slots.isNotEmpty && slots.first.builtin == HomeBuiltin.yourPlaces
          ? 1
          : 0;
      slots.insert(top, slot);
      break;
    }
  }
  if (!layout.pinTop) return slots;
  return pinPersonalShelves(slots, available: available);
}

/// How many shelves from the top Your places and Near you must sit within.
const pinnedSlots = 3;

/// [slots] with Your places and Near you in the first [pinnedSlots], for a
/// "where now" app the two shelves most likely to get a tap (UX research
/// 2026-10-16, finding 2).
///
/// Near you counts only when it is in [available] (it has cafes, so the
/// phone has a position). Your places always counts: with nothing saved it
/// draws nothing and takes no room.
///
/// When both already sit in the first [pinnedSlots], nothing moves.
/// Otherwise the first shelves are the pinned ones plus the admin's first
/// other shelves, kept in the document's order; everything else follows in
/// its order. A shelf the layout hides is not in [slots] and is not brought
/// back.
List<HomeSlot> pinPersonalShelves(
  List<HomeSlot> slots, {
  required Set<HomeRail> available,
}) {
  bool pinned(HomeSlot s) =>
      s.builtin == HomeBuiltin.yourPlaces ||
      (s.builtin == HomeBuiltin.nearby && available.contains(HomeRail.nearby));

  final pins = [
    for (final s in slots)
      if (pinned(s)) s,
  ];
  if (pins.isEmpty) return slots;
  if (pins.every((p) => slots.indexOf(p) < pinnedSlots)) return slots;

  final lead = pinnedSlots - pins.length;
  final others = [
    for (final s in slots)
      if (!pinned(s)) s,
  ];
  final top = {...pins, ...others.take(lead)};
  return [
    for (final s in slots)
      if (top.contains(s)) s,
    for (final s in others.skip(lead)) s,
  ];
}
