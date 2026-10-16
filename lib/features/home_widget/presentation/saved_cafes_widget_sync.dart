import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/analytics/home_widget_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/presentation/cubit/account_want_to_try_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/home_widget/data/home_widget_platform.dart';
import 'package:nook/features/home_widget/data/widget_promo_store.dart';
import 'package:nook/features/home_widget/domain/saved_cafes_widget_data.dart';
import 'package:nook/features/home_widget/domain/widget_promo_rules.dart';
import 'package:nook/features/home_widget/presentation/widget_links.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// The Want to try cafes the widget is showing, for the Saved tab's "Add
/// widget" card (its count and its preview). Null until first worked out.
final ValueNotifier<List<WidgetCafe>?> savedCafesWidgetFeed = ValueNotifier(
  null,
);

/// Keeps the home-screen widget "Your saved cafes" in step with the app,
/// app-wide: on start, on resume, whenever the Want to try list changes
/// (a guest's saves on this phone, or the account's list once signed in),
/// on sign-in and sign-out, and when a position arrives (for distances; it
/// never asks for one).
///
/// Each write lays out the coming week ([SavedCafesWidgetData]) and redraws
/// the widget, which then arms its own alarm for the next moment a saved
/// cafe opens or closes (`SavedCafesWidgetProvider.armNextTurnover`), so
/// "open now" stays true while the app is closed.
class SavedCafesWidgetSync extends StatefulWidget {
  const SavedCafesWidgetSync({
    super.key,
    required this.child,
    this.platform = const HomeWidgetPluginPlatform(),
    this.isSignedIn,
    this.repository,
    this.store,
  });

  final Widget child;
  final HomeWidgetPlatform platform;

  /// Defaults to the Supabase session; tests pass their own.
  final bool Function()? isSignedIn;
  final ICafeRepository? repository;
  final WidgetPromoStore? store;

  @override
  State<SavedCafesWidgetSync> createState() => _SavedCafesWidgetSyncState();
}

class _SavedCafesWidgetSyncState extends State<SavedCafesWidgetSync>
    with WidgetsBindingObserver {
  static const _debounce = Duration(milliseconds: 400);

  AccountWantToTryCubit? _account;
  StreamSubscription<List<CafeSummary>>? _accountSub;
  StreamSubscription<Uri?>? _clicks;

  /// The account's list has been read at least once since sign-in, so an
  /// empty one means empty rather than not loaded yet.
  bool _accountLoaded = false;
  Timer? _timer;
  String? _lastJson;

  bool get _enabled => widget.platform.isSupported;

  bool get _signedIn =>
      widget.isSignedIn?.call() ??
      Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    final repository =
        widget.repository ??
        (sl.isRegistered<ICafeRepository>() ? sl<ICafeRepository>() : null);
    if (repository != null) {
      final account = AccountWantToTryCubit(repository: repository);
      _account = account;
      _accountSub = account.stream.listen((_) {
        _accountLoaded = true;
        _queue();
      });
    }
    DeviceLocation.instance.position.addListener(_queue);
    unawaited(
      widget.platform.launchLink().then(
        WidgetLinks.acceptFromPlatform,
        onError: (Object e) => debugPrint('[SavedCafesWidget] launch: $e'),
      ),
    );
    _clicks = widget.platform.clicks.listen(WidgetLinks.acceptFromPlatform);
    unawaited(context.read<GuestSavesCubit>().load().then((_) => _queue()));
    _loadAccount();
    unawaited(_checkInstalled());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_enabled) {
      WidgetsBinding.instance.removeObserver(this);
      DeviceLocation.instance.position.removeListener(_queue);
    }
    _accountSub?.cancel();
    _clicks?.cancel();
    _account?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // A week ahead from now, and the account's list may have changed on
    // another phone.
    _lastJson = null;
    _loadAccount();
    _queue();
    unawaited(_checkInstalled());
  }

  void _loadAccount({List<CafeList>? lists}) {
    final account = _account;
    if (account == null) return;
    if (!_signedIn) {
      _accountLoaded = false;
      account.clear();
      return;
    }
    unawaited(account.load(lists: lists ?? _listsInHand()));
  }

  List<CafeList>? _listsInHand() {
    try {
      final lists = context.read<ListsBloc>().userLists;
      return lists.isEmpty ? null : lists;
    } catch (_) {
      return null;
    }
  }

  void _queue() {
    if (!mounted || !_enabled) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_write()));
  }

  /// The Want to try cafes, newest first; null while not known yet (so the
  /// widget is not wiped to empty during start-up).
  List<CafeSummary>? _wantToTry() {
    if (_signedIn) {
      final account = _account;
      if (account == null || !_accountLoaded) return null;
      return account.state;
    }
    final guest = context.read<GuestSavesCubit>().state;
    if (!guest.loaded) return null;
    return [
      for (final s in guest.withStatus(CafeStatus.wantToTry))
        s.cafe.toSummary(),
    ];
  }

  Future<void> _write() async {
    if (!mounted) return;
    final cafes = _wantToTry();
    if (cafes == null) return;
    final position = DeviceLocation.instance.position.value;
    final widgetCafes = [
      for (final c in cafes)
        WidgetCafe(
          id: c.id,
          name: c.name,
          operatingHours: c.operatingHours,
          distanceMeters: position == null || c.lat == null || c.lng == null
              ? null
              : Geolocator.distanceBetween(
                  position.latitude,
                  position.longitude,
                  c.lat!,
                  c.lng!,
                ),
        ),
    ];
    savedCafesWidgetFeed.value = widgetCafes;

    final data = SavedCafesWidgetData.build(widgetCafes, now: DateTime.now());
    final json = jsonEncode(data.toJson());
    if (json == _lastJson) return;
    _lastJson = json;
    try {
      final platform = widget.platform;
      await platform.write(SavedCafesWidgetData.storageKey, json);
      await platform.redraw();
    } catch (e) {
      _lastJson = null;
      debugPrint('[SavedCafesWidget] write failed: $e');
    }
  }

  /// Logs `widget_installed_count_changed` when the number of widgets on
  /// the home screen differs from the last look.
  Future<void> _checkInstalled() async {
    try {
      final count = await widget.platform.installedCount();
      if (count == null) return;
      final store = widget.store ?? WidgetPromoStore();
      final previous = await store.lastInstalledCount();
      if (previous == count) return;
      await store.setInstalledCount(count);
      // A phone that never had one is not news.
      if (previous == null && count == 0) return;
      final before = previous ?? 0;
      logAppEvent(
        HomeWidgetEvents.countChanged,
        properties: {
          'count': count,
          'previous': before,
          if (count > before)
            'source': WidgetInstallSource.infer(
              lastPinRequest: await store.lastPinRequestAt(),
              now: DateTime.now(),
            ),
        },
      );
    } catch (e) {
      debugPrint('[SavedCafesWidget] installed count failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return MultiBlocListener(
      listeners: [
        BlocListener<GuestSavesCubit, GuestSavesState>(
          listener: (_, _) => _queue(),
        ),
        BlocListener<ListsBloc, ListsState>(
          listenWhen: (_, current) => current is ListsLoaded,
          listener: (_, state) {
            if (state is ListsLoaded) _loadAccount(lists: state.lists);
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              (current is AuthAuthenticated &&
                  previous is! AuthAuthenticated) ||
              current is AuthLoggedOut ||
              current is AuthUnauthenticated ||
              current is AuthAccountDeleted,
          listener: (_, _) {
            _accountLoaded = false;
            _loadAccount();
            _queue();
          },
        ),
      ],
      child: widget.child,
    );
  }
}
