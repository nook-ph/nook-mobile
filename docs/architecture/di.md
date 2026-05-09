# Dependency Injection (`get_it`)

> **Status:** 🚧 In Progress
> **Last updated:** 2026-05-08

---

## 1. What This Document Covers

How `get_it` is configured in Nook — what is registered, in what order,
and how dependencies are resolved across the app.

---

## 2. Setup

**File:** `lib/injection_container.dart`

```dart
final sl = GetIt.instance;

Future<void> initDependencies() async {
  // registrations go here
}
```

`initDependencies()` is called in `main.dart` before `runApp()`.

---

## 3. Registration Map

Document every registration here as you find them.

### External / Third-Party

| Name | Type | Registration |
|---|---|---|
| `SupabaseClient` | Singleton | `sl.registerLazySingleton(...)` |
| `AnalyticsService` | Singleton | `sl.registerLazySingleton(...)` |
| `http.Client` | Singleton | `sl.registerLazySingleton(...)` |
| `ShareService` | Singleton | `sl.registerLazySingleton(...)` |

### Data Sources

| Name | Type | Registration |
|---|---|---|
| `CafeStore` | Singleton | `sl.registerLazySingleton(...)` |
| `CafeRemoteDataSource` | Singleton | `sl.registerLazySingleton(...)` |
| `ReviewImageUploadRemoteDataSource` | Singleton | `sl.registerLazySingleton(...)` |
| `CafeTagsRemoteDataSource` | Singleton | `sl.registerLazySingleton(...)` |

### Repositories

| Name | Type | Registration |
|---|---|---|
| `ICafeRepository` | Singleton | `sl.registerLazySingleton(...)` |
| `IReviewImageUploadRepository` | Singleton | `sl.registerLazySingleton(...)` |
| `ICafeTagsRepository` | Singleton | `sl.registerLazySingleton(...)` |

### Use Cases

| Name | Type | Registration |
|---|---|---|
| `GetCafeCardUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `GetHomeFeedUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `GetCafesUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `GetCafeDetailsUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `GetCafeReviewsUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `GetReviewsWrittenByUserUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `AddReviewUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `UploadReviewImagesUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `GetUserListsUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `AddCafeToListUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `RemoveCafeFromListUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `CreateListUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `GetCafeListMembershipsUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `ResolveQuickSaveListUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `GetFilterTagsUseCase` | Singleton | `sl.registerLazySingleton(...)` |
| `SearchCafesUseCase` | Singleton | `sl.registerLazySingleton(...)` |

### BLoCs / Cubits

| Name | Type | Registration |
|---|---|---|
| `MapBloc` | Factory | `sl.registerFactory(...)` |
| `HomeBloc` | Factory | `sl.registerFactory(...)` |
| `CafeDetailsBloc` | Factory | `sl.registerFactory(...)` |
| `ReviewsBloc` | Factory | `sl.registerFactory(...)` |
| `ReviewSubmitBloc` | Factory | `sl.registerFactory(...)` |
| `SaveToListCubit` | Factory | `sl.registerFactory(...)` |
| `SearchBloc` | Factory | `sl.registerFactory(...)` |
| `ListsBloc` | Singleton | `sl.registerLazySingleton(...)` |
| `FilterCubit` | Singleton | `sl.registerLazySingleton(...)` |

> BLoCs are usually `registerFactory` (new instance per page).
> Repos and data sources are usually `registerLazySingleton`.

---

## 4. How to Resolve Dependencies

```dart
// In a widget or page
final cafeRepo = sl<ICafeRepository>();

// Providing a BLoC to a subtree
BlocProvider(
  create: (_) => sl<SearchBloc>(),
  child: ...,
)
```

---

## 5. Dependency Graph

```
SupabaseClient
  └── CafeRemoteDataSource
        └── ICafeRepository
              └── GetCafeDetailsUseCase
                    └── CafeDetailsBloc
                          └── UI
```

> Extend this as you map out more of the graph.

---

## 6. Open Questions

- [ ] Is there a separate DI file per feature or one central file?
- [ ] Are BLoCs registered globally or provided per-route?
- [ ] Auth DI uses `AuthInjection` instead of `get_it` (confirm if this is intended long-term).
- [ ] Add more as you go.
