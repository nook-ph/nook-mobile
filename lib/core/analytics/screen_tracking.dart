import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:nook/core/analytics/analytics_config.dart';

/// Human names for PostHog `$screen` events and the `$screen_name` stamped on
/// every event after them. Stable strings: insights, heatmaps and replay
/// filters key on them, so rename only with a reason.
abstract final class ScreenNames {
  // Root route: the app shell and what it shows before it.
  static const splash = 'Splash';
  static const onboarding = 'Onboarding';

  // The four tabs, in BottomNav order.
  static const home = 'Home';
  static const map = 'Map';
  static const saved = 'Saved';
  static const profile = 'Profile';
  static const tabs = [home, map, saved, profile];

  // Auth.
  static const login = 'Login';
  static const loginPassword = 'Login Password';
  static const signupDetails = 'Signup Details';
  static const emailConfirmation = 'Email Confirmation';
  static const usernameSetup = 'Username Setup';
  static const forgotPassword = 'Forgot Password';
  static const changeEmail = 'Change Email';
  static const changePassword = 'Change Password';

  // Discovery and cafes.
  static const search = 'Search';
  static const cafeDetails = 'Cafe Details';
  static const cafePhotos = 'Cafe Photos';
  static const cafeTags = 'Cafe Tags';
  static const cafeMenu = 'Cafe Menu';
  static const cafeCups = 'Cafe Cups';
  static const photoViewer = 'Photo Viewer';
  static const galleryViewer = 'Gallery Viewer';
  static const storyViewer = 'Story Viewer';
  static const savedPlaceEditor = 'Saved Place Editor';
  static const pickOnMap = 'Pick On Map';

  // Lists.
  static const listDetail = 'List Detail';

  // Crawls.
  static const crawlDetail = 'Crawl Detail';
  static const crawlBuilder = 'Crawl Builder';
  static const crawlRun = 'Crawl Run';
  static const crawlComplete = 'Crawl Complete';
  static const crawlShare = 'Crawl Share';
  static const crewInvite = 'Crew Invite';

  // People and settings.
  static const publicProfile = 'Public Profile';
  static const settings = 'Settings';
  static const blockedUsers = 'Blocked Users';
  static const editProfile = 'Edit Profile';

  static const linkNotFound = 'Link Not Found';
}

/// go_router names a page after its path pattern when the route has no
/// `name`, so this is what [RouteSettings.name] holds for each GoRoute.
const Map<String, String> _goRouteScreens = {
  'u/:username': ScreenNames.publicProfile,
  'c/:code': ScreenNames.crawlDetail,
  '/login': ScreenNames.login,
  '/login-password': ScreenNames.loginPassword,
  '/change-email': ScreenNames.changeEmail,
  '/change-password': ScreenNames.changePassword,
  '/forgot-password': ScreenNames.forgotPassword,
  '/signup-details': ScreenNames.signupDetails,
  '/email-confirmation': ScreenNames.emailConfirmation,
  '/username-setup': ScreenNames.usernameSetup,
  '/cafe/:id': ScreenNames.cafeDetails,
  '/search': ScreenNames.search,
};

/// The screen name for a route, or null for one that should not be tracked.
///
/// `/` is the shell: what it shows (a tab, onboarding, the splash) is owned by
/// [ScreenTracker.rootScreen]. GoRoutes are looked up by path pattern. Pages
/// pushed with `Navigator.push` carry a [ScreenNames] value in their
/// `RouteSettings` and pass through as is.
@visibleForTesting
String? screenNameForRoute(RouteSettings settings, {required String root}) {
  final name = settings.name?.trim();
  if (name == null || name.isEmpty) return null;
  if (name == '/') return root;
  return _goRouteScreens[name] ?? (name.contains('/') ? null : name);
}

/// The one place the app reports which screen is showing.
///
/// Routes report through [NookScreenObserver]; the root route's content (tab
/// switches inside one route, onboarding vs. home) reports through
/// [showRoot]. Every `$screen` goes through [report], so `$screen_name` on
/// later events (taps, `$rageclick`) names the real screen instead of the
/// native host view ("Flutter").
class ScreenTracker {
  ScreenTracker._();

  static final ScreenTracker instance = ScreenTracker._();

  /// The screen last reported, or null before the first one.
  String? get current => _current;
  String? _current;

  /// What the root route is showing right now.
  String get rootScreen => _rootScreen;
  String _rootScreen = ScreenNames.splash;

  /// The root route now shows [name]. Reported at once when [onTop] (the
  /// root route is the visible one); otherwise remembered for when a pushed
  /// page pops back to it.
  void showRoot(String name, {bool onTop = true}) {
    _rootScreen = name;
    if (onTop) report(name);
  }

  /// Counts screen changes: bumps on every new [report], so a widget can
  /// tell one visit to a screen from the next (Home, then a cafe, then Home
  /// again is two Home visits).
  ValueListenable<int> get visits => _visits;
  final ValueNotifier<int> _visits = ValueNotifier<int>(0);

  /// Sends a `$screen` for [name] unless it is already the current screen.
  void report(String name) {
    if (name == _current) return;
    _current = name;
    _visits.value++;
    if (!kAnalyticsEnabled) return;
    Posthog().screen(screenName: name).catchError((Object e) {
      debugPrint('PostHog screen failed: $e');
    });
  }

  @visibleForTesting
  void resetForTest() {
    _current = null;
    _rootScreen = ScreenNames.splash;
  }
}

/// Reports a `$screen` whenever a page is pushed, popped back to or replaced.
///
/// Built on [PosthogObserver] so surveys still get their navigation context
/// and screens are skipped while the app is in the background. Its own
/// capture is bypassed (the extractor reports through [ScreenTracker] and
/// returns null) so every screen view goes through one place and is deduped.
class NookScreenObserver extends PosthogObserver {
  NookScreenObserver()
    : super(
        nameExtractor: (settings) {
          final tracker = ScreenTracker.instance;
          final name = screenNameForRoute(settings, root: tracker.rootScreen);
          if (name != null) tracker.report(name);
          return null;
        },
      );
}

/// `beforeSend` hook: adds `$screen_width` / `$screen_height` (logical
/// pixels, as the native SDKs report them) to events captured from Dart when
/// they are missing, so rage taps and screen views can be placed on a layout.
/// Native-only events (lifecycle, `$snapshot`) are not routed through here.
PostHogEvent addScreenSize(PostHogEvent event) {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  if (view == null || view.devicePixelRatio == 0) return event;
  final size = view.physicalSize / view.devicePixelRatio;
  if (size.isEmpty) return event;
  final properties = event.properties ?? <String, Object>{};
  properties.putIfAbsent(r'$screen_width', () => size.width.roundToDouble());
  properties.putIfAbsent(r'$screen_height', () => size.height.roundToDouble());
  event.properties = properties;
  return event;
}
