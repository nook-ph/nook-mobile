import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/search/presentation/pages/search_page.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea (
        child: Column(
          children: [
            _buildTopBar(context)
          ],
        )
      )
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Image.asset('assets/logos/logoT.png', height: 28, fit: BoxFit.contain),
          const SizedBox(width: 20),
          
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const SearchPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              child: Hero(
                tag: 'search_bar_hero', 
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        Icon(LucideIcons.search, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Search...", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBottomNav() {
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
          selectedItemColor: const Color(0xFF344E41), 
          unselectedItemColor: Colors.grey,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.house), 
              label: "Home"
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.search), 
              label: "Search"
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.heart), 
              label: "Favorites"
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.user), 
              label: "Profile"
            ),
          ],
        ),
      ),
    );
  }
}

