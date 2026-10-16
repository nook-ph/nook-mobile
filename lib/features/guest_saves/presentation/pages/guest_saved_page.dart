import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/engagement_score.dart';
import 'package:nook/features/guest_saves/presentation/save_actions.dart';
import 'package:nook/features/guest_saves/presentation/widgets/sign_up_ask_on_saved.dart';
import 'package:nook/features/home_page/presentation/widgets/home_meta_line.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/profile/presentation/pages/settings_page.dart';
import 'package:nook/injection_container.dart';

/// The Saved tab for someone without an account: the Want to Try and Been
/// they kept on this phone, and a card (not a wall) offering to keep them
/// on any phone by signing in.
class GuestSavedPage extends StatefulWidget {
  const GuestSavedPage({super.key, this.onBrowse});

  /// Takes the guest somewhere to find a cafe (Home); hides the empty
  /// state's button when null.
  final VoidCallback? onBrowse;

  // One name for the tab and its page (review finding 7).
  static const title = 'Saved';
  static const emptyTitle = 'Start your Want to try list';
  static const emptyBody =
      'Tap Want to try or Been on any cafe. It stays on this phone, no '
      'account needed.';
  static const keepTitle = 'Keep your saves on any phone';
  static const keepBody = 'Sign in and everything here moves to your account.';
  static const keepAction = 'Sign in';

  /// After two declined asks the card becomes one row below the lists
  /// (ux finding 6): still there, no longer first.
  static const keepRowLabel = 'On this phone only';
  static const shrinkAfterDeclines = 2;

  @override
  State<GuestSavedPage> createState() => _GuestSavedPageState();
}

class _GuestSavedPageState extends State<GuestSavedPage> {
  bool _loggedPrompt = false;

  /// The app's score, for its decline count; none in some tests.
  final EngagementScore? _score = sl.isRegistered<EngagementScore>()
      ? sl<EngagementScore>()
      : null;

  @override
  void initState() {
    super.initState();
    context.read<GuestSavesCubit>().load();
    _score?.declines.addListener(_onDeclines);
    // The keep-saves card's size (and the surface its event reports) hangs
    // on the declines, so nothing is drawn or logged until they are read.
    final read = _score?.read();
    if (read != null) {
      unawaited(
        read.then<void>((_) {}, onError: (_) {}).whenComplete(() {
          if (mounted) setState(() => _scoreReady = true);
        }),
      );
    }
  }

  late bool _scoreReady = _score == null;

  @override
  void dispose() {
    _score?.declines.removeListener(_onDeclines);
    super.dispose();
  }

  void _onDeclines() {
    if (mounted) setState(() {});
  }

  bool get _shrunk =>
      (_score?.declines.value ?? 0) >= GuestSavedPage.shrinkAfterDeclines;

  String get _surface =>
      _shrunk ? KeepSavesSurface.savedRow : KeepSavesSurface.savedTab;

  void _logPromptShown() {
    if (_loggedPrompt) return;
    _loggedPrompt = true;
    logAppEvent(
      SavesEvents.keepSavesPromptShown,
      properties: {'surface': _surface},
    );
  }

  void _signIn() {
    final surface = _surface;
    logAppEvent(
      SavesEvents.keepSavesPromptTapped,
      properties: {'surface': surface},
    );
    openKeepSavesSignIn(context, surface);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: ScreenNames.settings),
        builder: (_) => const SettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListsTokens.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Opening Saved with 3+ saves may bring the score's ask. Outside
            // the lazy list: scrolled out and back, it would be made again
            // and ask again.
            const SignUpAskOnSaved(),
            BlocBuilder<GuestSavesCubit, GuestSavesState>(
              builder: (context, state) {
                if (!state.loaded || !_scoreReady) {
                  return const SizedBox.shrink();
                }
                final wantToTry = state.withStatus(CafeStatus.wantToTry);
                final been = state.withStatus(CafeStatus.been);
                if (!state.isEmpty) _logPromptShown();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    ListsTokens.gutter,
                    8,
                    ListsTokens.gutter,
                    40,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            GuestSavedPage.title,
                            style: listsText(24, weight: FontWeight.w600),
                          ),
                        ),
                        // A guest has no Profile tab, so Settings (location,
                        // visit reminders) is reached from here.
                        _SettingsButton(onTap: _openSettings),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (state.isEmpty)
                      _EmptySaves(onBrowse: widget.onBrowse)
                    else ...[
                      if (!_shrunk) _KeepSavesCard(onSignIn: _signIn),
                      if (wantToTry.isNotEmpty) ...[
                        if (!_shrunk) const SizedBox(height: 24),
                        _Section(
                          title: 'Want to try',
                          icon: LucideIcons.bookmark,
                          saves: wantToTry,
                        ),
                      ],
                      if (been.isNotEmpty) ...[
                        if (!_shrunk || wantToTry.isNotEmpty)
                          const SizedBox(height: 24),
                        _Section(
                          title: 'Been',
                          icon: LucideIcons.check,
                          saves: been,
                        ),
                      ],
                      if (_shrunk) ...[
                        const SizedBox(height: 16),
                        const ListsDivider(),
                        _KeepSavesRow(onSignIn: _signIn),
                      ],
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySaves extends StatelessWidget {
  const _EmptySaves({this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final browse = onBrowse;
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ListsTokens.tint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.bookmark,
              size: 24,
              color: ListsTokens.brand,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            GuestSavedPage.emptyTitle,
            textAlign: TextAlign.center,
            style: listsText(18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            GuestSavedPage.emptyBody,
            textAlign: TextAlign.center,
            style: listsText(14, color: ListsTokens.muted),
          ),
          if (browse != null) ...[
            const SizedBox(height: 20),
            _PillButton(label: 'Find a cafe', onTap: browse),
          ],
        ],
      ),
    );
  }
}

