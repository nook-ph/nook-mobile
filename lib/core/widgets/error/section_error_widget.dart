import 'package:flutter/material.dart';
import 'package:nook/core/utils/error_info.dart';

/// Compact error block for a subsection (e.g. failed reviews list).
class SectionErrorWidget extends StatelessWidget {
  const SectionErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  final ErrorInfo error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _iconFor(error.type),
            size: 36,
            color: Colors.grey.shade800,
          ),
          const SizedBox(height: 12),
          Text(
            error.title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            error.subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                error.type == ErrorType.sessionExpired
                    ? 'Sign in'
                    : 'Try again',
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(ErrorType type) {
    return switch (type) {
      ErrorType.offline => Icons.wifi_off_outlined,
      ErrorType.sessionExpired => Icons.lock_outline,
      ErrorType.serverError => Icons.error_outline,
      ErrorType.unknown => Icons.error_outline,
    };
  }
}
