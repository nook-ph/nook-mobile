# Caching (`CafeStore` / `CafeBundle` / TTL)

> **Status:** 🚧 In Progress
> **Last updated:** 2026-05-08

---

## 1. What This Document Covers

The in-memory caching strategy used in Nook: `CafeStore`, the `CafeBundle`
entity pattern, and how TTL (time-to-live) is implemented.

---

## 2. Why Caching Exists

Fetching a full cafe view can require multiple Supabase round-trips (details,
menu, reviews). The `CafeBundle` pattern groups these into one unit so repeat
visits can avoid redundant fetches.

---

## 3. `CafeBundle`

**File:** `lib/core/cafe/domain/entities/cafe_bundle.dart`

A `CafeBundle` groups a cafe's detail entity with optional menu and reviews.
This is the unit cached in memory.

```dart
class CafeBundle {
  final CafeDetails details;
  final List<MenuItem>? menu;
  final List<Review>? reviews;

  const CafeBundle({required this.details, this.menu, this.reviews});

  CafeBundle copyWith({
    CafeDetails? details,
    List<MenuItem>? menu,
    List<Review>? reviews,
  }) {
    return CafeBundle(
      details: details ?? this.details,
      menu: menu ?? this.menu,
      reviews: reviews ?? this.reviews,
    );
  }
}
```

---

## 4. `CafeStore`

**File:** `lib/core/cafe/data/cafe_store.dart`

An in-memory store that holds `CafeBundle`s keyed by `cafeId`, with TTL-based
staleness checks tracked separately from the bundle itself.

```dart
class CafeStore {
  static const Duration _ttl = Duration(minutes: 5);

  final Map<String, CafeBundle> _bundles = <String, CafeBundle>{};
  final Map<String, DateTime> _writtenAt = <String, DateTime>{};

  CafeBundle? get(String id) {
    if (isStale(id)) return null;
    return _bundles[id];
  }

  void set(String id, CafeBundle bundle) {
    _bundles[id] = bundle;
    _writtenAt[id] = DateTime.now();
  }

  void bust(String id) {
    _bundles.remove(id);
    _writtenAt.remove(id);
  }

  void bustAll() {
    _bundles.clear();
    _writtenAt.clear();
  }

  bool isStale(String id) {
    final writtenAt = _writtenAt[id];
    if (writtenAt == null) return true;
    return DateTime.now().difference(writtenAt) > _ttl;
  }
}
```

---

## 5. TTL Strategy

| Scenario | TTL Behavior |
|---|---|
| First visit to cafe details | Cache miss -> fetch -> store |
| Return visit within TTL | Cache hit -> return bundle, no Supabase call |
| Return visit after TTL | Cache miss -> re-fetch -> store |
| App cold start | Cache is empty (in-memory only, no persistence) |
| Summary warm-up | Store seeded `CafeDetails` with `createdAt = 0` and null menu/reviews |

---

## 6. Where Caching Is Used

| Feature | Uses CafeStore? | Notes |
|---|---|---|
| Cafe Details | ✅ | `getCafeBundleById` returns cached bundle when fresh |
| Home/Feed lists | ✅ (warm cache) | `warmCache` seeds partial bundles from summaries |
| Cafe Discovery (list) | ❓ | Uses `getCafes`, no list-level cache found |
| Favorites | ❓ | No cache hooks found |
| Reviews | ❓ | Reviews can be included in bundle, no separate cache found |

---

## 7. Cache Invalidation Triggers

> Document every place in the codebase that calls `bust()` or `bustAll()`.

- _No calls found yet (as of 2026-05-08)._

---

## 8. Open Questions

- [ ] Is the full cafe list cached or only individual bundles?
- [ ] Should `bust()` be called after review submission or list changes?
- [ ] Should `bustAll()` be called on sign out?
- [ ] Is `CafeStore` ever persisted to disk (Hive, SharedPreferences)?
- [ ] Add more as you go.
