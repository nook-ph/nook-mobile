import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Added go_router import
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CafeDetailsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CafeDetailsAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 22.0),
        child: Center(
          child: GestureDetector(
            // You might also want to update this to context.pop()
            // if you are migrating everything to go_router
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.black,
                size: 18,
              ),
            ),
          ),
        ),
      ),
      actions: [
        Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                LucideIcons.share,
                color: Colors.black,
                size: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Center(
          child: GestureDetector(
            onTap: () {
              context.push('/login');
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                LucideIcons.heart,
                color: Colors.black,
                size: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 22),
      ],
    );
  }
}
