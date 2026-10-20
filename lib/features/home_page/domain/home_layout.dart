/// The admin-controlled Home layout (contract: nook-supabase
/// `docs/HOME_LAYOUT.md`, schema 1).
///
/// Parsing is tolerant: unknown fields are ignored, a malformed section or
/// banner is dropped on its own, and only a document the app cannot read at
/// all (not an object, or `schema` above [HomeLayout.supportedSchema]) makes
/// [HomeLayout.fromRpc] return null, which means "use the built-in Home".
library;

/// Asia/Manila is UTC+8 all year (the Philippines has no daylight saving),
/// so a fixed offset gives the same wall clock as a time zone database.
const Duration manilaOffset = Duration(hours: 8);

/// [now] as a wall clock in Manila. The fields of the returned value
/// (weekday, hour, minute) are Manila's; it is a UTC [DateTime] only so no
/// device time zone is applied.
DateTime toManila(DateTime now) => now.toUtc().add(manilaOffset);

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// [ids] without the strings Postgres would not cast to `uuid`, in order.
/// `get_cafes_by_ids` takes `uuid[]`, so one bad id fails the whole batch.
List<String> uuidsOnly(Iterable<String> ids) => [
  for (final id in ids)
    if (_uuid.hasMatch(id.trim())) id.trim(),
];

/// When a banner or section is shown. Every part is optional; an empty
/// schedule is always on.
class HomeSchedule {
  const HomeSchedule({
    this.startsAt,
    this.endsAt,
    this.days = const {},
    this.fromMinute,
    this.toMinute,
  });

  /// Inclusive start and end instants; null is open-ended.
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// ISO weekdays in Manila, 1 = Monday. Empty = every day.
  final Set<int> days;

  /// Minutes since midnight in Manila. Both null = all day. When [toMinute]
  /// is before [fromMinute] the window wraps past midnight (22:00-02:00).
  final int? fromMinute;
  final int? toMinute;

  static const always = HomeSchedule();

  /// Nothing set: on at every instant.
  bool get isAlways =>
      startsAt == null &&
      endsAt == null &&
      days.isEmpty &&
      (fromMinute == null || fromMinute == toMinute);

  /// Null for a missing or unreadable schedule (treated as always on).
  static HomeSchedule? tryParse(Object? json) {
    if (json is! Map) return null;
    final days = <int>{};
    final rawDays = json['days'];
    if (rawDays is List) {
      for (final d in rawDays) {
        final day = d is int ? d : (d is num ? d.toInt() : null);
        if (day != null && day >= 1 && day <= 7) days.add(day);
      }
    }
    int? from;
    int? to;
    final hours = json['hours'];
    if (hours is Map) {
      from = parseClock(hours['from']);
      to = parseClock(hours['to']);
      // Half a window is no window: treat as all day.
      if (from == null || to == null) from = to = null;
    }
    return HomeSchedule(
      startsAt: _parseInstant(json['starts_at']),
      endsAt: _parseInstant(json['ends_at']),
      days: days,
      fromMinute: from,
      toMinute: to,
    );
  }

  /// "HH:MM" (or "HH:MM:SS") as minutes since midnight, else null.
  static int? parseClock(Object? raw) {
    if (raw is! String) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(raw);
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h > 24 || m > 59 || (h == 24 && m != 0)) return null;
    return h * 60 + m;
  }

  static DateTime? _parseInstant(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  /// Whether the schedule is on at [now] (any time zone; evaluated in
  /// Manila).
  bool isActiveAt(DateTime now) {
    final start = startsAt;
    final end = endsAt;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;

    final local = toManila(now);
    final from = fromMinute;
    final to = toMinute;
    final minute = local.hour * 60 + local.minute;

    // A wrapped window that is past midnight belongs to the day it started:
    // Friday 22:00-02:00 is still on at 01:00 Saturday.
    var weekday = local.weekday;
    if (from != null && to != null) {
      if (from == to) {
        // Same start and end: the whole day.
      } else if (from < to) {
        if (minute < from || minute >= to) return false;
      } else {
        final late = minute >= from;
        final early = minute < to;
        if (!late && !early) return false;
        if (early) weekday = weekday == 1 ? 7 : weekday - 1;
      }
    }
    return days.isEmpty || days.contains(weekday);
  }
}

/// The one card at the top of Home.
class HomeBanner {
  const HomeBanner({
    required this.title,
    this.body,
    this.imageUrl,
    this.ctaLabel,
    this.link,
    this.schedule = HomeSchedule.always,
    this.id,
  });

