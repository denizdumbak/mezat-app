import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/app/app.dart';
import 'package:mezat_app/core/auth_failure.dart';
import 'package:mezat_app/data/auth_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';

/// In-memory stand-in for Supabase Auth.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? signedInAs}) : _userId = signedInAs;

  final _changes = StreamController<String?>.broadcast();
  String? _userId;

  /// Every call, e.g. `signIn:deniz@example.com`.
  final calls = <String>[];

  /// Thrown (once) by the next call instead of succeeding.
  Object? nextError;

  /// When set, calls wait for it to complete; lets a test see the loading state.
  Completer<void>? gate;

  /// Simulates a project with email confirmation switched on.
  bool requireEmailConfirmation = false;

  static const signedInUserId = 'user-1';

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> userIdChanges() => _changes.stream;

  @override
  Future<bool> signUp({required String email, required String password}) async {
    calls.add('signUp:$email');
    await _proceed();
    if (requireEmailConfirmation) return false;
    _setUser(signedInUserId);
    return true;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    await _proceed();
    _setUser(signedInUserId);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    await _proceed();
    _setUser(null);
  }

  Future<void> _proceed() async {
    await gate?.future;
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
  }

  void _setUser(String? userId) {
    _userId = userId;
    _changes.add(userId);
  }
}

/// In-memory stand-in for the profiles table, including its unique username.
class FakeProfileRepository implements ProfileRepository {
  final profiles = <String, Profile>{};

  /// Thrown by fetchProfile while set.
  Object? fetchError;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    final error = fetchError;
    if (error != null) throw error;
    return profiles[userId] ?? Profile(id: userId, username: null);
  }

  @override
  Future<Profile> setUsername({
    required String userId,
    required String username,
  }) async {
    final taken = profiles.values.any(
      (p) => p.username == username && p.id != userId,
    );
    if (taken) throw AuthFailure.usernameTaken;
    return profiles[userId] = Profile(id: userId, username: username);
  }
}

/// Pumps the whole app on top of the fakes and waits for the first screen.
Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeProfileRepository? profiles,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(
          profiles ?? FakeProfileRepository(),
        ),
      ],
      // Riverpod retries failed providers by default; tests want the failure.
      retry: (retryCount, error) => null,
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}