class _KeepSavesCard extends StatelessWidget {
  const _KeepSavesCard({required this.onSignIn});

  final VoidCallback onSignIn;

  /// Above this text scale the button goes under the text, so the text
  /// keeps the card's width instead of three words a line (finding 9).
  static const stackAbove = 1.3;

  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.textScalerOf(context).scale(14) / 14 > stackAbove;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          GuestSavedPage.keepTitle,
          style: listsText(14, weight: FontWeight.w600),
        ),
        Text(
          GuestSavedPage.keepBody,
          // 14: the screen's secondary text size (finding 9).
          style: listsText(14, color: ListsTokens.muted),
        ),
      ],
    );
    const icon = Icon(
      LucideIcons.smartphone,
      size: 22,
      color: ListsTokens.brand,
    );
    final button = _PillButton(
      label: GuestSavedPage.keepAction,
      onTap: onSignIn,
    );
    // The whole card signs in (review N12), as it already read to TalkBack;
    // the pill stays the visible action.
    return AdaptiveTap(
      onTap: onSignIn,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ListsTokens.border),
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: icon,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: text),
                    ],
                  ),
                  const SizedBox(height: 12),
                  button,
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  const SizedBox(width: 12),
                  button,
                ],
              ),
      ),
    );
  }
}

/// The keep-saves offer after two declines: one quiet row below the lists,
/// "On this phone only" and Sign in, the whole row one button.
class _KeepSavesRow extends StatelessWidget {
  const _KeepSavesRow({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${GuestSavedPage.keepRowLabel}. ${GuestSavedPage.keepAction}',
      excludeSemantics: true,
      onTap: onSignIn,
      child: AdaptiveTap(
        onTap: onSignIn,
        borderRadius: BorderRadius.circular(ListsTokens.radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.smartphone,
                  size: 20,
                  color: ListsTokens.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    GuestSavedPage.keepRowLabel,
                    style: listsText(14, color: ListsTokens.muted),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  GuestSavedPage.keepAction,
                  style: listsText(
                    14,
                    weight: FontWeight.w600,
                    color: ListsTokens.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Semantics(
        button: true,
        label: 'Settings',
        child: const SizedBox.square(
          dimension: 48,
          child: Icon(LucideIcons.settings, size: 22, color: ListsTokens.ink),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          // 48: the touch floor (review finding 6).
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ListsTokens.brand,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: listsText(
              14,
              weight: FontWeight.w500,
              color: ListsTokens.surface,
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.saves,
  });

  final String title;
  final IconData icon;
  final List<GuestSave> saves;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: ListsTokens.brand),
            const SizedBox(width: 6),
            Text(title, style: listsText(16, weight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(
              '${saves.length}',
              style: listsText(14, color: ListsTokens.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < saves.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 6),
            const ListsDivider(),
            const SizedBox(height: 6),
          ],
          _SavedCafeRow(cafe: saves[i].cafe),
        ],
      ],
    );
  }
}

class _SavedCafeRow extends StatelessWidget {
  const _SavedCafeRow({required this.cafe});

  final CafeSnapshot cafe;

  @override
  Widget build(BuildContext context) {
    final summary = cafe.toSummary();
    return AdaptiveTap(
      onTap: () => context.push('/cafe/${cafe.id}'),
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CafeCardImage(
                imageUrl: cafe.coverImage,
                placeholderSeed: cafe.name,
                width: 56,
                height: 56,
                showSampleLabel: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cafe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listsText(14, weight: FontWeight.w500),
                  ),
                  HomeMetaLine(
                    area: homeCardArea(summary),
                    lat: cafe.lat,
                    lng: cafe.lng,
                  ),
                  HomeOpenLine(hours: cafe.operatingHours),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: ListsTokens.muted,
            ),
          ],
        ),
      ),
    );
  }
}
