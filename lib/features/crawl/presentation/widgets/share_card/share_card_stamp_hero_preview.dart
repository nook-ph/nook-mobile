import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_stamp_hero.dart';

@Preview(name: 'Default no cafe logo', group: 'Share Card Stamp Hero')
@Preview(name: 'With cafe logo', group: 'Share Card Stamp Hero')
Widget shareCardStampHeroPreview() {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ShareCardStampHero(),
            const SizedBox(height: 16),
            ShareCardStampHero(
              cafeLogoUrl:
                  'https://lucerocris.sgp1.cdn.digitaloceanspaces.com/cafe-brindle-logo.png',
            ),
          ],
        ),
      ),
    ),
  );
}
