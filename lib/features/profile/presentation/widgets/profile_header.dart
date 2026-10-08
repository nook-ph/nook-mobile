import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// The profile tab's own top bar: the handle (or "Profile" when there is no
/// one to name) centred, the settings gear on the right.
class ProfileTopBar extends StatelessWidget {
  const ProfileTopBar({
    super.key,
    required this.title,
    this.brand = true,
    this.onSettings,
  });

  final String title;

  /// Kept for callers; the title is ink either way in the v2 header.
  final bool brand;

  /// Null hides the gear (signed out).
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final settings = onSettings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            // Balances the gear so the handle sits in the middle.
            const SizedBox(width: 44),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ProfileTokens.text(16, weight: FontWeight.w600),
              ),
            ),
            if (settings != null)
              AdaptiveTap(
                onTap: settings,
                borderRadius: BorderRadius.circular(22),
                child: Semantics(
                  button: true,
                  label: 'Settings',
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      LucideIcons.settings,
                      size: 22,
                      color: ProfileTokens.ink,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

/// One number in the header's stat row. [value] null shows a dash (not
/// loaded yet, or the read failed), never a zero that isn't true.
class ProfileStat {
  const ProfileStat(this.label, this.value, {this.onTap});

  final String label;
  final int? value;

  /// Opens the tab the number counts.
  final VoidCallback? onTap;
}

/// Who the profile belongs to, TikTok's way: the avatar and name centred,
/// a row of three numbers, the owner's actions, then the bio
/// (docs/references/profile-v2).
///
/// A visitor's header has no action row: Nook has no follow, and Share and
/// Block live in the bar's "…".
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.stats,
    this.onEdit,
    this.onShare,
    this.onAdd,
    this.avatarUrl,
    this.bio = '',
  });

  final String name;

  /// Ranked · Reviews · Cups. Each is shown once here instead of as badges
  /// on the tabs.
  final List<ProfileStat> stats;
  final String? avatarUrl;
  final String bio;

  /// Null leaves the action row out (a visitor's view).
  final VoidCallback? onEdit;

  /// Shares the profile's web link.
  final VoidCallback? onShare;

  /// Adds photos to the gallery, the owner's most common action.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final about = bio.trim();
    final share = onShare, add = onAdd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        8,
        ProfileTokens.gutter,
        20,
      ),
      child: Column(
        children: [
          ProfileAvatar(name: name, imageUrl: avatarUrl, size: 96),
          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ProfileTokens.text(20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final stat in stats) _Stat(stat: stat)],
          ),
          if (onEdit != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HeaderButton(label: 'Edit profile', onTap: onEdit!),
                ),
                if (share != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeaderButton(label: 'Share profile', onTap: share),
                  ),
                ],
                if (add != null) ...[
                  const SizedBox(width: 8),
                  _HeaderButton(
                    icon: LucideIcons.plus,
                    label: 'Add photos',
                    onTap: add,
                  ),
                ],
              ],
            ),
          ],
          if (about.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              about,
              textAlign: TextAlign.center,
              style: ProfileTokens.text(14),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.stat});

  final ProfileStat stat;

  @override
  Widget build(BuildContext context) {
    final value = stat.value;
    final number = value == null ? '–' : '$value';
    final body = SizedBox(
      width: 92,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              number,
              style: ProfileTokens.text(
                18,
                weight: FontWeight.w600,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ProfileTokens.text(12, color: ProfileTokens.muted),
            ),
          ],
        ),
      ),
    );
    final tap = stat.onTap;
    return Semantics(
      button: tap != null,
      label: '$number ${stat.label}',
      excludeSemantics: true,
      child: tap == null
          ? body
          : AdaptiveTap(
              onTap: tap,
              borderRadius: BorderRadius.circular(8),
              child: body,
            ),
    );
  }
}

/// A 40pt filled button in the header row: a label, or one icon in a 44
/// wide square.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          width: icon == null ? null : 44,
          alignment: Alignment.center,
          padding: icon == null
              ? const EdgeInsets.symmetric(horizontal: 8)
              : null,
          decoration: BoxDecoration(
            color: ProfileTokens.fill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: icon == null
              ? Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileTokens.text(14, weight: FontWeight.w500),
                )
              : Icon(icon, size: 18, color: ProfileTokens.ink),
        ),
      ),
    );
  }
}

