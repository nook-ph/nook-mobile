import 'package:nook/core/filters/models/cafe_filter.dart';

abstract class MapEvent {}

class LoadMapDataEvent extends MapEvent {
  final CafeFilter filter;
  LoadMapDataEvent({this.filter = const CafeFilter()});
}

class LoadFilterTagsEvent extends MapEvent {}
