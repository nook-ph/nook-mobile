import 'package:flutter/foundation.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';

/// The place distances are measured from, shared by search and the map so
/// both name the same spot. Null means the phone's own location.
///
/// Kept for the app session only: a pin dropped yesterday should not decide
/// where today's search starts.
class SearchOriginStore {
  final ValueNotifier<SearchOrigin?> origin = ValueNotifier<SearchOrigin?>(
    null,
  );

  SearchOrigin? get value => origin.value;

  void set(SearchOrigin? place) => origin.value = place;
}
