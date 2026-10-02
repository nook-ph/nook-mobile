import 'package:flutter/material.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/invite_crew_sheet.dart';

/// What the user picked from the run's "more" sheet.
enum RunOption { invite, shareLink, viewCrawl, leave }

/// The run page's "more" sheet. Pops with the chosen [RunOption]; the page
/// carries it out.
class RunOptionsSheet extends StatelessWidget {
  const RunOptionsSheet({super.key, required this.run});

  final CrawlRun run;

  static Future<RunOption?> show(
    BuildContext context, {
    required CrawlRun run,
  }) {
    return CrawlSheet.show<RunOption>(
      context,
      builder: (_) => RunOptionsSheet(run: run),
    );
  }

  @override
  Widget build(BuildContext context) {
    void pick(RunOption option) => Navigator.of(context).pop(option);

    return CrawlSheet(
      title: run.crawl.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrawlSheetAction(
            title: 'Invite crew',
            subtitle:
                'Up to ${InviteCrewSheet.crewLimit} people. '
                'Share the invite link.',
            onTap: () => pick(RunOption.invite),
          ),
          CrawlSheetAction(
            title: 'Share crawl link',
            subtitle: 'nookph.app/c/${run.crawl.shareCode}',
            onTap: () => pick(RunOption.shareLink),
          ),
          CrawlSheetAction(
            title: 'View crawl',
            subtitle: 'Route and stops',
            onTap: () => pick(RunOption.viewCrawl),
          ),
          CrawlSheetAction(
            title: 'Leave run',
            subtitle: 'Your stamps in this run are removed',
            destructive: true,
            onTap: () => pick(RunOption.leave),
          ),
        ],
      ),
    );
  }
}

/// Confirms leaving a run. Resolves true when the user chooses to leave.
class LeaveRunDialog extends StatelessWidget {
  const LeaveRunDialog({super.key, required this.stampCount});

  final int stampCount;

  static Future<bool> show(BuildContext context, {required int stampCount}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => LeaveRunDialog(stampCount: stampCount),
    ).then((leave) => leave ?? false);
  }

  String get _body => switch (stampCount) {
    0 =>
      'You have no stamps in this run yet. You can join again with an '
          'invite.',
    1 =>
      'Your stamp in this run will be removed. The cafe stays in your '
          'Been list.',
    _ =>
      'Your $stampCount stamps in this run will be removed. The cafes '
          'stay in your Been list.',
  };

  @override
  Widget build(BuildContext context) {
    return CrawlConfirmDialog(
      title: 'Leave this run?',
      body: _body,
      cancelLabel: 'Stay',
      confirmLabel: 'Leave run',
    );
  }
}
