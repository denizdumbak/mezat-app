import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import 'supabase_errors.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth),
);

/// Email + password authentication through Supabase Auth.
///
/// Every method throws [AuthFailure] on error. Inputs are passed through as
/// given; normalizing them (trimming the email etc.) is the caller's job.
class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  /// The signed-in user's id, or null. Supabase restores a saved session at
  /// startup, so this is already set when the app reopens.
  String? get currentUserId => _auth.currentUser?.id;

  /// Emits the user id on every auth change, and null after sign-out or when
  /// the session can no longer be refreshed.
  Stream<String?> userIdChanges() =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id);

  /// Creates the account. Returns true when the user is signed in right away,
  /// false when Supabase first wants the email address confirmed.
  Future<bool> signUp({required String email, required String password}) =>
      guardSupabase(() async {
        final response = await _auth.signUp(email: email, password: password);
        return response.session != null;
      });

  Future<void> signIn({required String email, required String password}) =>
      guardSupabase(
        () => _auth.signInWithPassword(email: email, password: password),
      );

  Future<void> signOut() => guardSupabase(_auth.signOut);
}
