// Runs the real repositories against the local Supabase stack, so the error
// mapping and RLS behaviour the widget tests assume are proven on the server.
//
// Needs `npx supabase start`. Not part of `flutter test` (CI has no Supabase):
//   flutter test test_supabase --dart-define-from-file=.env
@Tags(['supabase'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auth_failure.dart';
import 'package:mezat_app/core/env.dart';
import 'package:mezat_app/data/auth_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final env = Env.fromDefines();
  // Unique per run, so the test never collides with earlier data.
  final run = Random().nextInt(1 << 32).toRadixString(36);
  const password = 'Passw0rd!x';

  // Supabase.initialize gives the app a persistent storage for the PKCE flow;
  // a bare client in a test needs one passed in.
  SupabaseClient newClient() => SupabaseClient(
    env.supabaseUrl,
    env.supabaseAnonKey,
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: _MemoryStorage(),
    ),
  );

  late SupabaseClient alice;
  late SupabaseClient bob;
  late AuthRepository aliceAuth;
  late String aliceId;

  setUpAll(() async {
    alice = newClient();
    bob = newClient();
    aliceAuth = AuthRepository(alice.auth);
    expect(
      await aliceAuth.signUp(
        email: 'alice_$run@example.com',
        password: password,
      ),
      isTrue,
      reason: 'email confirmation is off locally, so sign-up signs in',
    );
    aliceId = aliceAuth.currentUserId!;
    await AuthRepository(
      bob.auth,
    ).signUp(email: 'bob_$run@example.com', password: password);
  });

  tearDownAll(() async {
    await alice.dispose();
    await bob.dispose();
  });

  group('AuthRepository', () {
    test('sign-up with an existing email is emailAlreadyRegistered', () async {
      final client = newClient();
      addTearDown(client.dispose);
      await expectLater(
        AuthRepository(
          client.auth,
        ).signUp(email: 'alice_$run@example.com', password: password),
        throwsA(AuthFailure.emailAlreadyRegistered),
      );
    });

    test('a 7-character password is weakPassword', () async {
      final client = newClient();
      addTearDown(client.dispose);
      await expectLater(
        AuthRepository(
          client.auth,
        ).signUp(email: 'weak_$run@example.com', password: '1234567'),
        throwsA(AuthFailure.weakPassword),
      );
    });

    test('wrong password and unknown email look the same', () async {
      final client = newClient();
      addTearDown(client.dispose);
      final auth = AuthRepository(client.auth);
      await expectLater(
        auth.signIn(email: 'alice_$run@example.com', password: 'wrong-pass'),
        throwsA(AuthFailure.invalidCredentials),
      );
      await expectLater(
        auth.signIn(email: 'nobody_$run@example.com', password: password),
        throwsA(AuthFailure.invalidCredentials),
      );
    });

    test('sign out, then sign in again with the same password', () async {
      final client = newClient();
      addTearDown(client.dispose);
      final auth = AuthRepository(client.auth);
      await auth.signIn(email: 'alice_$run@example.com', password: password);
      expect(auth.currentUserId, aliceId);
      await auth.signOut();
      expect(auth.currentUserId, isNull);
      await auth.signIn(email: 'alice_$run@example.com', password: password);
      expect(auth.currentUserId, aliceId);
    });

    test('an unreachable server is a network failure', () async {
      final client = SupabaseClient(
        'http://127.0.0.1:1',
        env.supabaseAnonKey,
        authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
      );
      addTearDown(client.dispose);
      await expectLater(
        AuthRepository(
          client.auth,
        ).signIn(email: 'alice_$run@example.com', password: password),
        throwsA(AuthFailure.network),
      );
    });
  });

  group('ProfileRepository', () {
    test('a new user has a profile without a username', () async {
      final profile = await ProfileRepository(alice).fetchProfile(aliceId);
      expect(profile?.id, aliceId);
      expect(profile?.username, isNull);
    });

    test('setUsername stores the normalized name', () async {
      final profile = await ProfileRepository(
        alice,
      ).setUsername(userId: aliceId, username: '  A_$run ');
      expect(profile.username, 'a_$run');
    });

    test('a taken username is usernameTaken, regardless of case', () async {
      await expectLater(
        ProfileRepository(bob).setUsername(
          userId: bob.auth.currentUser!.id,
          username: 'A_$run'.toUpperCase(),
        ),
        throwsA(AuthFailure.usernameTaken),
      );
    });

    test('a malformed username is invalidUsername', () async {
      await expectLater(
        ProfileRepository(
          bob,
        ).setUsername(userId: bob.auth.currentUser!.id, username: 'a b'),
        throwsA(AuthFailure.invalidUsername),
      );
    });

    test("RLS: bob cannot set alice's username", () async {
      await expectLater(
        ProfileRepository(bob).setUsername(userId: aliceId, username: 'stolen'),
        throwsA(AuthFailure.unknown), // zero rows updated -> .single() fails
      );
      final profile = await ProfileRepository(alice).fetchProfile(aliceId);
      expect(profile?.username, 'a_$run');
    });
  });
}

class _MemoryStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _values[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _values.remove(key);
}
