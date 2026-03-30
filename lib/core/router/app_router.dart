import 'package:go_router/go_router.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/features/auth/presentation/pages/email_entry_page.dart';



final GoRouter appRouter = GoRouter(
    initialLocation: '/',

    routes: [
        GoRoute(path: '/', builder: (context, state) => const MainScreen(),),

        GoRoute(path: 'login', builder: (context, state) => const EmailEntryScreen()),
    ]
)
