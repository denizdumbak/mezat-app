import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auctions/create_auction_screen.dart';
import '../features/auctions/discover_screen.dart';
import '../features/auctions/sell_screen.dart';
import '../features/auth/choose_username_screen.dart';
import '../features/auth/session.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/bids/my_bids_screen.dart';
import '../features/live_room/live_room_screen.dart';
import '../features/profile/profile_screen.dart';
import 'app_shell.dart';
import 'design_tokens.dart';
import 'routes.dart';
import 'theme.dart';

export 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // go_router re-runs `redirect` whenever this notifier changes, so every
  // sign-in, sign-out or username change moves the user to the right screen.
  final status = ValueNotifier(ref.read(sessionStatusProvider));
  ref.listen(sessionStatusProvider, (_, next) => status.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: status,
    redirect: (context, state) =>
        redirectFor(status.value, state.matchedLocation),
    routes: [
      _route(AppRoutes.splash, (_) => const SplashScreen()),
      _route(AppRoutes.signIn, (_) => const SignInScreen()),
      _route(AppRoutes.signUp, (_) => const SignUpScreen()),
      _route(AppRoutes.chooseUsername, (_) => const ChooseUsernameScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          _tab(AppRoutes.home, const DiscoverScreen()),
          _tab(AppRoutes.sell, const SellScreen()),
          _tab(AppRoutes.bids, const MyBidsScreen()),
          _tab(AppRoutes.profile, const ProfileScreen()),
        ],
      ),
      // Full screen, above the tab bar.
      _route(AppRoutes.createAuction, (_) => const CreateAuctionScreen()),
      // The one dark screen: the video is the stage. Sheets opened from here
      // capture this theme too.
      _route(
        AppRoutes.liveRoomPattern,
        (state) => Theme(
          data: liveTheme,
          child: LiveRoomScreen(auctionId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    status.dispose();
  });
  return router;
});

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      // Switching tabs is instant; only pushed pages animate.
      pageBuilder: (context, state) => NoTransitionPage(child: screen),
    ),
  ],
);

GoRoute _route(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: build(state),
        transitionDuration: AppDurations.entry,
        reverseTransitionDuration: AppDurations.entry,
        transitionsBuilder: _transition,
      ),
    );

/// Enter: fade in and rise a little (ease-out). Leave: the reverse
/// (ease-in). With reduced motion, opacity only.
Widget _transition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: AppCurves.enter,
    reverseCurve: AppCurves.exit,
  );
  final faded = FadeTransition(opacity: curved, child: child);
  if (!motionAllowed(context)) return faded;
  return SlideTransition(
    position: Tween(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curved),
    child: faded,
  );
}
