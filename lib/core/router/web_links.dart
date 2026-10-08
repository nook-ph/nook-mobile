import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/crawls/presentation/widgets/enter_crawl_code_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';

/// Parsing for the `https://www.nookph.app` links the app opens (Android App
/// Links and iOS Universal Links): `/u/<username>` and `/c/<code>[?crew=…]`.
///
/// Kept apart from the router so the rules can be tested without building
/// the pages behind them.
abstract final class WebLinks {
  static final _username = RegExp(r'^[A-Za-z0-9_.]{1,40}$');

  /// The username in a `/u/<username>` link, or null when it can't be one.
  /// Tolerates a leading `@`, which people add when typing a link by hand.
  static String? username(String? raw) {
    if (raw == null) return null;
    var value = Uri.decodeComponent(raw).trim();
    if (value.startsWith('@')) value = value.substring(1);
    return _username.hasMatch(value) ? value : null;
  }

  /// What a `/c/<code>` link opens: a crew invite when it carries a valid
  /// `?crew=<invite>` (the crew code wins, as in the code sheet), otherwise
  /// the crawl with share code [code]. Null when neither code is valid.
  static CrawlCodeTarget? crawl(String? code, String? crew) {
    final invite = (crew ?? '').trim().toUpperCase();
    if (invite.length == CrawlCodeTarget.inviteCodeLength) {
      final parsed = CrawlCodeTarget.parse(invite);
      if (parsed != null && parsed.isInvite) return parsed;
    }
    final share = (code ?? '').trim().toUpperCase();
    if (share.length != CrawlCodeTarget.shareCodeLength) return null;
    final parsed = CrawlCodeTarget.parse(share);
    return parsed != null && !parsed.isInvite ? parsed : null;
  }
}

/// Where a link the app can't place lands, instead of go_router's bare
/// "Page Not Found": a short note and a way Home.
class LinkNotFoundPage extends StatelessWidget {
  const LinkNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This link doesn’t open anything',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ListsTokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'It may be mistyped or no longer shared.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: ListsTokens.muted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ListsTokens.brand,
                    minimumSize: const Size(160, 44),
                  ),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
