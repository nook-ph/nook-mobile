abstract class HomeEvent {}

class LoadHomeDataEvent extends HomeEvent {
  /// A pull to refresh: the feed already on screen stays in place while the
  /// new one loads, instead of being swapped for the skeleton.
  final bool refresh;

  LoadHomeDataEvent({this.refresh = false});
}

/// Hides the location banner until the next successful load.
class HomeDismissLocationBannerEvent extends HomeEvent {}
