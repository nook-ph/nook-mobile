# Supabase Integration

> **Status:** ✅ Done
> **Last updated:** 2026-05-08

---

## 1. What This Document Covers

How the Supabase client is initialized, how RPCs are called and typed,
and how Supabase Auth is wired into the app.

---

## 2. Client Initialization

**File:** `lib/main.dart`

```dart
await dotenv.load(fileName: ".env");

await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL']!,
  anonKey: dotenv.env['SUPABASE_KEY']!,
);

// Accessing the client anywhere
final supabase = Supabase.instance.client;
```

> Env vars are loaded via `flutter_dotenv` in `lib/main.dart` from `.env`.

---

## 3. RPC Pattern

All database functions are called via `.rpc()` and cast from `dynamic`.

```dart
// Generic RPC call
final response = await supabase.rpc(
  'function_name',
  params: { 'param_key': value },
);

// With type casting
final List raw = await supabase.rpc(
  'get_reviews_with_vote_status',
  params: {
    'p_cafe_id': cafeId,
    'p_user_id': userId,
    'p_sort': sort,
    'p_rating_filter': ratingFilter,
  },
);
final reviews = raw
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .map(ReviewModel.fromJson)
    .toList();
```

**Common RPC error — type mismatch:**
> PostgreSQL parameter types must exactly match what the RPC expects.
> A common fix is explicit casting: `params: { 'p_user_id': userId.toString() }`.

---

## 4. RPC Inventory

| Function Name | Purpose | Key Params | Returns |
|---|---|---|---|
| `get_cafes` | Fetch cafe list with filters | `query`, `tags`, `sort`, `lat`, `lng`, `user_id`, `page`, `limit` | `List<CafeSummaryModel>` |
| `get_reviews_with_vote_status` | Reviews + helpful vote state | `p_cafe_id`, `p_user_id`, `p_sort`, `p_rating_filter` | `List<ReviewModel>` |
| `get_menu_items` | Menu items for a cafe | `p_cafe_id` | `List<Map>` (nullable) |
| `create_new_list` | Create a list | `list_name`, `list_description`, `list_is_public` | `String` (list id) |
| `filter_tags` | Fetch filter tags | _none_ | `List<CafeTagsModel>` |
| `check_email_exists` | Check if email exists | `check_email` | `bool` |
| `is_username_available` | Validate username availability | `p_username` | `bool` |
| `set_username` | Persist username | `p_username` | `void` |

---

## 5. Auth Integration

```dart
// Sign up
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {'full_name': name},
);

// Sign in
await supabase.auth.signInWithPassword(email: email, password: password);

// OAuth (Apple)
await supabase.auth.signInWithOAuth(
  OAuthProvider.apple,
  redirectTo: 'nookapp://login-callback',
);

// OAuth (Google via ID token)
await supabase.auth.signInWithIdToken(
  provider: OAuthProvider.google,
  idToken: idToken,
  accessToken: accessToken,
);

// Sign out
await supabase.auth.signOut(scope: SignOutScope.global);

// Current session
final session = supabase.auth.currentSession;
final user = supabase.auth.currentUser;

// Listen to auth state changes
supabase.auth.onAuthStateChange.listen((data) {
  final event = data.event;  // AuthChangeEvent
  final session = data.session;
});
```

---

## 6. Table Queries (non-RPC)

Direct `.from().select()` queries are used for profile, cafe, review, and list
data.

```dart
// Cafe details with nested tags
await supabase
    .from('cafes')
    .select('id, name, address, cafe_tags ( tags ( name ) )')
    .eq('id', cafeId)
    .single();

// Reviews written by a user
await supabase
    .from('reviews')
    .select('id, cafe_id, rating, content, created_at')
    .eq('user_id', userId)
    .order('created_at', ascending: false);

// Helpful vote toggle
await supabase.from('review_helpful_votes').insert({
  'review_id': reviewId,
  'user_id': userId,
});
```

---

## 7. Storage

No Supabase Storage buckets are referenced in code. Review image uploads use a
custom presigned upload API (see `ReviewImageUploadRemoteDataSource`) and pass a
Supabase access token for auth.

| Bucket | Purpose | Access |
|---|---|---|
| _None_ | _N/A_ | _N/A_ |

---

## 8. Open Questions

- [ ] _Are there any Realtime subscriptions in use? (none found in code search)_
- [ ] _Any Supabase Storage usage planned, or will uploads stay presigned-only?_
