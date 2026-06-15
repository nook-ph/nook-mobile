import 'package:flutter/material.dart';
import 'package:nook/core/utils/error_info.dart';

/// Full-screen error shell: icon, title, subtitle, optional primary action.
class FullPageErrorWidget extends StatelessWidget {
  const FullPageErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  final ErrorInfo error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconFor(error.type),
                size: 64,
                color: Colors.grey.shade800,
              ),
              const SizedBox(height: 24),
              Text(
                error.title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(color: Colors.black),
              ),
              const SizedBox(height: 12),
              Text(
                error.subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 32),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
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
        ),
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
