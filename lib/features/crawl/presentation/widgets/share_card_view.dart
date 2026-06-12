import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_state.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/crawl_share_card.dart';

class ShareCardView extends StatelessWidget {
  const ShareCardView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShareCardCubit, ShareCardState>(
      builder: (context, state) {
        return switch (state) {
          ShareCardReady(:final data) => CrawlShareCard(data: data),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}
