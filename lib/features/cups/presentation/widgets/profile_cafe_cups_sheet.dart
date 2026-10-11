import 'package:flutter/material.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/presentation/cup_actions.dart';
import 'package:nook/features/cups/presentation/widgets/cup_card_view.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// A profile tile opened: that person's cups at one cafe, newest visit
/// first, with the cafe as a way in. Yours carry Edit and Delete; someone
/// else's Report and Block. [onOpenPhoto] may open a photo itself (true),
/// as your own profile does with the gallery viewer that pins and hides.
Future<void> showProfileCafeCups(
  BuildContext context, {
  required ProfileCafeCups cafe,
  required VoidCallback onOpenCafe,
  required ValueChanged<CupCard> onEdit,
  required VoidCallback onChanged,
  bool Function(CupCard cup, int index)? onOpenPhoto,
}) {
  return ReviewSheetShell.show<void>(
    context,
    builder: (sheetContext) => ReviewSheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CafeRow(
            cafe: cafe,
            onTap: () {
              Navigator.of(sheetContext).pop();
              onOpenCafe();
            },
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: ReviewTokens.border),
          for (var i = 0; i < cafe.cups.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: ReviewTokens.border,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: CupCardView(
                card: cafe.cups[i],
                showAuthor: false,
                onOpenPhoto: (index) {
                  // The owner's viewer (pin, hide, edit) when it can.
                  if (onOpenPhoto?.call(cafe.cups[i], index) ?? false) return;
                  openCupPhotos(
                    sheetContext,
                    card: cafe.cups[i],
                    index: index,
                    cafeId: cafe.cafeId,
                    cafeName: cafe.cafeName,
                  );
                },
                onMore: () => showCupOptions(
                  sheetContext,
                  card: cafe.cups[i],
                  cafeId: cafe.cafeId,
                  cafeName: cafe.cafeName,
                  cafeArea: cafe.cafeArea,
                  shareEntry: CupShareEntry.profile,
                  onEdit: () {
                    Navigator.of(sheetContext).pop();
                    onEdit(cafe.cups[i]);
                  },
                  onChanged: () {
                    Navigator.of(sheetContext).pop();
                    onChanged();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CafeRow extends StatelessWidget {
  const _CafeRow({required this.cafe, required this.onTap});

  final ProfileCafeCups cafe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visits = cafe.visitCount;
    final sub = [
      if (cafe.cafeArea != null) cafe.cafeArea!,
      visits == 1 ? '1 visit' : '$visits visits',
    ].join(' · ');
    return Semantics(
      button: true,
      label: 'Open ${cafe.cafeName}',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              ListsThumb(
                imageUrl: cafe.cafeImageUrl ?? cafe.cover?.imageUrl,
                size: 48,
                radius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafe.cafeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyLargeSemi.copyWith(
                        color: ReviewTokens.ink,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: ReviewTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: ReviewTokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
