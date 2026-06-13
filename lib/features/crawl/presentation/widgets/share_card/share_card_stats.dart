import 'package:flutter/material.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';

class ShareCardStats extends StatelessWidget {
  final CrawlShareCardData data;

  const ShareCardStats({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _StatRow(label: 'STOPS', value: _stopsWidget),
          _StatRow(
            label: 'CRAWL',
            value: Text(
              data.crawlTitle,
              textAlign: TextAlign.center,
            ),
          ),

        ],
      ),
    );
  }

  Widget get _stopsWidget => Text.rich(
        TextSpan(
          text: '${data.totalStamps}',
          children: [
            TextSpan(
              text: ' of ',
              style: const TextStyle(color: Colors.white),
            ),
            TextSpan(text: '${data.totalStops}'),
          ],
        ),
        textAlign: TextAlign.center,
      );
}

class _StatRow extends StatelessWidget {
  final String label;
  final Widget value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.0,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            child: value,
          ),
        ],
      ),
    );
  }
}
