import 'package:flutter/foundation.dart';

/// Debug-only switch for trying place search before the `place-search`
/// function and the `saved_places` table are deployed:
///
///   flutter run --dart-define=PLACE_SEARCH_DIRECT=true
///
/// Search then calls the public Photon server straight from the phone and
/// saved places stay on the device. `kDebugMode` keeps this off in profile
/// and release builds whatever is passed.
const bool kPlaceSearchDirect =
    kDebugMode && bool.fromEnvironment('PLACE_SEARCH_DIRECT');
