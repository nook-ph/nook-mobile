import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_by_code_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_preview_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/join_crawl_run_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crew_invite_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_detail_page.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_run_page.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/injection_container.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Where a crew invite lands: who started the run, which crawl, and a button
/// to join. Opened with the run's invite code.
class CrewInvitePage extends StatelessWidget {
  const CrewInvitePage({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CrewInviteCubit(
        getCrawlRunPreviewUseCase: sl<GetCrawlRunPreviewUseCase>(),
        getCrawlByCodeUseCase: sl<GetCrawlByCodeUseCase>(),
        joinCrawlRunUseCase: sl<JoinCrawlRunUseCase>(),
        analytics: sl<AnalyticsService>(),
      )..load(inviteCode),
      child: _CrewInviteView(inviteCode: inviteCode),
    );
  }
}

class _CrewInviteView extends StatelessWidget {
  const _CrewInviteView({required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the user comes back from sign-in.
    final signedIn = context.watch<AuthBloc>().state is AuthAuthenticated;

    return BlocConsumer<CrewInviteCubit, CrewInviteState>(
      listenWhen: (previous, current) =>
          previous.joinedRun != current.joinedRun ||
          (current.error != null && previous.error != current.error),
      listener: (context, state) {
        final run = state.joinedRun;
        if (run != null) {
          context.read<CrewInviteCubit>().consumeJoinedRun();
          context.read<MyCrawlsCubit>().load();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CrawlRunPage(runId: run.id, initial: run),
            ),
          );
          return;
        }
        final error = state.error;
        if (error != null && state.status == CrewInviteStatus.loaded) {
          showPrimaryToast(context, AppErrorCopy.fromException(error).title);
        }
      },
      builder: (context, state) {
        final preview = state.preview;
        return Scaffold(
          backgroundColor: ListsTokens.surface,
          appBar: AppBar(
            backgroundColor: ListsTokens.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: ListsTokens.surface,
            leading: AdaptiveTap(
              onTap: () => Navigator.of(context).pop(),
              child: Semantics(
                button: true,
                label: 'Close',
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(LucideIcons.x, size: 24, color: ListsTokens.ink),
                ),
              ),
            ),
          ),
          body: switch (state.status) {
            CrewInviteStatus.loading => const _Loading(),
            CrewInviteStatus.error => _Error(
              error: state.error,
              onRetry: () => context.read<CrewInviteCubit>().load(inviteCode),
            ),
            CrewInviteStatus.loaded => _Body(
              preview: preview!,
              crawl: state.crawl,
              full: state.isFull,
            ),
          },
          bottomNavigationBar:
              state.status != CrewInviteStatus.loaded || preview == null
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(
                    crawlGutter,
                    12,
                    crawlGutter,
                    8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _primaryButton(context, state, preview, signedIn),
                      const SizedBox(height: 6),
                      CrawlTextButton(
                        label: 'Not now',
                        color: ListsTokens.muted,
                        minHeight: 40,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _primaryButton(
    BuildContext context,
    CrewInviteState state,
    CrawlRunPreview preview,
    bool signedIn,
  ) {
    if (state.isFull) {
      return CrawlPrimaryButton(
        label: 'Start your own run',
        onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CrawlDetailPage(
              shareCode: preview.shareCode,
              initial: state.crawl,
            ),
          ),
        ),
      );
    }
    if (!signedIn) {
      return CrawlPrimaryButton(
        label: 'Sign in to join',
        onTap: () => context.push('/login'),
      );
    }
    return CrawlPrimaryButton(
      label: 'Join crew',
      busy: state.joining,
      onTap: () => context.read<CrewInviteCubit>().join(inviteCode),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.preview, required this.crawl, required this.full});

  final CrawlRunPreview preview;
  final Crawl? crawl;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final starter = preview.starterUsername;
    final spotsLeft = preview.crewLimit - preview.crewSize;

    // Figma: 14 between every block of the body.
    const gap = SizedBox(height: 14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(crawlGutter, 4, crawlGutter, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _StarterAvatar(
            username: starter,
            avatarUrl: preview.starterAvatarUrl,
          ),
        ),
        gap,
        Text(
          full
              ? 'This crew is full'
              : starter == null
              ? 'You are invited to a crawl'
              : '@$starter invited you to a crawl',
          style: crawlText(24, weight: FontWeight.w600),
        ),
        if (full) ...[
          gap,
          Text(
            'A crew holds up to ${preview.crewLimit} people. You can still do '
            'this crawl with your own crew.',
            style: crawlText(14, color: ListsTokens.muted),
          ),
        ],
        gap,
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ListsTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.title,
                style: crawlText(16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(_meta(), style: crawlText(12, color: ListsTokens.muted)),
              for (final stop in crawl?.stops ?? const <CrawlStop>[]) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    CrawlNumberBadge(
                      number: stop.order,
                      size: 22,
                      background: crawlTint,
                      foreground: ListsTokens.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: crawlText(14),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        gap,
        Row(
          children: [
            const Icon(LucideIcons.users, size: 22, color: ListsTokens.brand),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${preview.crewSize} going',
                  style: crawlText(12, weight: FontWeight.w500),
                ),
                Text(
                  full || spotsLeft <= 0
                      ? 'No spots left'
                      : spotsLeft == 1
                      ? '1 spot left'
                      : '$spotsLeft spots left',
                  style: crawlText(10, color: ListsTokens.muted),
                ),
              ],
            ),
          ],
        ),
        if (!full) ...[
          gap,
          Text(
            'Your crew sees which stops you stamp. Nobody else does.',
            style: crawlText(12, color: ListsTokens.muted),
          ),
        ],
      ],
    );
  }

  /// "5 stops · IT Park · Saturday, Oct 3", dropping what is not known.
  String _meta() {
    final area = crawl?.stops.firstOrNull?.neighborhood ?? '';
    final planned = preview.plannedFor;
    return [
      '${preview.stopCount} stops',
      if (area.isNotEmpty) area,
      if (planned != null) _formatDay(planned),
    ].join(' · ');
  }

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatDay(DateTime day) =>
      '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}';
}

