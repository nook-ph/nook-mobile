import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_stamp_hero.dart';

@Preview(name: 'Cafe Brindle, Stop 3', group: 'Share Card Stamp Hero')
Widget shareCardStampHeroPreview() {
  return const MaterialApp(
    home: Scaffold(
      backgroundColor: Color(0xFF0F1F0F),
      body: Center(
        child: ShareCardStampHero(
          cafeName: 'Cafe Brindle',
          stopNumber: 3,
        ),
      ),
    ),
  );
}
