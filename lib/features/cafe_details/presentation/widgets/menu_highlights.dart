import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/pages/menu_full_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlight_card.dart';

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
              Text(
                'Menu Highlights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              AdaptiveTextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuFullPage(
                        menuItems: cafe?.allMenuItems ?? [],
                        highlights: cafe?.menuHighlights ?? [],
                        cafeName: cafe?.cafeDetails.name,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See All',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: MenuHighlightCard.listHeight,
          child: ListView.separated(
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
