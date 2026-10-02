import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
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
    return MainShell(
      isAuthenticated: () =>
          Supabase.instance.client.auth.currentSession != null,
      pagesBuilder: (tabIndex) => [
        const HomePage(),
        MapPage(isActive: tabIndex == 1),
        const ListsPage(showBackButton: false),
        ProfileRedesignPage(key: ValueKey('profile_tab_${tabIndex == 3}')),
      ],
    );
  }
}

/// The tab bar and the page stack behind it. Split from [MainScreen] so the
/// tab rules can be tested without the real pages or a Supabase session.
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.isAuthenticated,
    required this.pagesBuilder,
  });

  /// Read on every tab tap, so signing in mid-session takes effect at once.
  final bool Function() isAuthenticated;

  /// The four tab pages, in `BottomNav.tabs` order, for the selected index.
  final List<Widget> Function(int tabIndex) pagesBuilder;

  static const savedTab = 2;
  static const profileTab = 3;

  /// Saved and Profile need an account. A guest gets the sign-in sheet and
  /// stays on the tab they were on.
  void _onTabTap(BuildContext context, int index) {
    if ((index == savedTab || index == profileTab) && !isAuthenticated()) {
      if (index == savedTab) {
        GuestSignInSheet.show(
          context,
          icon: LucideIcons.bookmark,
          title: 'Sign in to save cafes',
          reason: 'Keep lists, mark the places you have been, and rank them.',
        );
      } else {
        GuestSignInSheet.show(
          context,
          icon: LucideIcons.userRound,
          title: 'Sign in to see your profile',
          reason:
              'Your reviews, lists and rankings live in one place once you '
              'have an account.',
        );
      }
      return;
    }

    context.read<NavigationBloc>().add(TabChange(tabIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NavigationBloc(),
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: IndexedStack(
              index: state.tabIndex,
              children: pagesBuilder(state.tabIndex),
            ),
            bottomNavigationBar: BottomNav(
              currentIndex: state.tabIndex,
              onTap: (index) => _onTabTap(context, index),
            ),
          );
        },
      ),
    );
  }
}
