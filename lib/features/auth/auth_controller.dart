import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_failure.dart';
import '../../data/auth_repository.dart';
import '../../data/profile_repository.dart';
import 'session.dart';
import 'validators.dart';

/// The forms that run auth actions. Each gets its own controller instance, so
/// an error on the sign-in form does not show up on the sign-up form.
enum AuthForm { signIn, signUp, chooseUsername, signOut }

final authControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AuthController, void, AuthForm>(AuthController.new);

/// Runs one auth action at a time and exposes its progress to the form:
/// loading while it runs, an [AuthFailure] if it failed.
///
/// On success it does not navigate: the session changes, and the router's
/// redirect moves the user to the right screen.
class AuthController extends AsyncNotifier<void> {
  AuthController(this.form);

  final AuthForm form;

  @override
  FutureOr<void> build() {}

  Future<void> signIn({required String email, required String password}) =>
      _run(
        () => ref
            .read(authRepositoryProvider)
            .signIn(email: normalizeEmail(email), password: password),
      );

  Future<void> signUp({required String email, required String password}) =>
      _run(() async {
        final signedIn = await ref
            .read(authRepositoryProvider)
            .signUp(email: normalizeEmail(email), password: password);
        // Only happens when email confirmation is switched on in Supabase.
        if (!signedIn) throw AuthFailure.emailNotConfirmed;
      });

  Future<void> chooseUsername(String username) => _run(() async {
    final userId = ref.read(authUserIdProvider).value;
    if (userId == null) throw AuthFailure.unknown;
    final profile = await ref
        .read(profileRepositoryProvider)
        .setUsername(userId: userId, username: normalizeUsername(username));
    ref.read(currentProfileProvider.notifier).replace(profile);
  });

  Future<void> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());

  Future<void> _run(Future<void> Function() action) async {
    // Ignore a second tap while the first request is still running.
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    // The form may be gone already, e.g. the router moved away on success.
    if (ref.mounted) state = result;
  }
}
