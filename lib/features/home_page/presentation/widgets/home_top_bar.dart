import 'package:flutter/material.dart';
import 'package:nook/features/search/presentation/widgets/search_entry_button.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, left: 22, right: 22),
      child: Row(
        children: [
          Image.asset(
            'assets/logos/logoT.png',
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 20),
          const Expanded(child: SearchEntryButton()),
        ],
      ),
    );
  }
}
