# Repositories

> **Status:** 🚧 In Progress
> **Last updated:** 2026-05-08

---

## 1. What This Document Covers

Repository contracts (abstract classes) and their implementations —
the layer between BLoCs and data sources.

---

## 2. What Is a Repository

Repositories define *what* the app can do with data, not *how*.
The abstract class is the contract; the impl handles the how.
BLoCs depend on the abstract class — never the impl directly.

```
BLoC → ICafeRepository (abstract)
              └── CafeRepositoryImpl
                    └── CafeRemoteDataSource
```

This makes BLoCs testable without a real Supabase connection.

---

## 3. `ICafeRepository`

**Contract:** `lib/core/cafe/domain/repositories/i_cafe_repository.dart`
**Impl:** `lib/core/cafe/data/cafe_repository_impl.dart`

### Contract

```dart
abstract class ICafeRepository {
  Future<List<CafeSummary>> getCafes(CafeQuery query);
  Future<CafeDetails> getCafeDetailsById(String cafeId);
  Future<CafeBundle> getCafeBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  });
  Future<List<Review>> getCafeReviewsById(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  });
  Future<List<WrittenReview>> getReviewsWrittenByUser(String userId);
  Future<void> toggleHelpfulVote(
    String reviewId,
    String userId,
    bool currentlyVoted,
  );
  Future<Review> addCafeReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  });
  Future<String> getDefaultListId();
  Future<List<CafeList>> getUserLists();
  Future<List<CafeSummary>> getListCafes(String listId);
  Future<Set<String>> getCafeListMemberships(
    String cafeId,
    List<String> listIds,
  );
  Future<bool> isCafeInList(String listId, String cafeId);
  Future<bool> isCafeSavedToAnyUserList(String cafeId);
  Future<void> addCafeToList(String listId, String cafeId);
  Future<void> removeCafeFromList(String listId, String cafeId);
  Future<void> removeCafeFromAllUserLists(String cafeId);
  Future<String> createList({
    required String name,
    String? description,
    required bool isPublic,
  });
  Future<void> deleteList(String listId);
  Future<void> updateList(
    String listId, {
    required String name,
    String? description,
    required bool isPublic,
  });
  Future<void> warmCache(List<CafeSummary> summaries);
}
```

### Implementation Notes

- Uses `CafeRemoteDataSource` for all network access.
- Caches `CafeBundle` in `CafeStore` for `getCafeBundleById` and `warmCache`.
- Maps model results to domain entities (`CafeDetails`, `CafeBundle`, `Review`).

### Method Map

| Method | Calls DataSource | Uses Cache | Returns Entity |
|---|---|---|---|
| `getCafes()` | ✅ | ❌ | `List<CafeSummary>` |
| `getCafeDetailsById()` | ✅ | ❌ | `CafeDetails` |
| `getCafeBundleById()` | ✅ | ✅ | `CafeBundle` |
| `getCafeReviewsById()` | ✅ | ❌ | `List<Review>` |
| `getReviewsWrittenByUser()` | ✅ | ❌ | `List<WrittenReview>` |
| `toggleHelpfulVote()` | ✅ | ❌ | `void` |
| `addCafeReview()` | ✅ | ❌ | `Review` |
| `getDefaultListId()` | ✅ | ❌ | `String` |
| `getUserLists()` | ✅ | ❌ | `List<CafeList>` |
| `getListCafes()` | ✅ | ❌ | `List<CafeSummary>` |
| `getCafeListMemberships()` | ✅ | ❌ | `Set<String>` |
| `isCafeInList()` | ✅ | ❌ | `bool` |
| `isCafeSavedToAnyUserList()` | ✅ (via repo calls) | ❌ | `bool` |
| `addCafeToList()` | ✅ | ❌ | `void` |
| `removeCafeFromList()` | ✅ | ❌ | `void` |
| `removeCafeFromAllUserLists()` | ✅ | ❌ | `void` |
| `createList()` | ✅ | ❌ | `String` |
| `deleteList()` | ✅ | ❌ | `void` |
| `updateList()` | ✅ | ❌ | `void` |
| `warmCache()` | ❌ | ✅ | `void` |

---

## 4. `ICafeTagsRepository`

**Contract:** `lib/features/map/domain/repositories/i_cafe_tags_repository.dart`
**Impl:** `lib/features/map/data/repositories/cafe_tags_repository_impl.dart`

### Method Map

| Method | Calls DataSource | Returns Entity |
|---|---|---|
| `filterTags()` | ✅ | `List<CafeTagsEntity>` |

---

## 5. `AuthRepository`

**Contract:** `lib/features/auth/domain/repository/auth_repository.dart`
**Impl:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

### Method Map

| Method | Calls DataSource | Returns |
|---|---|---|
| `emailExists()` | ✅ | `bool` |
| `signUp()` | ✅ | `AuthResponse` |
| `signIn()` | ❌ (Supabase direct) | `AuthResponse` |
| `signOut()` | ✅ | `void` |
| `signInWithGoogle()` | ✅ | `Either<Failure, void>` |
| `signInWithApple()` | ✅ | `Either<Failure, void>` |
| `getCurrentSession()` | ❌ (Supabase direct) | `Session?` |

---

## 6. `IReviewImageUploadRepository`

**Contract:** `lib/core/upload/domain/repositories/i_review_image_upload_repository.dart`
**Impl:** `lib/core/upload/data/review_image_upload_repository_impl.dart`

### Method Map

| Method | Calls DataSource | Returns Entity |
|---|---|---|
| `uploadReviewImages()` | ✅ | `List<UploadedReviewImage>` |

---

## 7. Model → Entity Mapping

Data sources return **Models** (JSON-shaped). Repositories map them to **Entities**
(domain-shaped, no Supabase coupling).

```dart
// Model (data layer)
class ReviewModel {
  final String id;
  final String cafeId;
  final String userId;
  final int rating;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String name;
  final int helpfulCount;
  final bool hasVoted;
}

// Repository mapping (data -> domain)
Review toEntity(ReviewModel item) => Review(
  id: item.id,
  cafeId: item.cafeId,
  userId: item.userId,
  rating: item.rating,
  content: item.content,
  imageUrls: item.imageUrls,
  createdAt: item.createdAt,
  updatedAt: item.updatedAt,
  name: item.name,
  helpfulCount: item.helpfulCount,
  hasVoted: item.hasVoted,
);
```

---

## 8. Open Questions

- [ ] _Is there a domain/entity layer or do models double as entities in some flows?_ 
- [ ] _Should `AuthRepositoryImpl.signIn()` and `getCurrentSession()` move into the auth remote data source for consistency?_ 
- [ ] _Is caching handled only in `CafeRepositoryImpl` or do other repos need it?_ 
- [ ] _Add more as you go_ 
