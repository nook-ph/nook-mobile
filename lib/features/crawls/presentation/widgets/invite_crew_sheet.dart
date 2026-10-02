import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/enable_crawl_link_usecase.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/injection_container.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Who is in the run, the code that lets a friend join it, and a share button.
class InviteCrewSheet extends StatelessWidget {
  const InviteCrewSheet({super.key, required this.run, this.onShared});

  final CrawlRun run;

  /// Called once the system share sheet has been opened.
  final VoidCallback? onShared;

  /// The server's crew limit (`join_community_crawl_run`).
  static const crewLimit = 8;

  static Future<void> show(
    BuildContext context, {
    required CrawlRun run,
    VoidCallback? onShared,
  }) {
    return CrawlSheet.show<void>(
      context,
      builder: (_) => InviteCrewSheet(run: run, onShared: onShared),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: run.inviteCode));
    if (context.mounted) showPrimaryToast(context, 'Copied');
    // The code joins the run either way; opening the crawl only lets the
    // invite page show its stops, so a failure here is not worth reporting.
    try {
      await sl<EnableCrawlLinkUseCase>()(run.crawl);
    } catch (e) {
      debugPrint('[InviteCrew] enable link failed: $e');
    }
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await sl<EnableCrawlLinkUseCase>()(run.crawl);
      await sl<ShareService>().shareCrewInvite(
        shareCode: run.crawl.shareCode,
        inviteCode: run.inviteCode,
        title: run.crawl.title,
        sharePositionOrigin: origin,
      );
      onShared?.call();
    } catch (e) {
      debugPrint('[InviteCrew] share failed: $e');
      if (context.mounted) {
        showPrimaryToast(context, 'Couldn’t open sharing. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = run.members;
    // Figma: 14 between every block of the sheet.
    const gap = SizedBox(height: 14);
    return CrawlSheet(
      title: 'Invite your crew',
      gap: 14,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Anyone with the code can join, up to $crewLimit people. Your '
              'crew sees which stops you stamp. Nobody else does.',
              style: crawlText(12, color: ListsTokens.muted),
            ),
            gap,
            Container(
              constraints: const BoxConstraints(minHeight: 45),
              padding: const EdgeInsets.only(left: 14, right: 2),
              decoration: BoxDecoration(
                color: crawlSoftFill,
                borderRadius: BorderRadius.circular(ListsTokens.radius),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Crew code ${run.inviteCode}',
                      child: Text(
                        run.inviteCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: crawlText(14, weight: FontWeight.w500),
                      ),
                    ),
                  ),
                  CrawlTextButton(
                    label: 'Copy',
                    fontSize: 12,
                    minHeight: 45,
                    onTap: () => _copy(context),
                  ),
                ],
              ),
            ),
            gap,
            Text(
              'In this run · ${members.length} of $crewLimit',
              style: crawlText(12, color: ListsTokens.muted),
            ),
            for (var i = 0; i < members.length; i++) ...[
              gap,
              _MemberRow(
                member: members[i],
                // Members arrive in join order; the first one started the run.
                note: i == 0
                    ? 'Started the run'
                    : _stampsLabel(_stampCount(members[i])),
              ),
            ],
            gap,
            CrawlPrimaryButton(
              label: 'Share invite link',
              icon: LucideIcons.share,
              onTap: () => _share(context),
            ),
          ],
        ),
      ),
    );
  }

  int _stampCount(CrewMember member) => run.stamps
      .where((s) => s.userId == member.userId)
      .map((s) => s.stopId)
      .toSet()
      .length;

  static String _stampsLabel(int count) => switch (count) {
    0 => 'No stamps yet',
    1 => '1 stamp',
    _ => '$count stamps',
  };
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.note});

  final CrewMember member;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CrewAvatars(crew: [member], size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            member.isMe ? 'You' : '@${member.username ?? 'someone'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: crawlText(14, weight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 10),
        Text(note, style: crawlText(12, color: ListsTokens.muted)),
      ],
    );
  }
}

/// The outlined "+ Invite" pill beside the crew on the run page.
class InviteCrewPill extends StatelessWidget {
  const InviteCrewPill({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CrawlPillButton(
      label: 'Invite',
      icon: LucideIcons.plus,
      onTap: onTap,
      outlined: true,
      height: 34,
      tapHeight: 34,
    );
  }
}
