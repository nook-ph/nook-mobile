import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/use_cases/report_crawl_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/report_crawl_cubit.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nook/injection_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Reports a crawl to the Nook team: one reason, optional details. Pops with
/// `true` once the report is sent.
class ReportCrawlSheet extends StatefulWidget {
  const ReportCrawlSheet({super.key, required this.crawl});

  final Crawl crawl;

  static Future<bool?> show(BuildContext context, Crawl crawl) {
    return CrawlSheet.show<bool>(
      context,
      builder: (_) => BlocProvider(
        create: (_) =>
            ReportCrawlCubit(reportCrawlUseCase: sl<ReportCrawlUseCase>()),
        child: ReportCrawlSheet(crawl: crawl),
      ),
    );
  }

  @override
  State<ReportCrawlSheet> createState() => _ReportCrawlSheetState();
}

class _ReportCrawlSheetState extends State<ReportCrawlSheet> {
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportCrawlCubit, ReportCrawlState>(
      listenWhen: (previous, current) => !previous.sent && current.sent,
      listener: (context, state) => Navigator.of(context).pop(true),
      builder: (context, state) {
        final cubit = context.read<ReportCrawlCubit>();
        final error = state.error;
        return CrawlSheet(
          title: 'Report this crawl',
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reports go to the Nook team. The creator is not told who '
                  'reported.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: ListsTokens.muted,
                  ),
                ),
                const SizedBox(height: 8),
                for (final reason in ReportCrawlCubit.reasons)
                  _ReasonRow(
                    label: reason,
                    selected: state.reason == reason,
                    onTap: state.submitting ? null : () => cubit.choose(reason),
                  ),
                const SizedBox(height: 8),
                CrawlTextField(
                  controller: _details,
                  hint: 'Add details (optional)',
                  maxLines: 3,
                  errorText: error == null
                      ? null
                      : "Couldn't send the report. "
                            '${AppErrorCopy.fromException(error).subtitle}',
                ),
                const SizedBox(height: 16),
                CrawlPrimaryButton(
                  label: 'Submit report',
                  busy: state.submitting,
                  onTap: state.canSubmit
                      ? () => cubit.submit(
                          widget.crawl.id,
                          details: _details.text,
                          reporterId:
                              Supabase.instance.client.auth.currentUser?.id,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ListsTokens.radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Icon(
                selected
                    ? PhosphorIcons.radioButton(PhosphorIconsStyle.fill)
                    : PhosphorIcons.circle(),
                size: 22,
                color: selected ? ListsTokens.brand : ListsTokens.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style:
                      (selected
                              ? context.textTheme.bodyLargeMed
                              : context.textTheme.bodyMedium)
                          ?.copyWith(color: ListsTokens.ink, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
