import 'package:flutter/material.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Footer inviting the owner of an unclaimed cafe to claim it on Nook for
/// Business. Opens the claim page in the browser, where sign-up happens.
///
/// Renders nothing unless the listing is known to be unclaimed: a cafe
/// seeded from a summary doesn't know yet, and a claimed one has an owner.
class CafeClaimLink extends StatelessWidget {
  const CafeClaimLink({
    super.key,
    required this.cafeId,
    required this.isClaimed,
  });

  final String cafeId;
  final bool? isClaimed;

  static const _claimBase = 'https://business.nookph.app/claim';

  Future<void> _open(BuildContext context) async {
    logAppEvent('claim_cafe_tapped', properties: {'cafe_id': cafeId});
    final uri = Uri.parse('$_claimBase/${Uri.encodeComponent(cafeId)}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showPrimaryToast(context, 'Unable to open the claim page.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isClaimed != false) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CafeSectionDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CafeDetailsTokens.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CafeSectionTitle('Own this café?'),
              const SizedBox(height: 4),
              Text(
                'Claim it to keep the hours, photos and menu up to date.',
                style: text.bodyMedium?.copyWith(
                  color: CafeDetailsTokens.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          link: true,
          child: InkWell(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CafeDetailsTokens.gutter,
                vertical: 14,
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.storefront(),
                    size: 20,
                    color: CafeDetailsTokens.brand,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Claim this café',
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: CafeDetailsTokens.brand,
                      ),
                    ),
                  ),
                  PhosphorIcon(
                    PhosphorIcons.arrowUpRight(),
                    size: 18,
                    color: CafeDetailsTokens.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
