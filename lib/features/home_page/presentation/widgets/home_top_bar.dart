import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/search/presentation/pages/search_results_page.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.border;

    return Padding(
      padding: const EdgeInsets.only(top: 46, left: 22, right: 22),
      child: Row(
        children: [
          Image.asset(
            'assets/logos/logoT.png',
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 20),

          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchResultsPage(query: ''),
                  ),
                );
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: const [
                    Icon(LucideIcons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Text("Search...", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
