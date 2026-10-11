# Cafe tags · references (ios)

Direction: project theme (`CafeDetailsTokens` in
`lib/features/cafe_details/presentation/widgets/cafe_details_common.dart`).
Researched 2026-10-11 with partwise. Refero's iOS index only had Airbnb for
these parts; Google Maps, Booking, Yelp and Beli returned no usable screens.
The web side of the same change (nook-webapp `docs/references/cafe-tags/`)
used Expedia and Yelp.

Data behind the cap (prod, read-only, 2026-10-11): 49 cafes with tags, median
10 per cafe, p90 19, max 23, before the coffee tags add up to 10 more.

## Tag preview
"What this cafe offers" on the details page: six tags (two each from Coffee,
Best for, Amenities; `CafeTagGroups.preview`) in the existing two-column icon
grid, one column at large text, then "See all N" when there are more.
Built in `lib/features/cafe_details/presentation/widgets/cafe_info.dart`
(`CafeAmenitiesSection`), button `CafeWideButton` in `cafe_details_common.dart`.

**Primary: Airbnb (What this place offers).** Borrow: Airbnb highlights.

| | Product | Taken |
|---|---|---|
| ![](tag-airbnb-preview.png) | [Airbnb](https://refero.design/screens/ae110ae8-c66a-45e0-a287-da23cbf90619) | Heading, a short capped set of icon + label rows, then a full-width button carrying the total ("See all 27"), shown only when there are more |
| ![](tag-airbnb-highlights.png) | [Airbnb highlights](https://refero.design/screens/60143210-1031-47eb-9b1f-e6789ab17fc8) | Long labels wrap to two lines beside the icon instead of truncating |
| ![](tag-airbnb-full.png) | [Airbnb full list](https://refero.design/screens/dfbf7b7d-fa6e-4030-9357-5dbe8966e77f) | See all pushes a full page, not a sheet |

## All tags page
Every group (Coffee, Best for, Amenities, Payment; empty ones left out), each a
heading over icon + label rows split by hairlines; coffee rows carry one line
on what the tag means. Built in
`lib/features/cafe_details/presentation/pages/cafe_tags_page.dart`.

**Primary: Airbnb Amenities.** Borrow: Airbnb (helper lines). Rejected: Google Maps.

| | Product | Taken |
|---|---|---|
| ![](tags-airbnb-amenities.png) | [Airbnb](https://refero.design/screens/dfbf7b7d-fa6e-4030-9357-5dbe8966e77f) | Back arrow, a large left-aligned title, then group headings over icon-left rows with full-width hairlines; more space between groups |
| ![](tags-airbnb-helper.png) | [Airbnb](https://refero.design/screens/d57e0688-0870-43ad-b0ae-229b7a2d84b0) | A gray helper line under the label, only on rows that need one |
| ![](tags-gmaps.png) | [Google Maps](https://refero.design/screens/e329537c-b937-4487-add6-b50f1dcb91cf) | Considered, not taken: group icon in the heading and plain rows with no per-row icon |
