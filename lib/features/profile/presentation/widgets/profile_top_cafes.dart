import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/lists/presentation/widgets/ranked_been_list.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/injection_container.dart';

/// "Your top cafes": the person's best-ranked cafes as a strip of photo
/// cards, each with its rank and score, under Edit profile. The heading opens
/// the whole ranked Been list.
///
/// It replaced a grey "5 cafes ranked · See your list" bar that repeated the
/// count already under the name and showed nothing of the person's taste
/// (docs/ux/core-loops.md, finding 3). Structure from Showcase (a titled strip
/// of poster cards with a score badge, the next card cut off to show it
/// scrolls) and Gowalla (a heading row ending in a count and chevron).
class ProfileTopCafes extends StatefulWidget {
  const ProfileTopCafes({
    super.key,
    required this.beenListId,
    required this.onOpenList,
  });

  final String beenListId;
  final VoidCallback onOpenList;

  /// Cards shown at most; the rest are a tap away in the list.
  static const int maxCards = 5;

  @override
  State<ProfileTopCafes> createState() => _ProfileTopCafesState();
}

class _ProfileTopCafesState extends State<ProfileTopCafes> {
  List<CafeSummary>? _cafes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileTopCafes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beenListId != widget.beenListId) _load();
  }

  Future<void> _load() async {
    try {
      final cafes = await sl<ICafeRepository>().getListCafes(widget.beenListId);
      if (mounted) setState(() => _cafes = cafes);
    } catch (_) {
      // The strip is a summary of a list that has its own page; a failed
      // read just leaves it out.
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final cafes = _cafes;
    return BlocBuilder<CafeRankingCubit, CafeRankingState>(
      builder: (context, ranking) {
        if (cafes == null) return const _Loading();
        final split = splitBeenList(cafes, ranking.rankings);
        if (split.ranked.isEmpty) {
          if (split.unranked.isEmpty) return const SizedBox.shrink();
          return _Invite(
            count: split.unranked.length,
            onTap: widget.onOpenList,
          );
        }
        final top = split.ranked.take(ProfileTopCafes.maxCards).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(count: split.ranked.length, onTap: widget.onOpenList),
            const SizedBox(height: 10),
            SizedBox(
              height: _TopCafeCard.height(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: ProfileTokens.gutter,
                ),
                itemCount: top.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    _TopCafeCard(rank: i + 1, entry: top[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "Your top cafes" with "5 ranked ›" on the right; the whole row opens the
/// ranked list.
class _Heading extends StatelessWidget {
  const _Heading({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Your top cafes, see all $count ranked',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ProfileTokens.gutter,
            8,
            ProfileTokens.gutter,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Your top cafes',
                  style: ProfileTokens.text(16, weight: FontWeight.w600),
                ),
              ),
              Text(
                '$count ranked',
                style: ProfileTokens.text(12, color: ProfileTokens.brand),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: ProfileTokens.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A square photo with "#1" on a white pill at the top left, then the name
/// and the score.
class _TopCafeCard extends StatelessWidget {
  const _TopCafeCard({required this.rank, required this.entry});

  final int rank;
  final RankedCafe entry;

  static const double photo = 112;

  /// Photo plus the two text lines, scaled with the reader's text size so
  /// nothing clips.
  static double height(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return photo + 8 + (20 + 18) * scale;
  }

  @override
  Widget build(BuildContext context) {
    final cafe = entry.cafe;
    final image = cafe.coverImage;
    return SizedBox(
      width: photo,
      child: AdaptiveTap(
        onTap: () => context.push('/cafe/${cafe.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          label:
              'Number $rank, ${cafe.name}, ${entry.ranking.displayScore} '
              'out of 10',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: photo,
                      child: image == null || image.isEmpty
                          ? const ColoredBox(color: ProfileTokens.tint)
                          : CafeCardImage(
                              imageUrl: image,
                              width: photo,
                              height: photo,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ProfileTokens.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          '#$rank',
                          style: ProfileTokens.text(
                            12,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cafe.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ProfileTokens.text(13, weight: FontWeight.w500),
              ),
              Text(
                entry.ranking.displayScore,
                style: ProfileTokens.text(
                  12,
                  weight: FontWeight.w600,
                  color: ProfileTokens.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Been cafes, none ranked yet: one line that leads to ranking them.
class _Invite extends StatelessWidget {
  const _Invite({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ProfileTokens.gutter,
          vertical: 12,
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.trophy,
              size: 18,
              color: ProfileTokens.brand,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rank the $count ${count == 1 ? 'cafe' : 'cafes'} you’ve been '
                'to and your top cafes show here',
                style: ProfileTokens.text(13),
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: ProfileTokens.brand,
            ),
          ],
        ),
      ),
    );
  }
}

/// The strip's shape in grey while the Been list loads.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your top cafes',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ProfileTokens.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const ProfileSkeleton(width: 120, height: 18),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  const ProfileSkeleton(
                    width: _TopCafeCard.photo,
                    height: _TopCafeCard.photo,
                    radius: 12,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
