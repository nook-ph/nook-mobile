# Data Sources

> **Status:** 🚧 In Progress
> **Last updated:** 2026-05-08

---

## 1. What This Document Covers

All remote data sources in the app. It documents what each one does,
what Supabase calls it makes, and how it's consumed by repositories.

---

## 2. What Is a Data Source

Data sources are the lowest app-level layer. They talk directly to Supabase
(RPCs, table queries, auth) or other remote APIs. They return raw models or
DTO-shaped maps. Repositories call them and map results to domain entities.

```
Repository
  └── RemoteDataSource
        └── Supabase (RPC / table / auth) or other HTTP APIs
```

---

## 3. `CafeRemoteDataSource`

**File:** `lib/core/cafe/data/cafe_remote_data_source.dart`

### Responsibility
Fetches all cafe, review, and list-related data from Supabase.

### Methods

| Method | Supabase Call | Returns | Notes |
|---|---|---|---|
| `fetchCafes()` | `rpc('get_cafes')` | `List<CafeSummaryModel>` | Uses `CafeQuery.toRpcParams()` |
| `fetchDetailsById()` | `.from('cafes').select(...).single()` | `CafeDetailsModel` | Includes tags + menu items |
| `fetchBundleById()` | `.from('cafes').select(...).single()` | `CafeBundleModel` | Optional menu + reviews |
| `fetchReviewsByCafeId()` | `rpc('get_reviews_with_vote_status')` | `List<ReviewModel>` | Uses user id for vote state |
| `fetchReviewsWrittenByUser()` | `.from('reviews').select(...).order(...)` | `List<Map<String, dynamic>>` | Includes cafe name |
| `toggleHelpfulVote()` | `.from('review_helpful_votes').insert/delete()` | `void` | Upserts by user + review |
| `insertReview()` | `.from('reviews').insert(...).select(...).single()` | `ReviewModel` | Returns created review |
| `fetchDefaultListId()` | `.from('list_members').select(...).single()` | `String` | Uses `is_default` |
| `fetchUserLists()` | `.from('list_members').select(...).order(...)` | `List<Map<String, dynamic>>` | Owner lists with list metadata |
| `fetchListCafes()` | `.from('list_cafes').select(...).order(...)` | `List<CafeSummaryModel>` | Joins `cafes` + tags |
| `fetchCafeListMemberships()` | `.from('list_cafes').select(...).inFilter(...)` | `Set<String>` | List ids containing cafe |
| `isCafeInList()` | `.from('list_cafes').select(...).limit(1)` | `bool` | Presence check |
| `addCafeToList()` | `.from('list_cafes').upsert(...)` | `void` | Updates list cover if empty |
| `removeCafeFromList()` | `.from('list_cafes').delete()` | `void` | Refreshes cover image |
| `removeCafeFromAllUserLists()` | `.from('list_cafes').delete()` | `void` | For all owner lists |
| `createList()` | `rpc('create_new_list')` | `String` | Returns new list id |
| `deleteList()` | `.from('lists').delete()` | `void` | Deletes list |
| `updateList()` | `.from('lists').update()` | `void` | Replaces rename list |

### Code Pattern

```dart
class CafeRemoteDataSource {
  final SupabaseClient supabase;

  CafeRemoteDataSource(this.supabase);

  Future<List<CafeSummaryModel>> fetchCafes({required CafeQuery query}) async {
    final params = query.toRpcParams();

    final rpcResponse = await supabase.rpc('get_cafes', params: params);

    final response = (rpcResponse as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return response.map(CafeSummaryModel.fromJson).toList();
  }
}
```

---

## 4. `CafeTagsRemoteDataSource`

**File:** `lib/features/map/data/datasources/cafe_tags_remote_data_source.dart`

### Responsibility
Fetches tag filters for the map experience.

### Methods

| Method | Supabase Call | Returns | Notes |
|---|---|---|---|
| `filterTags()` | `rpc('filter_tags')` | `List<CafeTagsEntity>` | Models mapped via `CafeTagsModel` |

---

## 5. `ReviewImageUploadRemoteDataSource`

**File:** `lib/core/upload/data/review_image_upload_remote_data_source.dart`

### Responsibility
Uploads review images via a custom presigned upload API (not Supabase Storage).

### Methods

| Method | Remote Call | Returns | Notes |
|---|---|---|---|
| `uploadReviewImages()` | `POST {UPLOAD_API_BASE_URL}/{PRESIGN_PATH}` + `PUT S3` | `List<UploadedReviewImage>` | Uses bearer token when available |

### Notes

- Uses a presign endpoint to receive `{ uploadUrl, objectKey, publicUrl }`.
- Uploads bytes directly to S3 with `x-amz-acl: public-read`.

---

## 6. `SupabaseAuthRemoteDataSource`

**File:** `lib/features/auth/data/datasources/supabase_auth_remote_data_source.dart`

### Responsibility
Wraps Supabase Auth calls and a single auth-related RPC.

### Methods

| Method | Supabase Call | Returns | Notes |
|---|---|---|---|
| `checkEmailExists()` | `rpc('check_email_exists')` | `bool` | Email validation on signup |
| `signUp()` | `auth.signUp()` | `AuthResponse` | Adds `full_name` in user metadata |
| `signInWithPassword()` | `auth.signInWithPassword()` | `void` | Email/password login |
| `signInWithApple()` | `auth.signInWithOAuth(apple)` | `void` | Uses `redirectTo` scheme |
| `signInWithGoogle()` | `auth.signInWithIdToken(google)` | `AuthResponse` | Uses Google Sign-In tokens |
| `signOut()` | `auth.signOut()` | `void` | Global sign out |

---

## 7. Supabase Calls Outside Data Sources

These are direct Supabase calls that live outside data sources today.

- `AuthRepositoryImpl.signIn()` calls `auth.signInWithPassword()` directly.
- `AuthRepositoryImpl.getCurrentSession()` reads `auth.currentSession`.
- `AuthBloc` calls `rpc('set_username')` and reads `profiles`.
- `UsernameSetupScreen` calls `rpc('is_username_available')`.

---

## 8. Adding a New Data Source (Checklist)

- [ ] Create abstract class with method signatures (if needed)
- [ ] Create `Impl` class that takes `SupabaseClient` via constructor
- [ ] Wrap all Supabase calls in try/catch and throw typed failures
- [ ] Register in `get_it` as `lazySingleton`
- [ ] Wire into the corresponding repository

---

## 9. Open Questions

- [ ] _Do we want to move `set_username` / `is_username_available` into an auth data source?_ 
- [ ] _Should `AuthRepositoryImpl.signIn()` route through the auth remote data source for consistency?_ 
- [ ] _Any additional data sources planned for profile or search?_ 
