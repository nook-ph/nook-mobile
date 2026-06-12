import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ShareCardFooter extends StatelessWidget {
  final String crawlTitle;

  const ShareCardFooter({super.key, required this.crawlTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: const Color(0xFF0F1F0F),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'nook',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
          const Gap(2),
          Text(
            crawlTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0x60FFFFFF),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
