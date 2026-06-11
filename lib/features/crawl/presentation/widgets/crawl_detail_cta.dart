import 'package:flutter/material.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class CrawlDetailCta extends StatelessWidget {
  final bool isRegistered;
  final bool allStopsClaimed;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onClaimStopTap;

  const CrawlDetailCta({
    super.key,
    required this.isRegistered,
    this.allStopsClaimed = false,
    this.onRegisterTap,
    this.onClaimStopTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isRegistered
                ? (allStopsClaimed ? null : onClaimStopTap)
                : onRegisterTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary100,
              disabledBackgroundColor: colors.primary100.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isRegistered
                  ? (allStopsClaimed ? 'All Stops Claimed' : 'Claim a Stop')
                  : 'Register for Crawl',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
