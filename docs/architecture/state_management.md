# State Management (BLoC)

> **Status:** 🚧 In Progress
> **Last updated:** 2026-05-08

---

## 1. What This Document Covers

How BLoC is used across Nook - naming conventions, event/state structure,
and the patterns shared across all features.

---

## 2. Package

```yaml
dependencies:
  flutter_bloc: ^9.1.1
  bloc: (transitive via flutter_bloc)
```

> `bloc` is not listed directly in `pubspec.yaml` today.

---

## 3. Naming Conventions

| Piece | Convention | Example |
|---|---|---|
| BLoC class | `[Feature]Bloc` | `HomeBloc`, `SearchBloc` |
| Cubit class | `[Feature]Cubit` | `FilterCubit`, `SaveToListCubit` |
| Event base class | `[Feature]Event` | `AuthEvent`, `CafeDetailsEvent` |
| State base class | `[Feature]State` | `MapState`, `CafeDetailsState` |
| Event subclass | Mixed: `[Feature][Action]` or `[Action][Feature]Event` | `SearchQueryChanged`, `LoadHomeDataEvent` |
| State subclass | Mixed: `[Feature][Status]State` or `[Status]` | `HomeLoadedState`, `AuthLoading` |
| Enum state | `[Feature]Status` (single state class) | `SearchStatus` within `SearchState` |

> Conventions are not fully consistent across features. Some BLoCs use class-per-state,
> others use a single state object + status enum.

---

## 4. Typical BLoC Structure

```dart
// event
abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

// state
enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<CafeSummary> cafes;

  const SearchState({
    this.status = SearchStatus.initial,
    this.cafes = const [],
  });

  @override
  List<Object?> get props => [status, cafes];
}

// bloc
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({required this.searchCafesUseCase}) : super(const SearchState()) {
    on<SearchQueryChanged>(_onQueryChanged);
  }

  final SearchCafesUseCase searchCafesUseCase;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    // ...
  }
}
```

---

## 5. BLoC Inventory

Document every BLoC/Cubit in the app here.

| BLoC / Cubit | Feature | Key Events | Key States |
|---|---|---|---|
| `AppBloc` | App bootstrap | `AppStarted`, `OnboardingCompleted` | `ShowOnboarding`, `ShowHome` |
| `AuthBloc` | Auth | `AuthSignInEvent`, `AuthSignOutEvent`, `AuthSessionCheckEvent` | `AuthLoading`, `AuthAuthenticated`, `AuthUnauthenticated`, `AuthError` |
| `HomeBloc` | Home feed | `LoadHomeDataEvent`, `HomeDismissLocationBannerEvent` | `HomeLoadingState`, `HomeLoadedState`, `HomeError` |
| `MapBloc` | Map | `LoadMapDataEvent`, `LoadFilterTagsEvent` | `MapLoadingState`, `MapLoadedState`, `MapError` |
| `SearchBloc` | Search | `SearchQueryChanged`, `SearchTagsChanged`, `SearchSortChanged`, `SearchRefresh` | `SearchState` (`SearchStatus.*`) |
| `ListsBloc` | Lists | `LoadUserLists`, `AddCafeToList`, `RemoveCafeFromList`, `CreateList` | `ListsLoading`, `ListsLoaded`, `ListCafesLoaded`, `ListsError` |
| `CafeDetailsBloc` | Cafe details | `LoadCafeDetailsRequested` | `CafeDetailsLoading`, `CafeDetailsLoaded`, `CafeDetailsError` |
| `ReviewsBloc` | Cafe reviews | `LoadReviewsRequested` | `ReviewsLoading`, `ReviewsLoaded`, `ReviewsError` |
| `ReviewSubmitBloc` | Review submission | `SubmitReviewRequested` | `ReviewSubmitting`, `ReviewSubmitSuccess`, `ReviewSubmitError` |
| `OnboardingBloc` | Onboarding | `PageChanged` | `OnboardingState` |
| `NavigationBloc` | Navigation tabs | `TabChange` | `NavigationState` |
| `FilterCubit` | Filters | Methods: `setSingleTag`, `setFilter`, `reset` | `CafeFilter` |
| `SaveToListCubit` | Save to list | Methods: `load`, `toggleList`, `createListAndSave` | `SaveToListInitial`, `SaveToListLoading`, `SaveToListLoaded`, `SaveToListError` |
| `ProfileCubit` | Profile | Methods: `loadProfile`, `clear` | `ProfileLoading`, `ProfileLoaded`, `ProfileError`, `ProfileUnauthenticated` |

---

## 6. How BLoCs Are Provided to the Widget Tree

```dart
// Root-level providers (main.dart)
MultiBlocProvider(
  providers: [
    BlocProvider<AppBloc>(create: (_) => AppBloc()..add(AppStarted())),
    BlocProvider<ListsBloc>(create: (_) => sl<ListsBloc>()),
    BlocProvider<FilterCubit>(create: (_) => sl<FilterCubit>()),
    BlocProvider<AuthBloc>(
      create: (context) =>
          AuthInjection.createAuthBloc(listsBloc: context.read<ListsBloc>())
            ..add(const AuthSessionCheckEvent()),
    ),
  ],
  child: ...,
)

// Per-route or per-page providers (typical)
BlocProvider(
  create: (_) => sl<SearchBloc>(),
  child: SearchResultsPage(),
)
```

> Root providers are defined in `main.dart`. Feature BLoCs are typically
> provided per-route using `BlocProvider` + `get_it`.

---

## 7. How UI Reacts to State

```dart
BlocBuilder<HomeBloc, HomeState>(
  builder: (context, state) {
    if (state is HomeLoadingState) return const CircularProgressIndicator();
    if (state is HomeLoadedState) return HomeFeed(state);
    if (state is HomeError) return ErrorWidget(state.error.toString());
    return const SizedBox.shrink();
  },
)

// For one-off side effects (snackbars, navigation)
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  },
)
```

---

## 8. Open Questions

- [ ] Are any feature BLoCs provided globally outside `main.dart`?
- [ ] Where is `NavigationBloc` provided (router shell, tab scaffold, or root)?
- [ ] Should BLoC naming be standardized (event/state suffixes, enum pattern)?
