import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:nook/core/constants/app_constants.dart';

/// The phone's side of the home-screen widget, behind one seam so the sync
/// and the promo can be tested without a launcher.
abstract class HomeWidgetPlatform {
  /// Whether this platform has the widget at all: Android, and iOS through
  /// the `NookWidget` WidgetKit extension (see `docs/features/home_widget.md`).
  bool get isSupported;

  Future<void> write(String key, String json);

  /// Redraws every copy of the widget now.
  Future<void> redraw();

  Future<bool> canPin();

  /// Asks the launcher to place the widget (it shows its own dialog).
  Future<void> requestPin();

  /// Copies of the widget on the home screen; null when unknown.
  Future<int?> installedCount();

  /// Whether Nook may post notifications; null when unknown.
  Future<bool?> notificationsEnabled();

  /// The phone's Android API level; null when unknown or not Android.
  Future<int?> sdkInt();

  /// The widget link that started the app, if it was started from the
  /// widget.
  Future<Uri?> launchLink();

  /// Widget taps that reach the running app.
  Stream<Uri?> get clicks;
}

class HomeWidgetPluginPlatform implements HomeWidgetPlatform {
  const HomeWidgetPluginPlatform();

  /// `android/app/src/main/kotlin/app/nookph/SavedCafesWidgetProvider.kt`.
  static const androidName = 'SavedCafesWidgetProvider';
  static const _qualified = 'app.nookph.$androidName';
  static const _notifications = MethodChannel('app.nookph/notifications');

  /// `ios/NookWidget/NookWidget.swift`, the widget's `kind`.
  static const iOSName = 'NookWidget';

  /// The App Group the app and the extension share (`NOOK_APP_GROUP` in the
  /// Xcode project); the dev flavor has its own.
  static const iOSAppGroup = AppConstants.scheme == 'ph.nook.app.dev'
      ? 'group.app.nookph.dev'
      : 'group.app.nookph';

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// iOS reads and writes the group's defaults, so it must be named before
  /// the first write.
  static Future<void>? _groupSet;
  static Future<void> _ready() async {
    if (_isIOS) await (_groupSet ??= HomeWidget.setAppGroupId(iOSAppGroup));
  }

  @override
  bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || _isIOS);

  @override
  Future<void> write(String key, String json) async {
    await _ready();
    await HomeWidget.saveWidgetData<String>(key, json);
  }

  @override
  Future<void> redraw() async {
    await _ready();
    await HomeWidget.updateWidget(
      qualifiedAndroidName: _qualified,
      iOSName: iOSName,
    );
  }

  @override
  Future<bool> canPin() async =>
      isSupported && (await HomeWidget.isRequestPinWidgetSupported() ?? false);

  @override
  Future<void> requestPin() =>
      HomeWidget.requestPinWidget(qualifiedAndroidName: _qualified);

  @override
  Future<int?> installedCount() async {
    if (!isSupported) return null;
    final widgets = await HomeWidget.getInstalledWidgets();
    return widgets
        .where(
          (w) =>
              (w.androidClassName?.endsWith(androidName) ?? false) ||
              w.iOSKind == iOSName,
        )
        .length;
  }

  @override
  Future<Uri?> launchLink() async {
    if (!isSupported) return null;
    return HomeWidget.initiallyLaunchedFromHomeWidget();
  }

  @override
  Stream<Uri?> get clicks =>
      isSupported ? HomeWidget.widgetClicked : const Stream.empty();

  @override
  Future<bool?> notificationsEnabled() => _ask<bool>('areEnabled');

  @override
  Future<int?> sdkInt() => _ask<int>('sdkInt');

  Future<T?> _ask<T>(String method) async {
    if (!isSupported) return null;
    try {
      return await _notifications.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
