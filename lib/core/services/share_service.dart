import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// Shares a cafe as its public web page.
///
/// The https link is the right payload for everyone: recipients without the
/// app can open it, and it unfurls with the cafe's OpenGraph card (name,
/// photo, description) wherever it is pasted — the webapp side of that was
/// verified end to end. The old custom-scheme deep link
/// (`ph.nook.app:///cafe/…`) did neither: dead for non-users, no unfurl.
class ShareService {
  Future<void> shareCafe({
    required String id,
    required String name,
    Rect? sharePositionOrigin,
  }) async {
    final link = 'https://www.nookph.app/cafes/$id';

    await SharePlus.instance.share(
      ShareParams(
        // The link on its own line auto-links reliably in share targets.
        text: 'Check out $name on Nook!\n\n$link',
        subject: name,
        // Required on iPadOS: without an anchor rect the share popover has
        // nowhere to point and UIKit throws.
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
