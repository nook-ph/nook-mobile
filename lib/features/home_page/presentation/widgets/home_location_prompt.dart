import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/location/location_prompt_tracking.dart';
import 'package:nook/core/preferences/home_location_prompt_store.dart';
import 'package:nook/core/preferences/location_prompt_store.dart';
import 'package:nook/core/presentation/widgets/confirm_sheet.dart';
import 'package:nook/core/widgets/error/location_denied_banner.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';

/// Whether Home should offer "See cafes near you".
///
/// Only once the user has had something from the app (a second launch, or a
/// cafe opened), never once they turned it down, never if the system prompt
/// was already shown from anywhere (Map and Search share
/// [LocationPromptStore]), and only while the permission can still be asked
/// for: services on and permission `denied`, not `deniedForever`, which the
/// existing banner covers. Counts this launch as a Home visit.
Future<bool> shouldOfferHomeLocation({
  required HomeLocationPromptStore store,
  required LocationPromptStore promptStore,
  required Future<bool> Function() servicesEnabled,
  required Future<LocationPermission> Function() checkPermission,
}) async {
  try {
    final visits = await store.recordHomeVisit();
    if (await store.isDismissed()) return false;
    if (await promptStore.hasRequested()) return false;
    if (visits < 2 && !await store.hasViewedCafe()) return false;
    if (!await servicesEnabled()) return false;
    return await checkPermission() == LocationPermission.denied;
  } catch (_) {
    return false;
  }
}

/// One tracker per launch, so `location_prompt_shown` and the answer go once
/// even if the feed is rebuilt (a retry) and the row with it.
LocationPromptTracker _tracker = LocationPromptTracker(
  LocationPromptSurface.home,
);

@visibleForTesting
void resetHomeLocationPromptLog() =>
    _tracker = LocationPromptTracker(LocationPromptSurface.home);

/// A soft "See cafes near you" row on Home. Home used to never ask for
/// location (only Map did), so "Near you" never appeared for anyone who
/// stayed on Home. Tapping it explains first, then shows the system prompt;
/// [onGranted] then reloads the feed so "Near you" appears.
class HomeLocationPrompt extends StatefulWidget {
  const HomeLocationPrompt({
    super.key,
    required this.onGranted,
    this.store,
    this.promptStore,
    this.servicesEnabled,
    this.checkPermission,
    this.requestPermission,
    this.confirm,
  });

  final VoidCallback onGranted;
  final HomeLocationPromptStore? store;
  final LocationPromptStore? promptStore;
  final Future<bool> Function()? servicesEnabled;
  final Future<LocationPermission> Function()? checkPermission;
  final Future<LocationPermission> Function()? requestPermission;

  /// The explanation before the system prompt; true to go on.
  final Future<bool> Function(BuildContext context)? confirm;

  @override
  State<HomeLocationPrompt> createState() => _HomeLocationPromptState();
}

class _HomeLocationPromptState extends State<HomeLocationPrompt> {
  bool _visible = false;
  bool _busy = false;

  late final HomeLocationPromptStore _store =
      widget.store ??
      (sl.isRegistered<HomeLocationPromptStore>()
          ? sl<HomeLocationPromptStore>()
          : HomeLocationPromptStore());
  late final LocationPromptStore _promptStore =
      widget.promptStore ??
      (sl.isRegistered<LocationPromptStore>()
          ? sl<LocationPromptStore>()
          : LocationPromptStore());

  @override
  void initState() {
    super.initState();
    unawaited(_evaluate());
  }

  Future<void> _evaluate() async {
    final offer = await shouldOfferHomeLocation(
      store: _store,
      promptStore: _promptStore,
      servicesEnabled:
          widget.servicesEnabled ?? Geolocator.isLocationServiceEnabled,
      checkPermission: widget.checkPermission ?? Geolocator.checkPermission,
    );
    if (!offer) return;
    // The row is an ask the first launch it appears, and the saver survey
    // does not stack on it then. After that it is a standing row: counting
    // it every launch would keep the survey away for good from anyone who
    // just leaves it there.
    // Behind a prompt that already took the session (the survey), the
    // first offer is not spent: the next launch counts it.
    // Gone while checking (the feed rebuilt, an error view): never seen,
    // so the one first offer is not used up.
    if (!mounted) return;
    final budget = SessionAskBudget.instance;
    final first =
        !budget.anyShown &&
        await _store.claimFirstOffer().catchError((_) => false);
    _tracker.countsAsPrompt = first;
    if (first) budget.noteShown(SessionAskKind.homeLocationRow);
    if (mounted) setState(() => _visible = true);
  }

  void _dismiss(String result) {
    // Turned down before the system prompt was shown.
    _tracker.result(result, systemPrompt: false);
    unawaited(_store.markDismissed().catchError((_) {}));
    setState(() => _visible = false);
  }

  Future<bool> _confirm(BuildContext context) => showConfirmSheet(
    context,
    title: 'Show cafes near you?',
    message:
        'Nook uses your location to put the closest cafes first and show '
        'how far each one is. It is never shared with cafes.',
    confirmLabel: 'Use my location',
    cancelLabel: 'Not now',
    destructive: false,
  );

  @override
  void didUpdateWidget(covariant HomeLocationPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Home rebuilt (a reload): location may have been allowed elsewhere
    // meanwhile (the saver survey, Map, Settings).
    if (_visible && !_busy) unawaited(_hideIfGranted());
  }

  Future<bool> _granted() async {
    try {
      final permission =
          await (widget.checkPermission ?? Geolocator.checkPermission)();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hideIfGranted() async {
    if (!await _granted()) return false;
    if (mounted && _visible) setState(() => _visible = false);
    return true;
  }

  Future<bool> _ask() async {
    if (_busy) return false;
    // Allowed elsewhere since the row appeared: no sheet for a permission
    // already given; Home only needs to reload.
    if (await _hideIfGranted()) {
      widget.onGranted();
      return true;
    }
    if (_busy || !mounted) return false;
    _busy = true;
    // Tapped: a sheet the person opened, so no score ask on top this
    // session (as for a sign-in sheet they open), whatever launch this is.
    SessionAskBudget.instance.blockScoreAsks(SessionAskKind.homeLocationAsk);
    try {
      final go = await (widget.confirm ?? _confirm)(context);
      if (!mounted) return false;
      if (!go) {
        _dismiss('not_now');
        return false;
      }
      await _promptStore.markRequested();
      final answer =
          await (widget.requestPermission ?? Geolocator.requestPermission)();
      if (!mounted) return false;
      _tracker.resultFor(answer);
      setState(() => _visible = false);
      final granted =
          answer == LocationPermission.always ||
          answer == LocationPermission.whileInUse;
      if (granted) widget.onGranted();
      return granted;
    } catch (_) {
      _tracker.result('unavailable');
      if (mounted) setState(() => _visible = false);
      return false;
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    // Not while a page covers Home (a suggestion opened from onboarding):
    // "shown" should mean seen.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (onTop) _tracker.shown();
    // Figma "Banner wrap": 4 above and below, like the denied banner.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LocationDeniedBanner(
        visible: true,
        title: 'See cafes near you',
        actionLabel: 'Use my location',
        onOpenSettings: _ask,
        onDismiss: () => _dismiss('dismissed'),
      ),
    );
  }
}
