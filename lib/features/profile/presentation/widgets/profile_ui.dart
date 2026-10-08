import 'package:flutter/material.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';

/// Shared pieces of the redesigned profile screens: the back bar, the pill
/// button, the avatar, the centred message block, the spinner and the
/// skeleton block.

/// The bar on every pushed profile screen: a back arrow, a SemiBold 16 title
/// and an optional muted line under it.
class ProfileNavBar extends StatelessWidget implements PreferredSizeWidget {
  const ProfileNavBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backEnabled = true,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;

  /// 44pt icon buttons at the right end (Share on a public profile).
  final List<Widget> actions;

  /// Defaults to popping the route.
  final VoidCallback? onBack;
  final bool backEnabled;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    return SafeArea(
      bottom: false,
      child: Padding(
        // The 22 arrow sits 20 from the edge inside a 44 touch target.
        padding: EdgeInsets.only(
          left: 9,
          right: actions.isEmpty ? ProfileTokens.gutter : 9,
        ),
        child: Row(
          children: [
            AdaptiveTap(
              onTap: backEnabled
                  ? onBack ?? () => Navigator.of(context).maybePop()
                  : null,
              borderRadius: BorderRadius.circular(22),
              child: Semantics(
                button: true,
                label: 'Back',
                child: const SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    LucideIcons.arrowLeft,
                    size: 22,
                    color: ProfileTokens.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileTokens.text(16, weight: FontWeight.w600),
                  ),
                  if (note != null)
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileTokens.text(12, color: ProfileTokens.muted),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// How a [ProfilePillButton] is painted.
enum ProfilePillStyle { brand, danger, outlined }

/// A pill button with a Medium label. Dimmed to 40% when [onTap] is null;
/// while [busy] it shows a spinner (beside [busyLabel] when one is given).
class ProfilePillButton extends StatelessWidget {
  const ProfilePillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.style = ProfilePillStyle.brand,
    this.height = 48,
    this.fontSize = 14,
    this.padding = 16,
    this.expand = true,
    this.busy = false,
    this.busyLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final ProfilePillStyle style;
  final double height;
  final double fontSize;

  /// Horizontal padding inside the pill.
  final double padding;

  /// Fill the available width instead of hugging the label.
  final bool expand;
  final bool busy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final outlined = style == ProfilePillStyle.outlined;
    final foreground = outlined ? ProfileTokens.ink : ProfileTokens.surface;
    final fill = switch (style) {
      ProfilePillStyle.brand => ProfileTokens.brand,
      ProfilePillStyle.danger => ProfileTokens.danger,
      ProfilePillStyle.outlined => ProfileTokens.surface,
    };
    final enabled = onTap != null && !busy;
    final textStyle = ProfileTokens.text(
      fontSize,
      weight: FontWeight.w500,
      color: foreground,
    );
    final working = busyLabel;

    final content = busy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileSpinner(size: 16, color: foreground),
              if (working != null) ...[
                const SizedBox(width: 6),
                Text(working, maxLines: 1, style: textStyle),
              ],
            ],
          )
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        // A busy button stays solid; only an unusable one is dimmed.
        opacity: onTap == null && !busy ? 0.4 : 1,
        child: AdaptiveTap(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            width: expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: padding),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(100),
              border: outlined ? Border.all(color: ProfileTokens.border) : null,
            ),
            child: Center(widthFactor: expand ? null : 1, child: content),
          ),
        ),
      ),
    );
  }
}

/// A round avatar: the photo when there is one, otherwise the first letter
/// of [name] on the sage fill.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.size,
    this.imageUrl,
    this.image,
    this.initialSize = 24,
    this.initialWeight = FontWeight.w600,
  });

  final String name;
  final double size;
  final String? imageUrl;

  /// A local image shown instead of [imageUrl] (a photo not uploaded yet).
  final ImageProvider? image;
  final double initialSize;
  final FontWeight initialWeight;

  /// "S" for "Sai"; "?" when there is no name to take a letter from.
  static String initialOf(String name) {
    final trimmed = name.trim().replaceFirst(RegExp(r'^@'), '');
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final local = image;
    final initial = Center(
      child: Text(
        initialOf(name),
        style: ProfileTokens.text(initialSize, weight: initialWeight),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: ProfileTokens.avatar,
        shape: BoxShape.circle,
      ),
      child: local != null
          ? Image(image: local, fit: BoxFit.cover, width: size, height: size)
          : url.isEmpty
          ? initial
          : CafeCardImage(
              imageUrl: url,
              width: size,
              height: size,
              // The avatar circle's own colour shows through while loading.
              placeholder: const SizedBox.shrink(),
              errorWidget: initial,
            ),
    );
  }
}

/// The centred state block: a 56 tinted circle, a SemiBold 16 title, an
/// optional muted line and an optional pill. Empty, error and signed-out
/// states all use it; [top] is the distance from the top of its area.
class ProfileMessage extends StatelessWidget {
  const ProfileMessage({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionStyle = ProfilePillStyle.outlined,
    this.wideAction = false,
    this.isError = false,
    this.top = 56,
  });

  /// The "could not load" block: the alert icon in brand green.
  const ProfileMessage.error({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel = 'Retry',
    this.onAction,
    this.actionStyle = ProfilePillStyle.brand,
    this.top = 56,
  }) : icon = LucideIcons.triangleAlert,
       wideAction = false,
       isError = true;

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ProfilePillStyle actionStyle;

  /// A full-width 48 button (signed out) instead of a pill that hugs its
  /// label.
  final bool wideAction;
  final bool isError;
  final double top;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    final label = actionLabel;
    final action = onAction;
    final outlined = actionStyle == ProfilePillStyle.outlined;

    // Full width, so the block centres even inside a scroll view, whose
    // loose width would otherwise shrink it to its longest line.
    return Padding(
      padding: EdgeInsets.fromLTRB(40, top, 40, 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: ProfileTokens.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isError ? 26 : 24,
                color: isError ? ProfileTokens.brand : ProfileTokens.muted,
              ),
            ),
            // Figma: 8 + a 4 spacer + 8.
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ProfileTokens.text(16, weight: FontWeight.w600),
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                textAlign: TextAlign.center,
                style: ProfileTokens.text(14, color: ProfileTokens.muted),
              ),
            ],
            if (label != null && action != null) ...[
              // Figma: 8 + a spacer (12 before the wide button, 8 otherwise)
              // + 8.
              SizedBox(height: wideAction ? 28 : 24),
              ProfilePillButton(
                label: label,
                onTap: action,
                style: actionStyle,
                expand: wideAction,
                height: wideAction ? 48 : (outlined ? 40 : 44),
                padding: outlined || wideAction ? 16 : 28,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The loader glyph, turning.
class ProfileSpinner extends StatefulWidget {
  const ProfileSpinner({
    super.key,
    this.size = 16,
    this.color = ProfileTokens.ink,
  });

  final double size;
  final Color color;

  @override
  State<ProfileSpinner> createState() => _ProfileSpinnerState();
}

class _ProfileSpinnerState extends State<ProfileSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: RotationTransition(
        turns: _turn,
        child: Icon(
          LucideIcons.loaderCircle,
          size: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}

/// A grey block standing in for content that is still loading.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ProfileTokens.tint,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