class _StarterAvatar extends StatelessWidget {
  const _StarterAvatar({required this.username, required this.avatarUrl});

  final String? username;
  final String? avatarUrl;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final name = username?.trim() ?? '';
    final initial = Container(
      color: ListsTokens.brand,
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ListsTokens.surface,
          height: 1,
        ),
      ),
    );
    final url = avatarUrl?.trim() ?? '';
    return ClipOval(
      child: SizedBox.square(
        dimension: _size,
        child: url.isEmpty
            ? initial
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => initial,
                errorWidget: (_, _, _) => initial,
              ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(crawlGutter, 4, crawlGutter, 24),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: CrawlSkeleton(width: 56, height: 56, radius: 28),
        ),
        const SizedBox(height: 16),
        const CrawlSkeleton(height: 26),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ListsTokens.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CrawlSkeleton(width: 180, height: 18),
              SizedBox(height: 12),
              CrawlSkeleton(width: 140, height: 12),
              SizedBox(height: 16),
              CrawlSkeleton(width: 200, height: 14),
              SizedBox(height: 14),
              CrawlSkeleton(width: 170, height: 14),
              SizedBox(height: 14),
              CrawlSkeleton(width: 190, height: 14),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: CrawlSkeleton(width: 120, height: 28),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error is CrawlNotFound) {
      return CrawlStateView(
        icon: CrawlStateView.goneIcon,
        title: 'This invite is no longer available',
        subtitle: 'The run may have ended. Ask for a fresh invite.',
        primaryLabel: 'Back',
        onPrimary: () => Navigator.of(context).pop(),
      );
    }
    final info = AppErrorCopy.fromException(error ?? Exception());
    final sessionExpired = info.type == ErrorType.sessionExpired;
    return CrawlStateView(
      icon: switch (info.type) {
        ErrorType.offline => CrawlStateView.offlineIcon,
        ErrorType.sessionExpired => CrawlStateView.lockedIcon,
        _ => CrawlStateView.alertIcon,
      },
      title: info.title,
      subtitle: info.subtitle,
      primaryLabel: sessionExpired ? 'Sign in' : 'Try again',
      primaryFilled: sessionExpired,
      onPrimary: sessionExpired ? () => context.push('/login') : onRetry,
      secondaryLabel: 'Back',
      onSecondary: () => Navigator.of(context).pop(),
    );
  }
}
