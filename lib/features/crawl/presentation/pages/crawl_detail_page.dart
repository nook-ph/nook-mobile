import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_state.dart';
import 'package:nook/injection_container.dart';

class CrawlDetailPage extends StatelessWidget {
  final String slug;

  const CrawlDetailPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrawlDetailCubit>(
      create: (_) => sl<CrawlDetailCubit>()..loadDetail(slug),
      child: BlocBuilder<CrawlDetailCubit, CrawlDetailState>(
        builder: (context, state) {
          return const Scaffold(
            body: Center(
              child: Text('Crawl Detail Page'),
            ),
          );
        },
      ),
    );
  }
}
