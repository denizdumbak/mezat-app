import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/features/auctions/discover_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pumps frames until [finder] matches; real network calls do not finish
/// inside a single pumpAndSettle.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

/// After app.main(): waits for the first real screen and signs out if an
/// earlier run left a session, so the test starts on sign-in.
///
/// Supabase restores a saved session in the background; a sign-out sent
/// before that finishes is undone by the restore, hence the wait.
Future<void> startSignedOut(WidgetTester tester) async {
  final signInEmail = find.byKey(const Key('signIn.email'));
  await pumpUntilFound(
    tester,
    find.byWidgetPredicate(
      (w) =>
          w.key == const Key('signIn.email') ||
          w.key == const Key('chooseUsername.username') ||
          w is DiscoverScreen,
    ),
  );
  if (signInEmail.evaluate().isEmpty) {
    await Supabase.instance.client.auth.signOut();
  }
  await pumpUntilFound(tester, signInEmail);
}
