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

  /// The public page for a crawl. `nookph.app/c/<code>` is also the short
  /// form printed on share cards and typed into "Enter a code".
  static String crawlLink(String shareCode) =>
      'https://www.nookph.app/c/$shareCode';

  /// The crawl page with the crew invite attached (spec §5).
  static String crewInviteLink(String shareCode, String inviteCode) =>
      '${crawlLink(shareCode)}?crew=$inviteCode';

  Future<void> shareCrawl({
    required String shareCode,
    required String title,
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            '$title, a cafe crawl on Nook\n\n${crawlLink(shareCode)}\n\n'
            'Or enter code $shareCode in the app.',
        subject: title,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// The invite code is in the text as well as the link, so a friend can
  /// type it into "Enter a code" when the link does not open the app.
  Future<void> shareCrewInvite({
    required String shareCode,
    required String inviteCode,
    required String title,
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Join my crew for $title on Nook\n\n'
            '${crewInviteLink(shareCode, inviteCode)}\n\n'
            'Or enter crew code $inviteCode in the app.',
        subject: 'Join my crew: $title',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
