import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/features/home_page/presentation/pages/home_page.dart';
import 'package:nook/features/lists/presentation/pages/list_page.dart';
import 'package:nook/features/map/presentation/pages/map_page.dart';
import 'package:nook/features/profile/presentation/pages/profile_page.dart';
import 'package:nook/features/profile/presentation/pages/profile_pagev2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NavigationBloc(),
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, state) {
          final pages = [
            const HomePage(),
            MapPage(key: ValueKey('map_tab_${state.tabIndex == 1}')),
            const ListsPage(showBackButton: false),
            ProfileRedesignPage(
              key: ValueKey('profile_tab_${state.tabIndex == 3}'),
            ),
          ];

          return Scaffold(
            backgroundColor: Colors.white,
            body: IndexedStack(index: state.tabIndex, children: pages),
            bottomNavigationBar: BottomNav(
              currentIndex: state.tabIndex,
              onTap: (index) {
                final isProtectedTab = index == 2 || index == 3;
                final isAuthenticated =
                    Supabase.instance.client.auth.currentSession != null;

                if (isProtectedTab && !isAuthenticated) {
                  context.push('/login');
                  return;
                }

                context.read<NavigationBloc>().add(TabChange(tabIndex: index));
              },
            ),
          );
        },
      ),
    );
  }
}
