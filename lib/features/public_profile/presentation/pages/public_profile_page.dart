import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/profile/presentation/widgets/profile_header.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:nook/features/public_profile/presentation/cubit/public_profile_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/cups/data/legacy_cups.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/cubit/profile_cups_cubit.dart';
import 'package:nook/features/cups/presentation/widgets/profile_cafe_cups_sheet.dart';
import 'package:nook/features/cups/presentation/widgets/profile_cups_grid.dart';
import 'package:nook/injection_container.dart';

/// Shares [profile]'s web link. Swapped in tests.
typedef ShareProfile =
    Future<void> Function({
      required String username,
      required String name,
      bool own,
    });

/// Someone's profile as anyone else sees it: avatar, name, counts and bio,
/// then Gallery and Reviews. Never their ranking, their lists or any score
/// (nook-supabase docs/PUBLIC_PROFILE.md).
///
/// With [preview] it is the owner's own "View as visitor": the same screen,
/// titled Preview, reached from their Ranked tab.
class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({
    super.key,
    this.username,
    this.userId,
    this.nameHint,
    this.preview = false,
    this.repository,
    this.shareProfile,
    this.onOpenCafe,
    this.isSignedIn,
    this.source = ProfileViewSource.link,
  }) : assert(username != null || userId != null);

  /// Where it was opened from, for analytics ([ProfileViewSource]).
  final String source;

  /// Whether someone is signed in, for Block. Defaults to the session.
  final bool Function()? isSignedIn;

  final String? username;
  final String? userId;

  /// The name the opener already shows (a review's author), for the title
  /// while the profile loads.
  final String? nameHint;
  final bool preview;

  /// Defaults to the app's.
  final IPublicProfileRepository? repository;
  final ShareProfile? shareProfile;

  /// Defaults to pushing `/cafe/<id>`.
  final ValueChanged<String>? onOpenCafe;

  /// Pushes the profile for a review author, a crew member or a link.
  static Future<void> open(
    BuildContext context, {
    String? username,
    String? userId,
    String? nameHint,
    bool preview = false,
    required String source,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(
          username: username,
          userId: userId,
          nameHint: nameHint,
          preview: preview,
          source: source,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? sl<IPublicProfileRepository>();
    return BlocProvider(
      create: (_) => PublicProfileCubit(
        repository: repo,
        username: username,
        userId: userId,
      )..load(),
      child: BlocListener<PublicProfileCubit, PublicProfileState>(
        // Once per open: a retry after a failure is still one view.
        listenWhen: (before, now) =>
            before.status != PublicProfileStatus.loaded &&
            now.status == PublicProfileStatus.loaded,
        listener: (_, state) {
          final profile = state.profile;
          if (profile == null) return;
          logAppEvent(
            ProfileEvents.profileViewed,
            properties: {
              'source': preview ? ProfileViewSource.preview : source,
              'is_self': profile.isSelf,
              'highlights_public': profile.highlightsPublic,
            },
          );
        },
        child: _PublicProfileView(
          repository: repo,
          title: username != null ? '@$username' : (nameHint ?? ''),
          preview: preview,
          shareProfile:
              shareProfile ??
              ({required username, required name, own = false}) =>
                  sl<ShareService>().shareProfile(
                    username: username,
                    name: name,
                    own: own,
                  ),
          onOpenCafe: onOpenCafe,
          signedIn: (isSignedIn ?? _sessionSignedIn)(),
        ),
      ),
    );
  }

  static bool _sessionSignedIn() {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }
}

class _PublicProfileView extends StatelessWidget {
  const _PublicProfileView({
    required this.repository,
    required this.title,
    required this.preview,
    required this.shareProfile,
    required this.signedIn,
    this.onOpenCafe,
  });

  final IPublicProfileRepository repository;
  final String title;
  final bool preview;
  final ShareProfile shareProfile;
  final bool signedIn;
  final ValueChanged<String>? onOpenCafe;

  /// Asks why, then reports the person: their name, avatar or bio.
  Future<void> _reportProfile(BuildContext context, PublicProfile profile) {
    return _report<ProfileReportReason>(
      context,
      title: 'Report @${profile.username}?',
      message:
          'For their name, photo or bio. To report a cup or a photo, use '
          'its ⋯. They won’t know who reported them.',
      reasons: ProfileReportReason.values,
      labelOf: (reason) => reason.label,
      send: (reason, details) async {
        await repository.reportProfile(
          profile.userId,
          reason,
          details: details,
        );
        logAppEvent(
          ProfileEvents.profileReported,
          properties: {'reason': reason.wire},
        );
      },
    );
  }

  /// The app's one report sheet: a reason, an optional detail, then Submit
  /// report. Thanks the person once it is sent.
  Future<void> _report<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<T> reasons,
    required String Function(T) labelOf,
    required Future<void> Function(T reason, String? details) send,
  }) async {
    final sent = await ReviewSheetShell.show<bool>(
      context,
      builder: (_) => ReportReasonSheet<T>(
        title: title,
        message: message,
        reasons: reasons,
        labelOf: labelOf,
        onSubmit: (reason, details) =>
            send(reason, details.isEmpty ? null : details),
      ),
    );
    if (sent == true && context.mounted) {
      showPrimaryToast(context, ReviewReportSheet.sentMessage);
    }
  }

  /// The bar's ⋯ (Figma B2): Share profile, then Report and Block for a
  /// signed-in visitor.
  Future<void> _openOptions(BuildContext context, PublicProfile profile) async {
    final moderate = signedIn && !profile.isSelf;
    final choice = await ListsSheet.show<_ProfileOption>(
      context,
      builder: (sheetContext) => ListsSheet(
        title: '@${profile.username}',
        gap: 4,
        children: [
          ListsSheetAction(
            title: 'Share profile',
            subtitle: profile.isSelf
                ? 'Send a link to your profile'
                : 'Send a link to their profile',
            onTap: () => Navigator.pop(sheetContext, _ProfileOption.share),
          ),
          if (moderate) ...[
            ListsSheetAction(
              title: 'Report @${profile.username}',
              subtitle: 'Their name, photo or bio breaks the guidelines',
              onTap: () => Navigator.pop(sheetContext, _ProfileOption.report),
            ),
            ListsSheetAction(
              title: 'Block @${profile.username}',
              subtitle: 'Hide their cups and profile from you',
              destructive: true,
              onTap: () => Navigator.pop(sheetContext, _ProfileOption.block),
            ),
          ],
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _ProfileOption.share:
        await shareProfile(
          username: profile.username,
          name: profile.displayName,
          own: profile.isSelf,
        );
      case _ProfileOption.report:
        await _reportProfile(context, profile);
      case _ProfileOption.block:
        await _block(context, profile);
    }
  }

  /// Blocking from the profile, as from a review: they disappear from the
  /// viewer's feeds and their profile is no longer shown to them.
  Future<void> _block(BuildContext context, PublicProfile profile) async {
    final blocks = context.read<BlockCubit>();
    final confirmed = await showProfileConfirmSheet(
      context,
      title: 'Block @${profile.username}?',
      message:
          'You will no longer see their cups or their profile. You can '
          'unblock them in Settings.',
      confirmLabel: 'Block',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await blocks.block(profile.userId);
      logAppEvent(ProfileEvents.userBlocked, properties: {'from': 'profile'});
      if (!context.mounted) return;
      showPrimaryToast(context, '@${profile.username} blocked');
      Navigator.of(context).maybePop();
    } catch (_) {
      if (context.mounted) {
        showPrimaryToast(context, 'Could not block them. Please try again.');
      }
    }
  }

  void _openCafe(BuildContext context, String id) {
    final open = onOpenCafe;
    if (open != null) {
      open(id);
    } else {
      context.push('/cafe/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PublicProfileCubit, PublicProfileState>(
      builder: (context, state) {
        final profile = state.profile;
        return Scaffold(
          backgroundColor: ProfileTokens.surface,
          appBar: ProfileNavBar(
            title: preview
                ? 'Preview'
                : (profile != null ? '@${profile.username}' : title),
            subtitle: preview ? 'What visitors see on your profile' : null,
            textScaler: MediaQuery.textScalerOf(context),
            actions: [
              if (profile != null && !preview)
                AdaptiveTap(
                  onTap: () => _openOptions(context, profile),
                  borderRadius: BorderRadius.circular(22),
                  child: Semantics(
                    button: true,
                    label: 'Profile options',
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        LucideIcons.ellipsis,
                        size: 20,
                        color: ProfileTokens.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: switch (state.status) {
              PublicProfileStatus.loading => const _Loading(),
              PublicProfileStatus.notFound => const SingleChildScrollView(
                child: ProfileMessage(
                  icon: LucideIcons.userX,
                  title: 'This profile isn’t available',
                  subtitle:
                      'The link may be wrong, or the account is no longer '
                      'on Nook.',
                  top: 120,
                ),
              ),
              PublicProfileStatus.failed => SingleChildScrollView(
                child: ProfileMessage.error(
                  title: 'Could not load this profile',
                  subtitle: 'Check your connection and try again.',
                  onAction: () => context.read<PublicProfileCubit>().load(),
                  top: 120,
                ),
              ),
              PublicProfileStatus.loaded => _Loaded(
                profile: profile!,
                onOpenCafe: (id) => _openCafe(context, id),
              ),
            },
          ),
        );
      },
    );
  }
}

enum _ProfileOption { share, report, block }

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ProfileHeaderSkeleton(showAction: false)],
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.profile, required this.onOpenCafe});

  final PublicProfile profile;
  final ValueChanged<String> onOpenCafe;

  /// Their cups through the Cups backend when the app has it, else from
  /// the reviews and photos the profile read already brought.
  ProfileCupsCubit _cups() {
    if (sl.isRegistered<ICupsRepository>()) {
      return ProfileCupsCubit(
        repository: sl<ICupsRepository>(),
        userId: profile.userId,
        username: profile.username,
      )..load();
    }
    return ProfileCupsCubit.from(
      () async => ProfileCups(
        userId: profile.userId,
        isSelf: profile.isSelf,
        highlightsPublic: profile.highlightsPublic,
        cafes: LegacyCups.profileCafes(
          userId: profile.userId,
          username: profile.username,
          avatarUrl: profile.avatarUrl,
          isMine: profile.isSelf,
          reviews: profile.reviews,
          photos: profile.highlightsPublic ? profile.photos : const [],
        ),
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    final ranked = profile.rankedCount;
    return BlocProvider(
      create: (_) => _cups(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BlocBuilder<ProfileCupsCubit, ProfileCupsState>(
              buildWhen: (a, b) => a.cups != b.cups,
              builder: (context, state) => ProfileHeader(
                name: profile.displayName,
                avatarUrl: profile.avatarUrl,
                bio: profile.bio ?? '',
                // Ranked only when the owner shows it, and not at zero:
                // beside their cups it reads as a verdict on the person.
                stats: [
                  if (ranked != null && ranked > 0)
                    ProfileStat('Ranked', ranked),
                  ProfileStat('Cups', state.cups?.cupCount),
                  ProfileStat('Cafes', state.cups?.cafeCount),
                ],
              ),
            ),
            if (!profile.highlightsPublic) const _PrivateNote(),
            const ProfileDivider(),
            Builder(
              builder: (context) => ProfileCupsGrid(
                scrollable: false,
                isSelf: profile.isSelf,
                onOpen: (cafe) => showProfileCafeCups(
                  context,
                  cafe: cafe,
                  onOpenCafe: () => onOpenCafe(cafe.cafeId),
                  onEdit: (_) => onOpenCafe(cafe.cafeId),
                  onChanged: () =>
                      context.read<ProfileCupsCubit>().load(refresh: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One muted line where the photos would be.
class _PrivateNote extends StatelessWidget {
  const _PrivateNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        0,
        ProfileTokens.gutter,
        16,
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.lock, size: 16, color: ProfileTokens.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Their photos are private. Their notes and stars are public.',
              style: ProfileTokens.text(13, color: ProfileTokens.muted),
            ),
          ),
        ],
      ),
    );
  }
}
