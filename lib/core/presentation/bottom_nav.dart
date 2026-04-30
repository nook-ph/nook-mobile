import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
          items: [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.house()),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.magnifyingGlass()),
              label: "Search",
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.bookmarkSimple()),
              label: "Saved",
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.user()),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}