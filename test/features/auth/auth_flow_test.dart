import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auth_failure.dart';
import 'package:mezat_app/core/widgets/app_loader.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:mezat_app/features/auctions/discover_screen.dart';

import '../../helpers/fakes.dart';

const _userId = FakeAuthRepository.signedInUserId;

Future<void> _signIn(
  WidgetTester tester, {
  String email = 'deniz@example.com',
  String password = 'Passw0rd!',
}) async {
  await tester.enterText(find.byKey(const Key('signIn.email')), email);
  await tester.enterText(find.byKey(const Key('signIn.password')), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
  await tester.pumpAndSettle();
}

/// Sign-out lives on the Profil tab.
Future<void> _signOutFromProfile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab.3')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Çıkış yap'));
}

void main() {
  group('sign in', () {
    testWidgets('signed out users start on the sign-in screen', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());

      expect(find.byKey(const Key('signIn.email')), findsOneWidget);
    });

    testWidgets('invalid input is caught before any request', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth);

      await _signIn(tester, email: 'not-an-email', password: '');

      expect(find.text(AuthFailure.invalidEmail.message), findsOneWidget);
      expect(find.text('Şifreni gir.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('wrong credentials show a friendly message', (tester) async {
      final auth = FakeAuthRepository()
        ..nextError = AuthFailure.invalidCredentials;
      await pumpApp(tester, auth: auth);

      await _signIn(tester);

      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
      expect(find.byKey(const Key('signIn.email')), findsOneWidget);
    });

    testWidgets('no connection shows a network message', (tester) async {
      final auth = FakeAuthRepository()..nextError = AuthFailure.network;
      await pumpApp(tester, auth: auth);

      await _signIn(tester);

      expect(find.text(AuthFailure.network.message), findsOneWidget);
    });

    testWidgets('email is trimmed and lowercased before sending', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth);

      await _signIn(tester, email: '  Deniz@Example.com ');

      expect(auth.calls, ['signIn:deniz@example.com']);
    });

    testWidgets('a second tap while signing in is ignored', (tester) async {
      final auth = FakeAuthRepository()..gate = Completer<void>();
      await pumpApp(tester, auth: auth);

      await tester.enterText(
        find.byKey(const Key('signIn.email')),
        'deniz@example.com',
      );
      await tester.enterText(find.byKey(const Key('signIn.password')), 'pw');
      await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
      await tester.pump();

      // The button now shows a spinner and is disabled.
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(AppLoader), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);

      auth.gate!.complete();
      await tester.pumpAndSettle();
      expect(auth.calls, ['signIn:deniz@example.com']);
    });

    testWidgets('success without a username leads to choose-username', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository());

      await _signIn(tester);

      expect(find.byKey(const Key('chooseUsername.username')), findsOneWidget);
    });

    testWidgets('success with a username leads home', (tester) async {
      final profiles = FakeProfileRepository()
        ..profiles[_userId] = const Profile(id: _userId, username: 'deniz');
      await pumpApp(tester, auth: FakeAuthRepository(), profiles: profiles);

      await _signIn(tester);

      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(find.text('@deniz'), findsOneWidget);
    });
  });

  group('sign up', () {
    Future<void> openSignUp(WidgetTester tester) async {
      await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
      await tester.pumpAndSettle();
    }

    Future<void> fillSignUp(
      WidgetTester tester, {
      String email = 'Deniz@Example.com',
      String password = 'Passw0rd!',
      String? again,
    }) async {
      await tester.enterText(find.byKey(const Key('signUp.email')), email);
      await tester.enterText(
        find.byKey(const Key('signUp.password')),
        password,
      );
      await tester.enterText(
        find.byKey(const Key('signUp.passwordAgain')),
        again ?? password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
      await tester.pumpAndSettle();
    }

    testWidgets('mismatched or short passwords are caught', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth);
      await openSignUp(tester);

      await fillSignUp(tester, password: 'short', again: 'other');

      expect(find.text('Şifre en az 8 karakter olmalı.'), findsOneWidget);
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('success signs in and asks for a username', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth);
      await openSignUp(tester);

      await fillSignUp(tester);

      expect(auth.calls, ['signUp:deniz@example.com']);
      expect(find.byKey(const Key('chooseUsername.username')), findsOneWidget);
    });

    testWidgets('existing email is reported', (tester) async {
      final auth = FakeAuthRepository()
        ..nextError = AuthFailure.emailAlreadyRegistered;
      await pumpApp(tester, auth: auth);
      await openSignUp(tester);

      await fillSignUp(tester);

      expect(
        find.text(AuthFailure.emailAlreadyRegistered.message),
        findsOneWidget,
      );
    });

    testWidgets('with email confirmation on, the user is told to check mail', (
      tester,
    ) async {
      final auth = FakeAuthRepository()..requireEmailConfirmation = true;
      await pumpApp(tester, auth: auth);
      await openSignUp(tester);

      await fillSignUp(tester);

      expect(find.text(AuthFailure.emailNotConfirmed.message), findsOneWidget);
      expect(find.byKey(const Key('signUp.email')), findsOneWidget);
    });

    testWidgets('a sign-in error does not leak onto the sign-up form', (
      tester,
    ) async {
      final auth = FakeAuthRepository()
        ..nextError = AuthFailure.invalidCredentials;
      await pumpApp(tester, auth: auth);
      await _signIn(tester);
      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);

      await openSignUp(tester);

      expect(find.text('E-posta veya şifre hatalı.'), findsNothing);
    });
  });

  group('choose username', () {
    Future<void> submitUsername(WidgetTester tester, String username) async {
      await tester.enterText(
        find.byKey(const Key('chooseUsername.username')),
        username,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
      await tester.pumpAndSettle();
    }

    testWidgets('a taken username is reported, another one works', (
      tester,
    ) async {
      final profiles = FakeProfileRepository()
        ..profiles['someone-else'] = const Profile(
          id: 'someone-else',
          username: 'deniz',
        );
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedInAs: _userId),
        profiles: profiles,
      );

      await submitUsername(tester, 'Deniz');
      expect(find.text(AuthFailure.usernameTaken.message), findsOneWidget);

      await submitUsername(tester, ' Deniz_01 ');
      expect(find.text('@deniz_01'), findsOneWidget);
      expect(profiles.profiles[_userId]?.username, 'deniz_01');
    });

    testWidgets('an invalid username is caught before any request', (
      tester,
    ) async {
      final profiles = FakeProfileRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedInAs: _userId),
        profiles: profiles,
      );

      await submitUsername(tester, 'a b');

      expect(find.text(AuthFailure.invalidUsername.message), findsOneWidget);
      expect(profiles.profiles, isEmpty);
    });

    testWidgets('the user can sign out instead', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository(signedInAs: _userId));

      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signIn.email')), findsOneWidget);
    });
  });

  group('session', () {
    testWidgets('a restored session with a username opens home directly', (
      tester,
    ) async {
      final profiles = FakeProfileRepository()
        ..profiles[_userId] = const Profile(id: _userId, username: 'deniz');
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedInAs: _userId),
        profiles: profiles,
      );

      expect(find.text('@deniz'), findsOneWidget);
    });

    testWidgets('sign out from the profile tab returns to sign-in', (
      tester,
    ) async {
      final auth = FakeAuthRepository(signedInAs: _userId);
      final profiles = FakeProfileRepository()
        ..profiles[_userId] = const Profile(id: _userId, username: 'deniz');
      await pumpApp(tester, auth: auth, profiles: profiles);

      await _signOutFromProfile(tester);
      await tester.pumpAndSettle();

      expect(auth.calls, ['signOut']);
      expect(find.byKey(const Key('signIn.email')), findsOneWidget);
    });

    testWidgets('a failed sign out keeps the user signed in and says why', (
      tester,
    ) async {
      final auth = FakeAuthRepository(signedInAs: _userId)
        ..nextError = AuthFailure.network;
      final profiles = FakeProfileRepository()
        ..profiles[_userId] = const Profile(id: _userId, username: 'deniz');
      await pumpApp(tester, auth: auth, profiles: profiles);

      await _signOutFromProfile(tester);
      await tester.pumpAndSettle();

      expect(find.text(AuthFailure.network.message), findsOneWidget);
      expect(find.text('@deniz'), findsOneWidget);
    });

    testWidgets('a profile load error offers retry', (tester) async {
      final profiles = FakeProfileRepository()
        ..profiles[_userId] = const Profile(id: _userId, username: 'deniz')
        ..fetchError = AuthFailure.network;
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedInAs: _userId),
        profiles: profiles,
      );

      expect(find.text(AuthFailure.network.message), findsOneWidget);

      profiles.fetchError = null;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(find.text('@deniz'), findsOneWidget);
    });
  });
}
