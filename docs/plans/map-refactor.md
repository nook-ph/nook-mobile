# Map refactor plan — port webapp map behavior to mobile

Branch: `refactor/map` (cut from main `654ffdb`, 2026-07-15)

## Goal

Bring the mobile map (`lib/features/map/`) up to par with the webapp map
(`nook-webapp/app/components/CafeMap.tsx` + `MapExplorer.tsx`):

1. **Viewport-driven fetching** — refetch cafes as the user pans/zooms:
   fixed **20 km radius** around the map center when zoomed in, exact
   viewport bounds when zoomed out. Debounced, stale-response-safe.
2. **Rating-pill pins** — pins rendered as GeoJSON style layers (dot +
   rating pill with star/rating/review-count/tail), collision-aware so
   the best-rated pin wins when pins overlap; unrated cafes show a dot.
3. **Non-blocking loader** — a floating "Updating" chip while a viewport
   fetch is in flight; the previous pins/list stay visible.
4. **Camera behaviors** — fit-to-markers on first load, fly-to on
   geolocation, no camera move on pin selection.

## How the webapp does it (reference)

- `MapExplorer.tsx` — owns fetch orchestration:
  - `RADIUS_METERS = 20000`, `MOVE_DEBOUNCE_MS = 300`.
  - On every `moveend` the map emits `{center, bounds, zoom}`. If
    `viewportRadiusMeters(viewport) <= 20km` (center→NE-corner haversine)
    it fetches `mode=radius` (fixed 20 km circle around center), else
    `mode=viewport` (exact bounds). 300 ms debounce; `AbortController`
    cancels the in-flight request; on abort/error the previous list is kept.
  - Loader: absolute-positioned pill, top-center of the map, animated dots +
    "Updating", pointer-events none.
  - Plain view (no query/tags): one-shot geolocation → `flyTo` user location
    (zoom ≥ 13); the viewport fetch loop takes over from there.
- `CafeMap.tsx` — owns rendering:
  - One GeoJSON source (`promoteId: 'id'`), four layers: `circle` dot layer;
    `symbol` pill layer (`icon-image: ['get','pillIcon']`, anchor bottom,
    `icon-allow-overlap: false` + `symbol-sort-key: -(rating*1000+reviewCount)`
    so overlapping pills compete and the best-rated stays visible, the rest
    fall back to their dot); a hover/selected duplicate layer; a coffee-badge
    layer for unrated cafes when hovered/selected.
  - Pills are **canvas-rasterized at 3× per distinct rating/review-count
    combo** and registered as map images (`pill-4.5-120`), cached in a Set.
    Review counts abbreviate (`1240 → "1.2k"`).
  - Initial camera: fit bounds of initial cafes (padding 60, maxZoom 15;
    single cafe → zoom 15.5). The programmatic initial move's `moveend` is
    skipped so it doesn't trigger a fetch.
- Data: Supabase RPCs **`get_cafes_near_point`** and **`get_cafes_in_viewport`**
  (limit 1000, offset 0, optional `p_query`/`p_tag_names`). Same Supabase
  project as mobile (URL verified identical), but these two RPCs are missing
  from mobile's `DB.md` — signatures are in
  `nook-webapp/lib/supabase/types.ts:146-175`.

## Current mobile state (what changes)

- `MapBloc` does a one-shot `LoadMapDataEvent` → `get_cafes` (sort/filter,
  limit 20). No viewport awareness; panning never refetches.
- Pins are per-cafe `addSymbol` calls with a static `MapPin.png` at
  `iconSize 0.17` (0.23 when selected); `clearSymbols()` + re-add on reload.
  No rating pills, no collision priority.
- Full-screen skeleton in the bottom sheet while loading; map itself has no
  refresh indicator.
- `maplibre_gl 0.25` is already the map plugin — it supports everything we
  need: `addGeoJsonSource`/`setGeoJsonSource`, `addCircleLayer`/
  `addSymbolLayer` with expressions, `symbol-sort-key`, `onFeatureTapped`,
  `onCameraIdle`, `getVisibleRegion`, `addImage`. It does **not** expose
  `setFeatureState`, so the webapp's hover/selected feature-state approach
  maps to a **selected-pin layer driven by `setFilter`** instead (there is
  no hover on touch anyway).

## Plan

### Phase 1 — data layer (`lib/core/cafe/`, shared)

- `core/utils/geo.dart` (new): `MapBounds`, `MapViewport` value types,
  `haversineMeters(a, b)`, `viewportRadiusMeters(viewport)` — direct port of
  `nook-webapp/lib/utils/maps.ts`. Unit-tested.
- `cafe_remote_data_source.dart`: add
  - `getCafesNearPoint(lat, lng, radiusMeters, {query, tags, userId})` →
    RPC `get_cafes_near_point`
  - `getCafesInViewport(bounds, {query, tags, userId})` →
    RPC `get_cafes_in_viewport`
  Both `p_limit: 1000, p_offset: 0`; reuse the existing `CafeSummaryModel`
  row mapping. Unlike the webapp (anon), pass the session user id so
  `isFavorited` comes back correct.
- Thread through `ICafeRepository` / `CafeRepositoryImpl` (+ `warmCache`
  like the existing path).
- Document both RPC signatures in `DB.md`.

### Phase 2 — use case

- `GetCafesForViewportUseCase` (map feature): input `MapViewport` +
  `CafeFilter`; picks **radius mode** when
  `viewportRadiusMeters(viewport) <= 20_000` (fetch fixed 20 km circle
  around `viewport.center`), else **viewport mode** (fetch exact bounds).
  Constant lives here: `kMapRadiusMeters = 20000`.

### Phase 3 — MapBloc refactor

