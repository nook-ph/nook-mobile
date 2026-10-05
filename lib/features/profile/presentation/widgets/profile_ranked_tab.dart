import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/ranked_been_list.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/public_profile/presentation/cubit/profile_visibility_cubit.dart';
import 'package:nook/features/public_profile/presentation/widgets/visitor_hint.dart';
import 'package:nook/injection_container.dart';

/// The Ranked tab: the person's Been list as their ranking (your #1, then
/// Liked it / It was fine bands, then cafes still to rank), the same view as
/// Saved → Been. It is the profile's first tab because it says the most
/// about the person, which matters once profiles are public
/// (docs/ux/core-loops.md, finding 3).
class ProfileRankedTab extends StatefulWidget {
  const ProfileRankedTab({super.key, required this.beenListId, this.onPreview});

  /// Null until the lists have loaded, or when there is no Been list yet.
  final String? beenListId;

  /// Opens "View as visitor". Null leaves the hint out.
  final VoidCallback? onPreview;

  @override
  State<ProfileRankedTab> createState() => _ProfileRankedTabState();
}

class _ProfileRankedTabState extends State<ProfileRankedTab> {
  List<CafeSummary>? _cafes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // As the Been page does: the scores may not have been fetched yet when
    // the profile opens first.
    final ranking = context.read<CafeRankingCubit>();
    if (!ranking.state.loaded) ranking.load();
    _load();
  }

  @override
  void didUpdateWidget(ProfileRankedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beenListId != widget.beenListId) _load();
  }

  Future<void> _load() async {
    final id = widget.beenListId;
    if (id == null) return;
    setState(() => _failed = false);
    try {
      final cafes = await sl<ICafeRepository>().getListCafes(id);
      if (mounted) setState(() => _cafes = cafes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// "Only you see your ranking…" with Preview; follows the switch.
  Widget _hint() => BlocBuilder<ProfileVisibilityCubit, ProfileVisibilityState>(
    builder: (context, visibility) => VisitorHint(
      highlightsPublic: visibility.highlightsPublic,
      onPreview: widget.onPreview!,
      likedCount: context
          .watch<CafeRankingCubit>()
          .state
          .rankings
          .where((r) => r.bucket == RankBucket.liked)
          .length,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return SingleChildScrollView(
        child: ProfileMessage.error(
          title: 'Could not load your ranking.',
          subtitle: 'Check your connection and try again.',
          actionStyle: ProfilePillStyle.outlined,
          onAction: _load,
        ),
      );
    }
    final cafes = _cafes;
    if (widget.beenListId != null && cafes == null) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          ProfileTokens.gutter,
          20,
          ProfileTokens.gutter,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileSkeleton(height: 64, radius: 12),
            SizedBox(height: 20),
            ProfileSkeleton(height: 48),
            SizedBox(height: 12),
            ProfileSkeleton(height: 48),
            SizedBox(height: 12),
            ProfileSkeleton(height: 48),
          ],
        ),
      );
    }
    if (cafes == null || cafes.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.onPreview != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ProfileTokens.gutter,
                  4,
                  ProfileTokens.gutter,
                  0,
                ),
                child: _hint(),
              ),
            const ProfileMessage(
              icon: LucideIcons.trophy,
              title: 'Nothing ranked yet',
              subtitle:
                  'Mark a cafe as Been and rank it. Your ranking shows here, '
                  'best first.',
            ),
          ],
        ),
      );
    }
    // Rebuild with the ranking so a re-rank from a row shows at once.
    return BlocBuilder<CafeRankingCubit, CafeRankingState>(
      buildWhen: (a, b) => a.rankings != b.rankings,
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          ProfileTokens.gutter,
          widget.onPreview != null ? 4 : 16,
          ProfileTokens.gutter,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.onPreview != null) ...[
              _hint(),
              const SizedBox(height: 8),
            ],
            RankedBeenList(cafes: cafes),
          ],
        ),
      ),
    );
  }
}
