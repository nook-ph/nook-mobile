# Map

The map tab (`lib/features/map/`) is a viewport-driven cafe explorer, ported
from the webapp's map (`nook-webapp/app/components/CafeMap.tsx` +
`MapExplorer.tsx`). See `docs/plans/map-refactor.md` for the original design.

## Data flow

1. **Initial load** — `LoadMapDataEvent` runs the existing
   `GetCafeCardUseCase` (`get_cafes` RPC, filter-aware) and emits
   `MapLoadedState`. The bottom sheet shows a skeleton during this load only.
2. **Camera settles** — `MapPage._onCameraIdle` builds a `MapViewport`
   (center + visible bounds + zoom, `lib/core/utils/geo.dart`) and dispatches
   `MapViewportChangedEvent`.
3. **Viewport fetch** — `MapBloc` debounces viewport events (300 ms,
   `switchMap` so newer events cancel in-flight handlers) and calls
   `GetCafesForViewportUseCase`:
   - visible area fits inside **20 km** (`viewportRadiusMeters`) → RPC
     `get_cafes_near_point` with a fixed 20 km circle around the center;
   - zoomed out beyond that → RPC `get_cafes_in_viewport` with the exact
     bounds.
   Both fetch up to 1000 rows (the map wants all pins, not a page) and pass
   the active `CafeFilter` (query, tags, sort) plus the session user id.
4. **Refresh semantics** — during a refetch `MapLoadedState.isRefreshing` is
   true: the previous cafes stay on screen and `MapUpdatingChip` (floating
   "Updating" pill) shows. Refetch errors keep the previous list; a stale
   response (a newer fetch started meanwhile) is dropped via a fetch counter.
5. **Filters** — the filter sheets keep dispatching `LoadMapDataEvent`; once
   a viewport exists, that event refetches the current viewport immediately
   (no debounce) instead of restarting the page.

## Pin rendering

Pins are style layers over one GeoJSON source (`promoteId: 'id'`), not
per-cafe symbols:

- `cafe-dots` — circle layer, every cafe.
- `cafe-pills` — symbol layer of canvas-rasterized rating pills
  (star + rating + abbreviated review count + pointer tail). Overlap is
  disallowed and `symbol-sort-key` prefers `rating*1000 + reviewCount`, so in
  dense areas the best-rated pill wins and the rest degrade to dots. Unrated
  cafes are filtered out (dot only).
- `cafe-pills-selected` / `cafe-coffee-selected` — enlarged duplicate pill /
  coffee badge pinned to the selected cafe id via `setFilter`
  (`maplibre_gl` doesn't expose `setFeatureState`).

`MapPinImages` (`presentation/utils/map_pin_images.dart`) rasterizes one pill
per distinct rating/review-count combo at 3× and registers it with
`controller.addImage`, cached in a set. Icon size compensates per platform:
Android registers raw pixels at pixel-ratio 1, iOS at the device scale.

Tapping any pin layer (`onFeatureTapped`) selects the cafe and shows the
existing `CafeOverlayCard`; selection no longer moves the camera. After a
refetch the selection survives if the cafe is still in view, else it clears.

## Camera

- First data load fits the camera to the fetched pins (single cafe → zoom
  15.5; else bounds + 60px padding). The camera-idle that follows triggers
  the first viewport fetch, upgrading the initial 20-row list to the full
  area.
- The my-location FAB keeps the pre-existing permission flow and enters
  tracking mode; the resulting camera idle refetches around the user.
