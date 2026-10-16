import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// The phone's side of the home-screen widget, behind one seam so the sync
/// and the promo can be tested without a launcher.
abstract class HomeWidgetPlatform {
  /// Whether this platform has the widget at all (Android for now; the iOS
  /// WidgetKit extension is not built yet, see `docs/features/home_widget.md`).
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

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> write(String key, String json) async {
    await HomeWidget.saveWidgetData<String>(key, json);
  }

  @override
  Future<void> redraw() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: _qualified);
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
        .where((w) => w.androidClassName?.endsWith(androidName) ?? false)
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
  Future<bool?> notificationsEnabled() async {
    if (!isSupported) return null;
    try {
      return await _notifications.invokeMethod<bool>('areEnabled');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
