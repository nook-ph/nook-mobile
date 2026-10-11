import 'package:flutter/material.dart';
import 'package:nook/core/presentation/widgets/tag_icon.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_tag_groups.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Everything a cafe offers, opened from "See all N" on the details page.
///
/// The cafe's name over a large title, then one section per group (Coffee,
/// Best for, Amenities, Payment) with a heading over icon + label rows split
/// by hairlines. Coffee rows carry one line on what the tag means, since
/// brew words are the ones a customer may not know. Groups with nothing in
/// them are left out.
class CafeTagsPage extends StatelessWidget {
  const CafeTagsPage({super.key, required this.groups, this.cafeName});

  final CafeTagGroups groups;
  final String? cafeName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = cafeName?.trim() ?? '';
    final sections = groups.sections();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Semantics(
          button: true,
          label: 'Back',
          child: AdaptiveTap(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, color: CafeDetailsTokens.ink),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          CafeDetailsTokens.gutter,
          4,
          CafeDetailsTokens.gutter,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          if (name.isNotEmpty)
            Text(
              name,
              style: textTheme.bodyMedium?.copyWith(
                color: CafeDetailsTokens.muted,
              ),
            ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              'What this cafe offers',
              style: textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: CafeDetailsTokens.ink,
              ),
            ),
          ),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Nothing listed for this cafe yet.',
                style: textTheme.bodyLarge?.copyWith(
                  color: CafeDetailsTokens.muted,
                ),
              ),
            ),
          for (final section in sections)
            _TagGroup(
              title: section.title,
              tags: section.tags,
              withHints: section.title == 'Coffee',
            ),
        ],
      ),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.title,
    required this.tags,
    required this.withHints,
  });

  final String title;
  final List<TagEntity> tags;
  final bool withHints;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CafeDetailsTokens.ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < tags.length; i++) ...[
            _TagRow(
              tag: tags[i],
              hint: withHints ? CafeTagGroups.coffeeHint(tags[i].name) : null,
            ),
            if (i < tags.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: CafeDetailsTokens.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag, this.hint});

  final TagEntity tag;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SizedBox.square(
              dimension: 24,
              child: Center(
                child: TagIcon(
                  tag.name,
                  size: 22,
                  color: CafeDetailsTokens.brand,
                  fallback: PhosphorIcons.checkCircle(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.name,
                  style: textTheme.bodyLarge?.copyWith(
                    color: CafeDetailsTokens.ink,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: textTheme.bodyMedium?.copyWith(
                      color: CafeDetailsTokens.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
