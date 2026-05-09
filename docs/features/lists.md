# Lists

> **Status:** 🚧 In Progress / ✅ Done / ❓ Unclear
> **Last updated:** 2026-05-08

---

## Overview
Lists let users organize cafes into Favorites and custom collections. The feature powers the Lists tab, list detail screens, and the Save to... sheet from cafe details, keeping list membership synced with Supabase and cached for quick access.

---

## User Story
> As a **signed-in user**, I want to **save cafes into named lists** so that **I can organize and revisit my favorite places**.

---

## Screens & Entry Points

| Screen / Widget | Role | Route |
|---|---|---|
| `ListsPage` | Lists tab overview + create/edit/delete | Main tab index 2 (no named route) |
| `ListDetailPage` | Shows cafes in a selected list | `Navigator.push` (MaterialPageRoute) |
| `SaveToListBottomSheet` | Add/remove cafe from lists | Modal bottom sheet from cafe details |

---

## State Management

**BLoC:** `ListsBloc`
**File:** `lib/features/lists/bloc/lists_bloc.dart`

| | Name | Trigger / Meaning | Payload / Fields |
|---|---|---|---|
| **Event** | `LoadUserLists` | Lists tab entry / refresh | — |
| **Event** | `LoadListCafes` | List detail open | `listId: String` |
| **Event** | `CreateList` | Create list dialog submit | `name, description?, isPublic` |
| **Event** | `UpdateList` | Edit list dialog submit | `listId, name, description?, isPublic` |
| **Event** | `DeleteList` | Delete confirmation | `listId` |
| **Event** | `AddCafeToList` | Add cafe to list | `listId, cafeId` |
| **Event** | `RemoveCafeFromList` | Remove cafe from list | `listId, cafeId` |
| **State** | `ListsInitial` | Not yet loaded | — |
| **State** | `ListsLoading` | Fetch in progress | — |
| **State** | `ListsLoaded` | Lists loaded | `lists: List<CafeList>` |
| **State** | `ListCafesLoaded` | Cafes for list loaded | `list: CafeList, cafes: List<CafeSummary>` |
| **State** | `ListsError` | Fetch failed | `error: Object` |

**Cubit:** `SaveToListCubit`
**File:** `lib/features/lists/presentation/cubit/save_to_list_cubit.dart`

| | Name | Trigger / Meaning | Payload / Fields |
|---|---|---|---|
| **State** | `SaveToListLoading` | Initial sheet load | — |
| **State** | `SaveToListLoaded` | Sheet ready | `lists, savedListIds, pendingListIds, isCreating` |
| **State** | `SaveToListError` | Load failed | `error: Object` |

---

## Data Flow

```
User Action (open Lists tab / Save to...)
  → Event/Cubit call dispatched
    → ListsBloc / SaveToListCubit calls use cases
      → Use case calls ICafeRepository
        → Repository calls CafeRemoteDataSource
          → Supabase tables / RPC
      → Entities mapped (CafeList / CafeSummary)
    → State emitted
  → UI rebuilds
```

---

## Supabase

| Type | Name | Params | Returns | Notes |
|---|---|---|---|---|
| Table | `list_members` | `user_id`, `role=owner` | list metadata join | Default list uses `is_default` |
| Table | `lists` | — | list metadata | Update/delete list, cover image refresh |
| Table | `list_cafes` | `list_id`, `cafe_id` | memberships | Add/remove cafes from lists |
| Table | `cafes` | — | `featured_image_url` | Used for list cover image |
| RPC | `create_new_list` | `list_name`, `list_description`, `list_is_public` | `String` list id | Creates list + default membership |

---

## Key Widgets

| Widget | File | Responsibility |
|---|---|---|
| `ListsPage` | `presentation/pages/list_page.dart` | Lists tab UI, create/edit/delete lists |
| `ListDetailPage` | `presentation/pages/list_detail_page.dart` | Renders cafes in a list |
| `SaveToListBottomSheet` | `presentation/widgets/save_to_list_bottom_sheet.dart` | Save/remove cafes across lists |
| `ListOptionsBottomSheet` | `presentation/widgets/list_options_bottom_sheet.dart` | Edit/delete actions for a list |

---

## Packages

| Package | Why |
|---|---|
| `flutter_bloc` | ListsBloc + SaveToListCubit state management |
| `supabase_flutter` | Lists CRUD and membership queries |
| `cached_network_image` | List cover thumbnails in Save to... sheet |
| `skeletonizer` | Loading placeholders in Save to... sheet |
| `shared_preferences` | Persist last saved list id |
| `go_router` | Redirect to login on session-expired errors |

---

## Edge Cases & Errors

- **Empty lists** — Lists tab prompts to create a list; Save to... sheet shows guidance.
- **Session expired** — Error widget redirects to `/login`.
- **Default list missing** — Favorites card triggers reload and shows toast if id not resolved.
- **Create list validation** — Empty name throws `ArgumentError` in `CreateListUseCase`.
- **Save/remove failures** — Save to... sheet shows toast and rolls back optimistic state.

---

## Open Questions

- [ ] Should `fetchUserLists()` include `last_saved_at` to drive Save to... sorting?
- [ ] Confirm whether list detail should use named routes instead of `MaterialPageRoute`.
- [ ] Do we need a dedicated empty-state image for the Lists tab?
