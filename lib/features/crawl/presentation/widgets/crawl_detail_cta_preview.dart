import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_detail_cta.dart';

Widget _buildPreview({
  required bool isRegistered,
  bool allStopsClaimed = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: const Center(child: Text('Preview')),
      bottomNavigationBar: CrawlDetailCta(
        isRegistered: isRegistered,
        allStopsClaimed: allStopsClaimed,
        onRegisterTap: () {},
        onClaimStopTap: () {},
      ),
    ),
    theme: ThemeData.light(),
  );
}

@Preview(name: 'Unregistered - Register CTA', group: 'Crawl Detail CTA')
Widget unregisteredCta() {
  return _buildPreview(isRegistered: false);
}

@Preview(name: 'Registered - Claim Stop', group: 'Crawl Detail CTA')
Widget registeredCta() {
  return _buildPreview(isRegistered: true, allStopsClaimed: false);
}

@Preview(name: 'Registered - All Claimed', group: 'Crawl Detail CTA')
Widget allClaimedCta() {
  return _buildPreview(isRegistered: true, allStopsClaimed: true);
}
