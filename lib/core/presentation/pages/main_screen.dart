import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/features/favorites/presentation/page/favorites_page.dart';
import 'package:nook/features/home_page/presentation/pages/home_page.dart';
import 'package:nook/features/map/presentation/map_page.dart';
import 'package:nook/features/profile/presentation/pages/profile_page.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  final List<Widget> _pages = const [
    HomePage(),
    MapPage(),
    FavoritesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NavigationBloc(),
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.white,

            body: IndexedStack(index: state.tabIndex, children: _pages),

            bottomNavigationBar: BottomNav(
              currentIndex: state.tabIndex,
              onTap: (index) {
                context.read<NavigationBloc>().add(TabChange(tabIndex: index));
              },
            ),
          );
        },
      ),
    );
  }
}
