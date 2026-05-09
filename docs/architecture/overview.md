# Error Handling Strategy

> **Status:** In Progress
> **Last updated:** 2026-05-08

---

## 1. What This Document Covers

How errors are caught, transformed, and surfaced to the user, from Supabase
all the way up to the UI.

---

## 2. Error Propagation Flow

```
Supabase throws AuthException / PostgrestException (or network/timeout errors)
	-> DataSource catches PostgrestException and throws CafeFetchException
		-> Repository generally passes exceptions through unchanged
			-> BLoC catches and emits feature-specific error state or message
				-> UI maps raw error to ErrorInfo via AppErrorCopy for display
```

---

## 3. Failure / Exception Types

There is no shared Failure hierarchy. Error handling relies on concrete
exceptions and a small UI-facing mapping layer.

```dart
// User-facing error classification
enum ErrorType { offline, sessionExpired, serverError, unknown }

class ErrorInfo {
	const ErrorInfo({required this.type, required this.title, required this.subtitle});
	final ErrorType type;
	final String title;
	final String subtitle;
}
```

See [lib/core/utils/error_info.dart](lib/core/utils/error_info.dart).

```dart
class CafeFetchException implements Exception {
	final String message;
	final Object? cause;
	final StackTrace? stackTrace;
	const CafeFetchException(this.message, {this.cause, this.stackTrace});
}
```

See [lib/core/cafe/data/cafe_remote_data_source.dart](lib/core/cafe/data/cafe_remote_data_source.dart).

Mapping to UI copy is centralized in `AppErrorCopy`, which classifies
`SocketException`, `TimeoutException`, `AuthException`, and
`PostgrestException` into `ErrorType` values.
See [lib/core/utils/app_error_copy.dart](lib/core/utils/app_error_copy.dart).

---

## 4. DataSource Layer

The data source wraps Supabase errors into `CafeFetchException` with context.

```dart
Future<List<CafeSummaryModel>> fetchCafes({required CafeQuery query}) async {
	final params = query.toRpcParams();

	try {
		final rpcResponse = await supabase.rpc('get_cafes', params: params);
		final response = (rpcResponse as List)
				.whereType<Map>()
				.map((item) => Map<String, dynamic>.from(item))
				.toList();
		return response.map((json) => CafeSummaryModel.fromJson(json)).toList();
	} on PostgrestException catch (e, st) {
		throw CafeFetchException(
			'Failed to fetch cafe summaries for sort "${query.sort}".',
			cause: e,
			stackTrace: st,
		);
	} catch (e, st) {
		if (e is CafeFetchException) rethrow;
		throw CafeFetchException(
			'Failed to fetch cafe summaries for sort "${query.sort}".',
			cause: e,
			stackTrace: st,
		);
	}
}
```

See [lib/core/cafe/data/cafe_remote_data_source.dart](lib/core/cafe/data/cafe_remote_data_source.dart).

---

## 5. Repository Layer

Repositories generally pass exceptions through without translating them.

```dart
@override
Future<List<CafeSummary>> getCafes(CafeQuery query) async {
	return remoteDataSource.fetchCafes(query: query);
}
```

See [lib/core/cafe/data/cafe_repository_impl.dart](lib/core/cafe/data/cafe_repository_impl.dart).

---

## 6. BLoC Layer

Blocs catch exceptions and emit feature-specific error states:

- `HomeBloc` -> `HomeError(e)`
- `SearchBloc` -> `SearchStatus.failure` with `lastError: e`
- `CafeDetailsBloc` -> `CafeDetailsError(e)`
- `ReviewsBloc` -> `ReviewsError(e.toString())`
- `ReviewSubmitBloc` -> `ReviewSubmitError(_mapErrorMessage(e))`
- `AuthBloc` maps `AuthException` and `PostgrestException` to friendly strings

Example (Search):

```dart
} catch (e, st) {
	debugPrint('SearchBloc: fetch cafes failed $e');
	debugPrint(st.toString());
	emit(
		state.copyWith(
			status: SearchStatus.failure,
			lastError: e,
			locationDenied: false,
		),
	);
}
```

See [lib/features/search/bloc/search_bloc.dart](lib/features/search/bloc/search_bloc.dart) and
[lib/features/auth/presentation/bloc/auth_bloc.dart](lib/features/auth/presentation/bloc/auth_bloc.dart).

---

## 7. UI Layer

UI layers translate raw errors to user copy using `AppErrorCopy` and render
either full-page or section error widgets.

- `HomePage`, `SearchResultsPage`, and `CafeDetailsPage` call
	`AppErrorCopy.fromException(...)` and show `FullPageErrorWidget`.
- Section-level errors use `SectionErrorWidget` when applicable.
- `sessionExpired` errors route users to login.

See [lib/features/home_page/presentation/pages/home_page.dart](lib/features/home_page/presentation/pages/home_page.dart),
[lib/features/search/presentation/pages/search_results_page.dart](lib/features/search/presentation/pages/search_results_page.dart),
[lib/features/cafe_details/presentation/pages/cafe_details_page.dart](lib/features/cafe_details/presentation/pages/cafe_details_page.dart),
[lib/core/widgets/error/full_page_error_widget.dart](lib/core/widgets/error/full_page_error_widget.dart), and
[lib/core/widgets/error/section_error_widget.dart](lib/core/widgets/error/section_error_widget.dart).

---

## 8. Global Error Handling

There is no global `FlutterError.onError` or `runZonedGuarded` handler in
`main.dart` today.
See [lib/main.dart](lib/main.dart).

---

## 9. Open Questions

- [ ] Should we add a global error handler (FlutterError.onError / runZonedGuarded)?
- [ ] Should we unify exception types beyond CafeFetchException?
- [ ] Should ReviewSubmitBloc emit ErrorInfo instead of a string to align with AppErrorCopy?
