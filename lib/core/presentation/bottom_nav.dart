import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 1.0,
          ),
        ),
      ),
      child: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          elevation: 0,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          iconSize: 28.0,
          currentIndex: currentIndex, 
          onTap: onTap,               
          selectedItemColor: const Color(0xFF344E41), 
          unselectedItemColor: Colors.grey,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.house),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.search),
              label: "Search",
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.heart),
              label: "Favorites",
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.user),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}