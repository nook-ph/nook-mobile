import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_bloc.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_event.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_state.dart';
import 'package:nook/injection_container.dart';

class StampClaimPage extends StatefulWidget {
  final String crawlSlug;
  final String stopId;
  final CrawlClaimBloc? bloc;

  const StampClaimPage({
    super.key,
    required this.crawlSlug,
    required this.stopId,
    this.bloc,
  });

  @override
  State<StampClaimPage> createState() => _StampClaimPageState();
}

class _StampClaimPageState extends State<StampClaimPage> {
  late final CrawlClaimBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = widget.bloc ?? sl<CrawlClaimBloc>();
    _bloc.add(
      ClaimInitialized(
        crawlId: widget.crawlSlug,
        stopId: widget.stopId,
        crawlTitle: '',
        cafeName: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrawlClaimBloc>.value(
      value: _bloc,
      child: BlocConsumer<CrawlClaimBloc, CrawlClaimState>(
        listener: (context, state) {
          if (state is ClaimSuccessWithTierCompletion) {
            // TODO: Show TierCompletionModal
          }
        },
        builder: (context, state) {
          return const Scaffold(
            body: Center(
              child: Text('Stamp Claim Page'),
            ),
          );
        },
      ),
    );
  }
}