  final String title;
  final String? body;
  final String? imageUrl;
  final String? ctaLabel;

  /// A `nook://` deep link or an `https://` URL; anything else is dropped.
  final Uri? link;
  final HomeSchedule schedule;

  /// `banner.id` from nook-admin: a hash of what the banner says, shows and
  /// opens, stable across re-publishes. Null on documents published before
  /// it existed. Used only to remember a dismissal or a tap.
  final String? id;

  /// Null when disabled, untitled or malformed.
  static HomeBanner? tryParse(Object? json) {
    if (json is! Map) return null;
    if (json['enabled'] == false) return null;
    final title = _text(json['title']);
    if (title == null) return null;
    return HomeBanner(
      title: title,
      body: _text(json['body']),
      imageUrl: _httpsUrl(json['image_url'])?.toString(),
      ctaLabel: _text(json['cta_label']),
      link: parseLink(json['link']),
      schedule: HomeSchedule.tryParse(json['schedule']) ?? HomeSchedule.always,
      id: _text(json['id']),
    );
  }

  /// `nook://…` or `https://…`, else null.
  static Uri? parseLink(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    if (uri.scheme == 'nook') return uri;
    if (uri.scheme == 'https' && uri.host.isNotEmpty) return uri;
    return null;
  }

  static Uri? _httpsUrl(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
  }

  /// What a dismissal (and "already tapped") is remembered by: [id], so a
  /// dismissed banner stays dismissed after an unrelated publish; else, for
  /// documents without one, the published version and the title.
  String dismissKey(String version) => id ?? legacyDismissKey(version);

  /// The key used before `banner.id`. Still honoured when reading, so a
  /// banner closed under it stays closed in the same version.
  String legacyDismissKey(String version) => '$version|$title';
}

/// The built-in shelves an admin can order, hide and rename.
enum HomeBuiltin {
  yourPlaces('your_places'),
  nearby('nearby'),
  featured('featured'),
  specialty('specialty'),
  localBeans('local_beans'),
  newest('newest'),
  laptopFriendly('laptop_friendly'),
  trending('trending'),
  topRated('top_rated');

  const HomeBuiltin(this.id);

  /// The id in the layout document.
  final String id;

  static HomeBuiltin? fromId(String id) {
    for (final b in values) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// How a custom shelf is filled.
enum HomeShelfSource { picked, rule }

/// A custom shelf filled by a query: an existing tag, one of the `get_cafes`
/// sorts, and a size.
class HomeShelfRule {
  const HomeShelfRule({
    required this.tag,
    this.sort = 'top_rated',
    this.limit = defaultLimit,
  });

  static const sorts = {'top_rated', 'trending', 'newest', 'nearby'};
  static const defaultLimit = 10;
  static const minLimit = 3;
  static const maxLimit = 20;

  final String tag;
  final String sort;
  final int limit;

  static HomeShelfRule? tryParse(Object? json) {
    if (json is! Map) return null;
    final tag = _text(json['tag']);
    if (tag == null) return null;
    final sort = json['sort'];
    final limit = json['limit'];
    return HomeShelfRule(
      tag: tag,
      sort: sort is String && sorts.contains(sort) ? sort : 'top_rated',
      limit: limit is num
          ? limit.toInt().clamp(minLimit, maxLimit)
          : defaultLimit,
    );
  }
}

/// One entry of `sections`.
class HomeSection {
  const HomeSection({
    required this.id,
    this.builtin,
    this.visible = true,
    this.title,
    this.cafeIds = const [],
    this.source,
    this.rule,
    this.schedule = HomeSchedule.always,
  });

  /// As in the document: a builtin id, or `custom:<id>`.
  final String id;

  /// Null for a custom shelf.
  final HomeBuiltin? builtin;
  final bool visible;

  /// The admin's title, null for the default.
  final String? title;

  /// Hand-picked cafes in order (House picks, picked custom shelves).
  final List<String> cafeIds;
  final HomeShelfSource? source;
  final HomeShelfRule? rule;
  final HomeSchedule schedule;

  bool get isCustom => builtin == null;

  /// The rail id analytics use for a custom shelf (`custom:<id>`).
  String get railId => id.startsWith('custom:') ? id : 'custom:$id';

  static const maxCafeIds = 30;

  /// Null for an unknown builtin id or an unreadable entry.
  static HomeSection? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _text(json['id']);
    if (id == null) return null;
    final type = json['type'];
    final visible = json['visible'] != false;
    final title = _text(json['title']);
    final schedule =
        HomeSchedule.tryParse(json['schedule']) ?? HomeSchedule.always;
    final cafeIds = _ids(json['cafe_ids']);

    if (type == 'custom' || (type == null && id.startsWith('custom:'))) {
      final source = switch (json['source']) {
        'picked' => HomeShelfSource.picked,
        'rule' => HomeShelfSource.rule,
        _ => null,
      };
      final rule = HomeShelfRule.tryParse(json['rule']);
      if (source == null) return null;
      if (source == HomeShelfSource.rule && rule == null) return null;
      // A custom shelf needs a title: it has no default.
      if (title == null) return null;
      return HomeSection(
        // Always `custom:<id>`, so a custom shelf never shares an id with a
        // built-in one (in de-dup, loaded shelves and shelf links).
        id: id.startsWith('custom:') ? id : 'custom:$id',
        visible: visible,
        title: title,
        cafeIds: source == HomeShelfSource.picked ? cafeIds : const [],
        source: source,
        rule: source == HomeShelfSource.rule ? rule : null,
        schedule: schedule,
      );
    }
    if (type != null && type != 'builtin') return null;
    final builtin = HomeBuiltin.fromId(id);
    if (builtin == null) return null;
    return HomeSection(
      id: id,
      builtin: builtin,
      visible: visible,
      title: title,
      cafeIds: builtin == HomeBuiltin.featured ? cafeIds : const [],
      schedule: schedule,
    );
  }

  static List<String> _ids(Object? raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final v in raw) {
      if (out.length >= maxCafeIds) break;
      // Lower case: the RPC answers with Postgres' lower-case uuid text,
      // and the shelves are put back together by matching ids.
      final id = v is String ? v.trim().toLowerCase() : '';
      if (id.isNotEmpty && seen.add(id)) out.add(id);
    }
    return out;
  }
}

