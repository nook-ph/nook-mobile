abstract class HomeEvent {}

class LoadHomeDataEvent extends HomeEvent {}

/// Hides [HomeLoadedState.locationDenied] banner until next successful load.
class HomeDismissLocationBannerEvent extends HomeEvent {}
