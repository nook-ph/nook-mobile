import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Asks a signed-out user to sign in before an action that needs an account,
/// saying what the account is for. "Not now" leaves them where they were.
class CrawlSignInSheet extends StatelessWidget {
  const CrawlSignInSheet({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  /// Opens the sheet; "Sign in or create account" pushes `/login`.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final signIn = await CrawlSheet.show<bool>(
      context,
      builder: (_) => CrawlSignInSheet(title: title, message: message),
    );
    if (signIn == true && context.mounted) context.push('/login');
  }

  @override
  Widget build(BuildContext context) {
    return CrawlSheet(
      showClose: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Figma: 8 + a 12 spacer + 8 under the grabber.
          const SizedBox(height: 24),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: crawlTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.bookmark,
              size: 24,
              color: ListsTokens.brand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: crawlText(20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: crawlText(14, color: ListsTokens.muted),
          ),
          // Figma: 8 + a 12 spacer + 8.
          const SizedBox(height: 28),
          CrawlPrimaryButton(
            label: 'Sign in or create account',
            onTap: () => Navigator.of(context).pop(true),
          ),
          CrawlTextButton(
            label: 'Not now',
            color: ListsTokens.muted,
            minHeight: 40,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
