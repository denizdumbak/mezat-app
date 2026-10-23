// Drives the real app (real main(), real Supabase) through the M1 flow.
//
// Needs `npx supabase start`. Run on the desktop or a device:
//   flutter test integration_test -d windows --dart-define-from-file=.env
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mezat_app/core/auth_failure.dart';
import 'package:mezat_app/features/auctions/discover_screen.dart';
import 'package:mezat_app/main.dart' as app;

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up, choose username, sign out, sign in again', (
    tester,
  ) async {
    final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final email = 'it_$run@example.com';
    final username = 'it_$run';
    const password = 'Passw0rd!x';

    await app.main();
    await startSignedOut(tester);

    // Wrong password for an unknown account: friendly message, no crash.
    await tester.enterText(find.byKey(const Key('signIn.email')), email);
    await tester.enterText(find.byKey(const Key('signIn.password')), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await pumpUntilFound(
      tester,
      find.text(AuthFailure.invalidCredentials.message),
    );

    // Sign up, with spaces and capitals in the email.
    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await pumpUntilFound(tester, find.byKey(const Key('signUp.email')));
    await tester.enterText(
      find.byKey(const Key('signUp.email')),
      '  ${email.toUpperCase()} ',
    );
    await tester.enterText(find.byKey(const Key('signUp.password')), password);
    await tester.enterText(
      find.byKey(const Key('signUp.passwordAgain')),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('chooseUsername.username')),
    );

    // Choose a username.
    await tester.enterText(
      find.byKey(const Key('chooseUsername.username')),
      username.toUpperCase(),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
    await pumpUntilFound(tester, find.text('@$username'));

    // Sign out, from the Profil tab.
    await tester.tap(find.byKey(const Key('tab.3')));
    await pumpUntilFound(tester, find.text('Çıkış yap'));
    await tester.tap(find.text('Çıkış yap'));
    await pumpUntilFound(tester, find.byKey(const Key('signIn.email')));

    // Sign in again with the address as typed at sign-up: straight home.
    await tester.enterText(
      find.byKey(const Key('signIn.email')),
      '  ${email.toUpperCase()} ',
    );
    await tester.enterText(find.byKey(const Key('signIn.password')), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await pumpUntilFound(tester, find.text('@$username'));
    expect(find.byType(DiscoverScreen), findsOneWidget);
  });
}
