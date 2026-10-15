import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/places_progress.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/save_actions.dart';
import 'package:nook/features/home_page/presentation/widgets/home_meta_line.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/lists/presentation/widgets/places_progress_pill.dart';

/// The Saved tab for someone without an account: the Want to Try and Been
/// they kept on this phone, and a card (not a wall) offering to keep them
/// on any phone by signing in.
class GuestSavedPage extends StatefulWidget {
  const GuestSavedPage({super.key, this.onBrowse});

  /// Takes the guest somewhere to find a cafe (Home); hides the empty
  /// state's button when null.
  final VoidCallback? onBrowse;

  static const title = 'Your lists';
  static const emptyTitle = 'Start your Want to Try list';
  static const emptyBody =
      'Tap Want to Try or Been on any cafe. It stays on this phone, no '
      'account needed.';
  static const keepTitle = 'Keep your saves on any phone';
  static const keepBody = 'Sign in and everything here moves to your account.';
  static const keepAction = 'Sign in';

  @override
  State<GuestSavedPage> createState() => _GuestSavedPageState();
}

class _GuestSavedPageState extends State<GuestSavedPage> {
  static const _surface = {'surface': KeepSavesSurface.savedTab};
  bool _loggedPrompt = false;

  @override
  void initState() {
    super.initState();
    context.read<GuestSavesCubit>().load();
  }

  void _logPromptShown() {
    if (_loggedPrompt) return;
    _loggedPrompt = true;
    logAppEvent(SavesEvents.keepSavesPromptShown, properties: _surface);
  }

  void _signIn() {
    logAppEvent(SavesEvents.keepSavesPromptTapped, properties: _surface);
    openKeepSavesSignIn(context, KeepSavesSurface.savedTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListsTokens.surface,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<GuestSavesCubit, GuestSavesState>(
          builder: (context, state) {
            if (!state.loaded) return const SizedBox.shrink();
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
                ListsTitleRow(
                  title: GuestSavedPage.title,
                  progress: PlacesProgress.fromStatuses(
                    state.saves.map((s) => s.status),
                  ),
                ),
                const SizedBox(height: 20),
                if (state.isEmpty)
                  _EmptySaves(onBrowse: widget.onBrowse)
                else ...[
                  _KeepSavesCard(onSignIn: _signIn),
                  if (wantToTry.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Want to try',
                      icon: LucideIcons.bookmark,
                      saves: wantToTry,
                    ),
                  ],
                  if (been.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Been',
                      icon: LucideIcons.check,
                      saves: been,
                    ),
                  ],
                ],
              ],
            );
          },
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ListsTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ListsTokens.border),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.smartphone,
            size: 22,
            color: ListsTokens.brand,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GuestSavedPage.keepTitle,
                  style: listsText(14, weight: FontWeight.w600),
                ),
                Text(
                  GuestSavedPage.keepBody,
                  style: listsText(12, color: ListsTokens.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PillButton(label: GuestSavedPage.keepAction, onTap: onSignIn),
        ],
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
          constraints: const BoxConstraints(minHeight: 40),
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
