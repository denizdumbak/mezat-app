// Drives the real app (real main(), real Supabase) through the M1 flow.
//
// Needs `npx supabase start`. Run on the desktop or a device:
//   flutter test integration_test -d windows --dart-define-from-file=.env
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mezat_app/core/auth_failure.dart';
import 'package:mezat_app/main.dart' as app;
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
    // A session saved by an earlier run opens home or choose-username instead
    // of sign-in. Wait for the first real screen before signing out: Supabase
    // restores the saved session in the background, and a sign-out sent
    // before that finishes is undone by the restore.
    final signInEmail = find.byKey(const Key('signIn.email'));
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key == const Key('signIn.email') ||
            w.key == const Key('chooseUsername.username') ||
            (w is Tooltip && w.message == 'Çıkış yap'),
      ),
    );
    if (signInEmail.evaluate().isEmpty) {
      await Supabase.instance.client.auth.signOut();
    }
    await pumpUntilFound(tester, signInEmail);

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

    // Sign out.
    await tester.tap(find.byTooltip('Çıkış yap'));
    await pumpUntilFound(tester, find.byKey(const Key('signIn.email')));

    // Sign in again with the address as typed at sign-up: straight home.
    await tester.enterText(
      find.byKey(const Key('signIn.email')),
      '  ${email.toUpperCase()} ',
    );
    await tester.enterText(find.byKey(const Key('signIn.password')), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await pumpUntilFound(tester, find.text('@$username'));
    expect(find.text('Canlı mezatlar yakında burada.'), findsOneWidget);
  });
}
