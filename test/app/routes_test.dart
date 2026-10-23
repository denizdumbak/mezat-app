import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/app/routes.dart';
import 'package:mezat_app/features/auth/session.dart';

void main() {
  const all = [
    AppRoutes.splash,
    AppRoutes.signIn,
    AppRoutes.signUp,
    AppRoutes.chooseUsername,
    AppRoutes.home,
  ];

  /// Where the user ends up from [location]: the redirect target, or
  /// [location] itself when no redirect happens.
  String landing(SessionStatus status, String location) =>
      redirectFor(status, location) ?? location;

  test('loading and profile errors always show the splash screen', () {
    for (final status in [SessionStatus.loading, SessionStatus.profileError]) {
      for (final location in all) {
        expect(landing(status, location), AppRoutes.splash, reason: location);
      }
    }
  });

  test('signed out users can only see sign-in and sign-up', () {
    expect(
      landing(SessionStatus.signedOut, AppRoutes.signIn),
      AppRoutes.signIn,
    );
    expect(
      landing(SessionStatus.signedOut, AppRoutes.signUp),
      AppRoutes.signUp,
    );
    for (final location in [
      AppRoutes.splash,
      AppRoutes.chooseUsername,
      AppRoutes.home,
    ]) {
      expect(
        landing(SessionStatus.signedOut, location),
        AppRoutes.signIn,
        reason: location,
      );
    }
  });

  test('users without a username must choose one first', () {
    for (final location in all) {
      expect(
        landing(SessionStatus.needsUsername, location),
        AppRoutes.chooseUsername,
        reason: location,
      );
    }
  });

  test('ready users are sent home from auth screens', () {
    for (final location in all) {
      expect(
        landing(SessionStatus.ready, location),
        AppRoutes.home,
        reason: location,
      );
    }
  });

  test('ready users can stay on other pages', () {
    expect(redirectFor(SessionStatus.ready, '/auctions/42'), isNull);
  });
}
