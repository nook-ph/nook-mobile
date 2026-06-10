import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_state.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_hero_header.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CrawlDetailPage extends StatelessWidget {
  final String slug;

  const CrawlDetailPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrawlDetailCubit>(
      create: (_) => sl<CrawlDetailCubit>()..loadDetail(slug),
      child: BlocBuilder<CrawlDetailCubit, CrawlDetailState>(
        builder: (context, state) {
          final isLoading =
              state is CrawlDetailInitial || state is CrawlDetailLoading;
          final detail = state is CrawlDetailLoaded ? state.detail : null;

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
              body: SingleChildScrollView(
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
                    ],
                  ),
                ),
              ),
            ),
          };
        },
      ),
    );
  }
}
