abstract class MapEvent {}

class LoadMapDataEvent extends MapEvent {
  final List<String> tags;
  LoadMapDataEvent({this.tags = const []});
}

class LoadFilterTagsEvent extends MapEvent {}
