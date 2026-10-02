import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/state_styles.dart';

/// Compact error block for a subsection, Figma "System — section states":
/// a tinted radius 12 row with 14 padding, a Medium 14 title over a Regular
/// 12 muted line, and a SemiBold 12 brand action on the right.
class SectionErrorWidget extends StatelessWidget {
  const SectionErrorWidget({super.key, required this.error, this.onRetry});

  final ErrorInfo error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: StateStyles.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 14, retry == null ? 14 : 0, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.title,
                    style: StateStyles.text(
                      14,
                      FontWeight.w500,
                      StateStyles.ink,
                    ),
                  ),
                  Text(
                    error.subtitle,
                    style: StateStyles.text(
                      12,
                      FontWeight.w400,
                      StateStyles.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (retry != null)
            Semantics(
              button: true,
              child: AdaptiveTap(
                onTap: retry,
                // The row's 10 gap and 14 padding sit inside the tap target.
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
                  child: Text(
                    error.type == ErrorType.sessionExpired
                        ? 'Sign in'
                        : 'Try again',
                    style: StateStyles.text(
                      12,
                      FontWeight.w600,
                      StateStyles.brand,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