- New event `MapViewportChangedEvent(MapViewport)`:
  - debounced 300 ms + restartable (`bloc_concurrency` transformer — add
    dev-standard `transformer: (events, mapper) => events.debounce(...).switchMap(mapper)`
    or a small custom transformer; `bloc_concurrency` may need adding to
    pubspec).
  - a monotonically increasing request id guards against stale responses
    (the AbortController equivalent).
- `MapLoadedState` gains `isRefreshing` (loader chip) and keeps the previous
  `cafes` while a refetch is in flight. Refetch **errors keep the previous
  list** (webapp behavior); only the initial `LoadMapDataEvent` surfaces
  `MapError`.
- Bloc stores `lastViewport`; applying/clearing filters refetches it
  immediately (no debounce).
- Initial load stays `LoadMapDataEvent` (existing nearby/`get_cafes` fetch
  is fine for first paint, mirroring the webapp's server-rendered initial
  list); the first viewport event after the programmatic fit is skipped.

### Phase 4 — pins as style layers (`map_page.dart` + new widgets/helpers)

- Replace `addSymbol`/`clearSymbols` with:
  - `addGeoJsonSource('cafes', featureCollection)` where each feature carries
    `id`, `name`, `rating`, `ratingNumber`, `reviewCount`, `pillIcon`;
    updates go through `setGeoJsonSource`.
  - **Dot layer** (`CircleLayerProperties`): radius 6, brand fill `#2D6A4F`,
    white 1.5 stroke — every cafe.
  - **Pill layer** (`SymbolLayerProperties`): `iconImage: ['get','pillIcon']`,
    `iconAnchor: 'bottom'`, `iconAllowOverlap: false`,
    `symbolSortKey: -(rating*1000 + reviewCount)`, icon-opacity 0 for
    unrated. Overlap collision then does what the webapp does: densest areas
    show the best-rated pill, others degrade to dots.
  - **Selected layer**: same pill imagery at ~1.16×, `iconAllowOverlap: true`,
    filtered to the selected cafe id via `setFilter` (replaces feature-state).
    Unrated selected cafes show the coffee-badge pin here instead.
- `map_pin_images.dart` (new helper): rasterize the stadium pill (star +
  rating + `(count)` + pointer tail, 3× supersampled) and the circular
  coffee badge with Flutter `Canvas`/`PictureRecorder` → PNG bytes →
  `controller.addImage('pill-4.5-120', bytes)`. Cache registered ids in a
  `Set` per controller; register only combos present in the current data.
  Port `formatReviewCount` (`1240 → "1.2k"`). Match webapp styling tokens
  (fill `#2D6A4F`, white border 2.5, shadow, Poppins/Inter-weight text).
- Tap: `controller.onFeatureTapped` (fall back to
  `queryRenderedFeatures` on the tap point if needed) → select cafe →
  existing `CafeOverlayCard` flow stays. Selection no longer moves the
  camera. Deselect on map tap / overlay close via clearing the selected
  filter.

### Phase 5 — viewport + camera wiring

- `onCameraIdle` → `controller.getVisibleRegion()` + `cameraPosition` →
  build `MapViewport` → dispatch `MapViewportChangedEvent`. Skip the one
  fired by the initial programmatic fit (port of `skipNextMoveEndRef`).
- Initial camera: fit bounds of first-load cafes (padding 60, maxZoom 15;
  single cafe → zoom 15.5) instead of the fixed Cebu `zoom 10`.
- Geolocation: keep the existing permission flow; when granted on entry
  (plain view, no query/tags), fly to the user at zoom
  `max(current, 13)`; the viewport loop takes over from there.

### Phase 6 — loader + bottom sheet

- `MapUpdatingChip` (new widget): floating top-center pill under the search
  bar — three animated dots + "Updating", `IgnorePointer`, white/95 bg,
  subtle shadow. Shown when `state.isRefreshing`.
- Bottom sheet: list is the same viewport result set as the pins; add the
  "N cafes in view" count and the empty copy "No cafes in this area. Try
  zooming out or moving the map." Selected cafe's card gets a highlight
  (webapp uses a ring).

### Phase 7 — tests, docs, verification

- Unit tests: geo helpers (haversine sanity, radius threshold at exactly
  20 km), use-case mode selection, MapBloc (debounce, stale-response drop,
  refetch-error keeps list, filter-apply refetches lastViewport),
  `formatReviewCount`, pill-id caching.
- Widget test: loader chip visibility toggles with `isRefreshing`.
- `flutter analyze`, `flutter test`, then manual run: pan/zoom refetch both
  modes, pill collision when zooming out, selection grow, overlay card,
  geolocation flow, filter refetch.
- Update `docs/features/map.md` (or add it) to describe the new flow.

## Suggested commit/PR slicing

1. Phase 1+2 (data + use case + geo utils, with tests) — no UI change.
2. Phase 3+5+6 (bloc + viewport wiring + loader) — behavior change, old pins.
3. Phase 4 (pill pins + selection layers) — visual change.

## Risks / notes

- `get_cafes_near_point` / `get_cafes_in_viewport` exist in the shared
  Supabase project but not in mobile docs — verify with a quick RPC call
  before building on them (signatures: `nook-webapp/lib/supabase/types.ts`).
- No `setFeatureState` in `maplibre_gl` — selected styling via `setFilter`
  is the documented divergence from the webapp.
- 1000-pin GeoJSON updates on every idle are fine for MapLibre, but
  registering many pill images is the hot spot — the id cache bounds it
  (distinct rating×count combos, small in practice).
- `symbol-sort-key` + collision needs `iconAllowOverlap: false` on the base
  pill layer only; the selected layer must overlap-allow so selection never
  disappears.
