import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/discovery_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/core/presentation/tab_back.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
import 'package:nook/features/home_page/presentation/pages/home_page.dart';
import 'package:nook/features/guest_saves/presentation/pages/saved_tab.dart';
import 'package:nook/features/home_widget/presentation/widget_link_opener.dart';
import 'package:nook/features/home_widget/presentation/widget_links.dart';
import 'package:nook/features/map/presentation/pages/map_page.dart';
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
        const SavedTab(),
        ProfileRedesignPage(isActive: tabIndex == 3),
      ],
    );
  }
}

/// The tab bar and the page stack behind it. Split from [MainScreen] so the
/// tab rules can be tested without the real pages or a Supabase session.
class MainShell extends StatefulWidget {
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

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Tabs that have been opened. A tab is built on its first visit and kept
  /// alive from then on, so a cold start pays for Home alone: no native map
  /// and no Saved or Profile requests for tabs nobody has looked at.
  final Set<int> _visited = {};

  /// The tab last reported as a screen, so a rebuild does not report it again.
  int? _reportedTab;

  /// Tabs live inside the one root route, so the route observer never sees
  /// a switch: each tab is reported as its own screen from here.
  void _reportTab(BuildContext context, int index) {
    if (_reportedTab == index) return;
    _reportedTab = index;
    ScreenTracker.instance.showRoot(
      ScreenNames.tabs[index],
      onTop: ModalRoute.of(context)?.isCurrent ?? true,
    );
  }

  /// Profile needs an account: a guest gets the sign-in sheet and stays on
  /// the tab they were on. Saved opens for everyone; a guest sees the saves
  /// kept on this phone ([SavedTab]).
  void _onTabTap(BuildContext context, int index) {
    final from = context.read<NavigationBloc>().state.tabIndex;
    final needsAccount =
        index == MainShell.profileTab && !widget.isAuthenticated();
    logAppEvent(
      NavEvents.tabTapped,
      properties: {
        'tab': ScreenNames.tabs[index],
        'from_tab': ScreenNames.tabs[from],
        'result': needsAccount
            ? 'sign_in_required'
            : index == from
            ? 'reselected'
            : 'switched',
      },
    );

    if (needsAccount) {
      GuestSignInSheet.show(
        context,
        icon: LucideIcons.userRound,
        title: 'Sign in to see your profile',
        reason:
            'Your cups, lists and rankings live in one place once you '
            'have an account.',
        trigger: 'profile_tab',
      );
      return;
    }

    context.read<NavigationBloc>().add(TabChange(tabIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NavigationBloc(),
      child: Builder(
        builder: (context) => WidgetLinkOpener(
          onLink: (link) => _openWidgetLink(context, link),
          child: _tabs(),
        ),
      ),
    );
  }

  /// A tap on the home-screen widget: a cafe opens over Home, the header
  /// opens Saved, the empty state Home.
  void _openWidgetLink(BuildContext context, WidgetLink link) {
    final location = link.location;
    if (location != null) {
      context.read<NavigationBloc>().add(TabChange(tabIndex: 0));
      // Already on top (the same tap reopened before its stack was
      // replaced): do not stack the cafe twice.
      final top = GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.uri.path;
      if (top != location) context.push(location);
      return;
    }
    context.read<NavigationBloc>().add(
      TabChange(
        tabIndex: link.target == WidgetLinkTarget.saved
            ? MainShell.savedTab
            : 0,
      ),
    );
  }

  Widget _tabs() {
    return BlocBuilder<NavigationBloc, NavigationState>(
      builder: (context, state) {
        _visited.add(state.tabIndex);
        _reportTab(context, state.tabIndex);
        final pages = widget.pagesBuilder(state.tabIndex);
        // System Back on Map, Saved or Profile goes to Home first, as in
        // other tabbed apps; only Back on Home leaves the app. PopScope
        // only acts while this route is on top, so pushed pages pop
        // normally.
        return PopScope(
          canPop: state.tabIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            // The tab may close something of its own first (the Map's
            // cafe card); the next Back then goes Home.
            if (TabBack.handle(state.tabIndex)) return;
            context.read<NavigationBloc>().add(TabChange(tabIndex: 0));
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            body: IndexedStack(
              index: state.tabIndex,
              children: [
                for (var i = 0; i < pages.length; i++)
                  _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: BottomNav(
              currentIndex: state.tabIndex,
              onTap: (index) => _onTabTap(context, index),
            ),
          ),
        );
      },
    );
  }
}
