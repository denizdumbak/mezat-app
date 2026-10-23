import '../features/auth/session.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const chooseUsername = '/choose-username';

  // The four tabs. Keşfet is home.
  static const home = '/';
  static const live = '/live';
  static const sell = '/sell';
  static const profile = '/profile';

  static const createAuction = '/auctions/new';
  static const liveRoomPattern = '/auctions/:id/live';
  static String liveRoom(String auctionId) => '/auctions/$auctionId/live';
}

const _signedOutRoutes = {AppRoutes.signIn, AppRoutes.signUp};

/// Where the user must be for [status], or null if [location] is fine.
///
/// This is the whole navigation guard of the app. It is a pure function so
/// every combination can be unit tested without a widget tree.
String? redirectFor(SessionStatus status, String location) {
  String? goTo(String target) => location == target ? null : target;

  return switch (status) {
    SessionStatus.loading ||
    SessionStatus.profileError => goTo(AppRoutes.splash),
    SessionStatus.signedOut =>
      _signedOutRoutes.contains(location) ? null : AppRoutes.signIn,
    SessionStatus.needsUsername => goTo(AppRoutes.chooseUsername),
    SessionStatus.ready =>
      _signedOutRoutes.contains(location) ||
              location == AppRoutes.splash ||
              location == AppRoutes.chooseUsername
          ? AppRoutes.home
          : null,
  };
}