/// The header's shape in grey, shown while the profile loads.
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key, this.showAction = true});

  /// The action row's shape; a visitor's header has none.
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading profile',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ProfileTokens.gutter,
          8,
          ProfileTokens.gutter,
          20,
        ),
        child: Column(
          children: [
            const ProfileSkeleton(width: 96, height: 96, radius: 48),
            const SizedBox(height: 14),
            const ProfileSkeleton(width: 140, height: 20),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  const SizedBox(
                    width: 92,
                    child: Column(
                      children: [
                        ProfileSkeleton(width: 28, height: 18),
                        SizedBox(height: 6),
                        ProfileSkeleton(width: 48, height: 12),
                      ],
                    ),
                  ),
              ],
            ),
            if (showAction) ...[
              const SizedBox(height: 16),
              const ProfileSkeleton(height: 44, radius: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// One tab of [ProfileTabs]: a label and, once known, how many it holds.
class ProfileTabData {
  const ProfileTabData(
    this.label, {
    this.count,
    this.private = false,
    this.icon,
  });

  /// The tab's name. With [icon] it is not drawn, but it is still what a
  /// screen reader says and what a long-press shows.
  final String label;
  final int? count;

  /// Draws the tab as this icon instead of [label], as Instagram, TikTok
  /// and Pinterest profiles do: regular when idle, filled when selected.
  final PhosphorIconData Function(PhosphorIconsStyle style)? icon;

  /// Only the owner sees this tab's content: drawn with a lock.
  final bool private;
}

/// The profile's tabs: equal-width labels or icons (a lock on a private
/// one), a 2pt brand underline on the selected one and a hairline under the
/// row. Counts live in the header's stat row, so tabs usually pass none.
class ProfileTabs extends StatelessWidget {
  const ProfileTabs({super.key, required this.tabs, required this.controller});

  final List<ProfileTabData> tabs;
  final TabController controller;

  /// The row's height at [scaler]: one line of 14pt text, 12 above and
  /// below, the 2pt underline and the 1pt hairline.
  static double heightFor(TextScaler scaler) => scaler.scale(14) * 1.5 + 27;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ProfileTokens.gutter),
      decoration: const BoxDecoration(
        color: ProfileTokens.surface,
        border: Border(bottom: BorderSide(color: ProfileTokens.border)),
      ),
      // Equal shares of the width; at a large text size a label scales
      // down rather than clipping its neighbour.
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _Tab(
                  data: tabs[i],
                  selected: controller.index == i,
                  onTap: () => controller.animateTo(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.data, required this.selected, required this.onTap});

  final ProfileTabData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = data.count;
    final icon = data.icon;
    final color = selected ? ProfileTokens.ink : ProfileTokens.muted;
    if (icon != null) {
      // Same 2pt underline and height as the word tabs; the word stays as
      // the semantics label and the long-press tooltip.
      final size = MediaQuery.textScalerOf(context).scale(22);
      return Semantics(
        button: true,
        selected: selected,
        label: data.private ? '${data.label}, only you can see it' : data.label,
        excludeSemantics: true,
        child: Tooltip(
          message: data.label,
          excludeFromSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: selected ? ProfileTokens.brand : Colors.transparent,
                  ),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon(
                        selected
                            ? PhosphorIconsStyle.fill
                            : PhosphorIconsStyle.regular,
                      ),
                      size: size,
                      color: color,
                    ),
                    if (data.private) ...[
                      const SizedBox(width: 3),
                      Icon(LucideIcons.lock, size: size * 0.5, color: color),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: selected ? ProfileTokens.brand : Colors.transparent,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.private) ...[
                  Icon(
                    LucideIcons.lock,
                    size: 13,
                    color: selected ? ProfileTokens.ink : ProfileTokens.muted,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  data.label,
                  style: ProfileTokens.text(
                    14,
                    weight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? ProfileTokens.ink : ProfileTokens.muted,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? ProfileTokens.brand
                          : ProfileTokens.tint,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$count',
                      style: ProfileTokens.text(
                        10,
                        weight: FontWeight.w500,
                        color: selected
                            ? ProfileTokens.surface
                            : ProfileTokens.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
