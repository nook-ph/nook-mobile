import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';

class ShareCardStats extends StatelessWidget {
  final CrawlShareCardData data;

  const ShareCardStats({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1F0F),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          const Divider(color: Color(0xFF2A3E2A), thickness: 1, height: 1),
          const Gap(8),
          Flexible(
            child: Row(
              children: [
                Expanded(child: _Column(label: 'STOPS', value: _stopsValue)),
                Expanded(child: _Column(label: _middleLabel, value: _middleValue)),
                Expanded(child: _Column(label: 'CRAWL', value: _crawlValue)),
              ],
            ),
          ),
          const Gap(8),
          const Divider(color: Color(0xFF2A3E2A), thickness: 1, height: 1),
        ],
      ),
    );
  }

  String get _stopsValue {
    if (data.highestTier != null) {
      return '${data.totalStamps} of ${data.totalStops}';
    }
    return '${data.totalStamps}';
  }

  String get _middleLabel => data.highestTier != null ? 'TIER' : 'LATEST';

  String get _middleValue {
    if (data.highestTier != null) return data.highestTier!.name;
    final claimed = data.stops
        .where((s) => s.isClaimed && s.claimedAt != null)
        .toList();
    if (claimed.isEmpty) return '\u2014';
    return claimed
        .reduce((a, b) => a.claimedAt!.isAfter(b.claimedAt!) ? a : b)
        .cafeName;
  }

  String get _crawlValue => '${data.crawlTitle} \u00b7 ${data.crawlPeriod}';
}

class _Column extends StatelessWidget {
  final String label;
  final String value;

  const _Column({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            color: Color(0x80FFFFFF),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gap(4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            clipBehavior: Clip.antiAlias,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 26,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
