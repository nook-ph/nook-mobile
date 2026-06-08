import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_state.dart';

class CrawlHomeBanner extends StatelessWidget {
  const CrawlHomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveCrawlsCubit, ActiveCrawlsState>(
      builder: (context, state) {
        return const SizedBox();
      },
    );
  }
}
