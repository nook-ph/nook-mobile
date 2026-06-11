import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_state.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_detail_cta.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_hero_header.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_progress_card.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_tiers_card.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CrawlDetailPage extends StatefulWidget {
  final String slug;

  const CrawlDetailPage({super.key, required this.slug});

  @override
  State<CrawlDetailPage> createState() => _CrawlDetailPageState();
}

class _CrawlDetailPageState extends State<CrawlDetailPage> {
  late final CrawlDetailCubit _cubit;
  bool _isFirstRouteChange = true;

  @override
  void initState() {
    super.initState();
    _cubit = sl<CrawlDetailCubit>()..loadDetail(widget.slug);
    GoRouter.of(context).routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    GoRouter.of(context).routerDelegate.removeListener(_onRouteChanged);
    _cubit.close();
    super.dispose();
  }

  void _onRouteChanged() {
    if (_isFirstRouteChange) {
      _isFirstRouteChange = false;
      return;
    }
    if (GoRouter.of(context).state.matchedLocation == '/crawl/${widget.slug}') {
      _cubit.loadDetail(widget.slug);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrawlDetailCubit>.value(
      value: _cubit,
      child: BlocConsumer<CrawlDetailCubit, CrawlDetailState>(
        listener: (context, state) {
          if (state is CrawlDetailRegisterSuccess) {
            showPrimaryToast(
              context,
              'Successfully registered for the crawl!',
            );
          }
        },
        builder: (context, state) {
          final isLoading =
              state is CrawlDetailInitial || state is CrawlDetailLoading;
          final detail = switch (state) {
            CrawlDetailLoaded(:final detail) => detail,
            CrawlDetailRegisterSuccess(:final detail) => detail,
            _ => null,
          };

          return switch (state) {
            CrawlDetailError(:final failure) => Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: Text(failure.message)),
            ),
            _ => Scaffold(
              backgroundColor: Colors.white,
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                leadingWidth: 70,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 22.0),
                  child: Center(
                    child: AppBarCircleIconButton(
                      icon: Icons.arrow_back,
                      iconSize: 18,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
              body: RefreshIndicator(
                onRefresh: () => _cubit.loadDetail(widget.slug),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Skeletonizer(
                    enabled: isLoading,
                    effect: const PulseEffect(),
                    child: Column(
                      children: [
                        CrawlHeroHeader(
                          crawl: detail?.crawl,
                          crawlImageUrl: detail?.crawl.coverImageUrl ?? '',
                          participantCount: detail?.crawl.totalStops,
                        ),
                        if (detail?.userProgress != null) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: CrawlProgressCard(
                              claimedStops: detail!.userProgress!.totalStamps,
                              totalStops: detail.stops.length,
                              currentTierName:
                                  detail.userProgress!.highestTier?.name ?? '',
                            ),
                          ),
                        ],
                        if (detail?.tiers != null && detail!.tiers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: CrawlTiersCard(tiers: detail.tiers),
                          ),
                        ],
                        SizedBox(
                          height: detail != null ? 80 : 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: detail != null
                  ? CrawlDetailCta(
                      isRegistered: detail.isRegistered,
                      allStopsClaimed:
                          detail.stops.every((CrawlStop s) => s.isClaimed),
                      onRegisterTap: () {
                        if (context.read<AuthBloc>().state
                            is AuthAuthenticated) {
                          _cubit.register();
                        } else {
                          context.push('/login');
                        }
                      },
                      onClaimStopTap: () {
                        final unclaimed = detail.stops.cast<CrawlStop?>().firstWhere(
                          (CrawlStop? s) => s != null && !s.isClaimed,
                          orElse: () => null,
                        );
                        if (unclaimed != null) {
                          context.push(
                            '/crawl/${detail.crawl.slug}/stop/${unclaimed.id}/claim',
                          );
                        }
                      },
                    )
                  : null,
            ),
          };
        },
      ),
    );
  }
}
