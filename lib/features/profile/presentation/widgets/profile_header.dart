import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// The profile tab's own top bar: the handle (or "Profile" when there is no
/// one to name) on the left and the settings gear on the right.
class ProfileTopBar extends StatelessWidget {
  const ProfileTopBar({
    super.key,
    required this.title,
    this.brand = true,
    this.onSettings,
  });

  final String title;

  /// Brand green for a handle, ink for the plain "Profile" title.
  final bool brand;

  /// Null hides the gear (signed out).
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final settings = onSettings;
    return Padding(
      padding: EdgeInsets.only(
        left: ProfileTokens.gutter,
        // The 22 gear sits 20 from the edge inside a 44 touch target.
        right: settings == null ? ProfileTokens.gutter : 9,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ProfileTokens.text(
                  16,
                  weight: FontWeight.w600,
                  color: brand ? ProfileTokens.brand : ProfileTokens.ink,
                ),
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
              ),
          ],
        ),
      ),
    );
  }
}

/// Who the profile belongs to: the avatar, the name with the counts under
/// it, the bio, and the owner's actions: Edit profile with a square Share
/// beside it (Duolingo's action row; docs/references/public-profile).
///
/// A visitor's header has no action row yet. When following arrives, Follow
/// takes Edit profile's place in the same row, with Share beside it.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.countsLine,
    this.onEdit,
    this.onShare,
    this.avatarUrl,
    this.bio = '',
  });

  final String name;

  /// "12 reviews · 3 lists".
  final String countsLine;
  final String? avatarUrl;
  final String bio;

  /// Null leaves the action row out (a visitor's view).
  final VoidCallback? onEdit;

  /// Shares the profile's web link. Shown beside Edit profile.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final about = bio.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        8,
        ProfileTokens.gutter,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(name: name, imageUrl: avatarUrl, size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileTokens.text(20, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      countsLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileTokens.text(12, color: ProfileTokens.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (about.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(about, style: ProfileTokens.text(14)),
          ],
          if (onEdit != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ProfilePillButton(
                    label: 'Edit profile',
                    onTap: onEdit,
                    style: ProfilePillStyle.outlined,
                    height: 44,
                  ),
                ),
                if (onShare != null) ...[
                  const SizedBox(width: 8),
                  ProfileIconButton(
                    icon: LucideIcons.share,
                    label: 'Share profile',
                    onTap: onShare!,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A 44pt outlined square holding one icon, the same outline as the
/// outlined pill beside it.
class ProfileIconButton extends StatelessWidget {
  const ProfileIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: ProfileTokens.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 18, color: ProfileTokens.ink),
        ),
      ),
    );
  }
}

/// The header's shape in grey, shown while the profile loads.
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key, this.showAction = true});

  /// The Edit profile row's shape; a visitor's header has none.
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
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileSkeleton(width: 72, height: 72, radius: 36),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileSkeleton(width: 140, height: 18),
                    SizedBox(height: 8),
                    ProfileSkeleton(width: 90, height: 12),
                  ],
                ),
              ],
            ),
            SizedBox(height: 14),
            ProfileSkeleton(height: 12),
            SizedBox(height: 14),
            FractionallySizedBox(
              widthFactor: 220 / 350,
              child: ProfileSkeleton(height: 12),
            ),
            if (showAction) ...[
              const SizedBox(height: 14),
              const ProfileSkeleton(height: 44, radius: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// One tab of [ProfileTabs]: a label and, once known, how many it holds.
class ProfileTabData {
  const ProfileTabData(this.label, {this.count});

  final String label;
  final int? count;
}

/// The Reviews / Lists switch: left-aligned labels with a count pill, a 2pt
/// brand underline on the selected one and a hairline under the row.
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
      // Four tabs with counts need about 340pt; on a narrow phone, or at a
      // large text size, the row scrolls instead of clipping the last tab.
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 20),
                _Tab(
                  data: tabs[i],
                  selected: controller.index == i,
                  onTap: () => controller.animateTo(i),
                ),
              ],
            ],
          ),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: ProfileTokens.text(
                  14,
                  weight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? ProfileTokens.brand : ProfileTokens.muted,
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
                    color: selected ? ProfileTokens.brand : ProfileTokens.tint,
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
    );
  }
}
