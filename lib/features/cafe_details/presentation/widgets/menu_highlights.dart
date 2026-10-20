import 'package:flutter/material.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/widgets/prototype_height.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/pages/menu_full_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlight_card.dart';
import 'package:nook/core/analytics/screen_tracking.dart';

class MenuHighlights extends StatelessWidget {
  const MenuHighlights({super.key, required this.width, required this.cafe});

  final double width;
  final CafeDetailsResult? cafe;

  @override
  Widget build(BuildContext context) {
    final highlights = cafe?.menuHighlights ?? const [];

    if (highlights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expanded: at large text the title gives way to "See all"
              // instead of pushing it off the row.
              const Expanded(child: CafeSectionTitle('Menu highlights')),
              AdaptiveTextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: ScreenNames.cafeMenu),
                      builder: (context) => MenuFullPage(
                        menuItems: cafe?.allMenuItems ?? [],
                        cafeName: cafe?.cafeDetails.name,
                      ),
                    ),
                  );
                },
                // A 44 target around the label; the row grows to fit it.
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See all',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: CafeDetailsTokens.brand,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 12 under the label; the 44 row already holds 10 of it.
        const SizedBox(height: 2),

        PrototypeHeight(
          prototype: MenuHighlightCard(
            item: MenuHighlightCard.prototypeItem,
            width: width,
          ),
          listView: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: highlights.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                MenuHighlightCard(item: highlights[index], width: width),
          ),
        ),
      ],
    );
  }
}