/// A published layout, as `get_home_layout()` returns it.
class HomeLayout {
  const HomeLayout({
    required this.version,
    this.publishedAt,
    this.respectPurpose = true,
    this.pinTop = true,
    this.banner,
    this.sections = const [],
  });

  static const supportedSchema = 1;
  static const maxSections = 20;
  static const maxCustom = 12;

  /// The published row id; analytics and banner dismissal key on it.
  final String version;
  final DateTime? publishedAt;
  final bool respectPurpose;

  /// `pin_top` (default true): Your places and Near you stay in the first
  /// three shelves when they have something to show, wherever the document
  /// puts them. False keeps the admin's order for them too.
  final bool pinTop;
  final HomeBanner? banner;
  final List<HomeSection> sections;

  /// Whether anything in it turns on or off with time.
  bool get hasSchedules =>
      !(banner?.schedule.isAlways ?? true) ||
      sections.any((s) => !s.schedule.isAlways);

  /// No sections and no banner: "reset to default", the built-in Home.
  bool get isDefault => sections.isEmpty && banner == null;

  /// The section with [id] (`custom:<id>` or a builtin id), else null.
  HomeSection? sectionById(String id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The layout in an RPC response, or null for the built-in Home: no
  /// published layout, an unreadable response, or a schema this app does
  /// not know.
  static HomeLayout? fromRpc(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final document = json['document'];
    if (version is! String || version.isEmpty || document is! Map) {
      return null;
    }
    final schema = document['schema'];
    if (schema is! num || schema.toInt() != schema || schema < 1) return null;
    if (schema > supportedSchema) return null;

    final sections = <HomeSection>[];
    final seen = <String>{};
    var custom = 0;
    final raw = document['sections'];
    if (raw is List) {
      for (final entry in raw) {
        if (sections.length >= maxSections) break;
        final section = HomeSection.tryParse(entry);
        if (section == null || !seen.add(section.id)) continue;
        if (section.isCustom && ++custom > maxCustom) continue;
        sections.add(section);
      }
    }
    final publishedAt = json['published_at'];
    return HomeLayout(
      version: version,
      publishedAt: publishedAt is String
          ? DateTime.tryParse(publishedAt)
          : null,
      respectPurpose: document['respect_purpose'] != false,
      pinTop: document['pin_top'] != false,
      banner: HomeBanner.tryParse(document['banner']),
      sections: sections,
    );
  }
}

String? _text(Object? raw) {
  if (raw is! String) return null;
  final t = raw.trim();
  return t.isEmpty ? null : t;
}
