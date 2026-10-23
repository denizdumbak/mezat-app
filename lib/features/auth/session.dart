import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/profile_repository.dart';

/// The signed-in user's id, or null when signed out.
final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  yield repository.currentUserId;
  yield* repository.userIdChanges();
});

/// The signed-in user's profile, or null when signed out.
final currentProfileProvider =
    AsyncNotifierProvider<CurrentProfileNotifier, Profile?>(
      CurrentProfileNotifier.new,
    );

class CurrentProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final userId = ref.watch(authUserIdProvider).value;
    if (userId == null) return null;
    return ref.watch(profileRepositoryProvider).fetchProfile(userId);
  }

  /// Swaps in a profile the server just returned, without a reload (which
  /// would briefly show the splash screen).
  void replace(Profile profile) => state = AsyncData(profile);
}

/// Where the user is in the sign-in flow. The router redirects on this.
enum SessionStatus {
  /// Restoring the session or loading the profile.
  loading,

  /// The profile could not be loaded (e.g. no connection).
  profileError,
  signedOut,

  /// Signed in, but no username yet.
  needsUsername,
  ready,
}

final sessionStatusProvider = Provider<SessionStatus>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (!userId.hasValue && !userId.hasError) return SessionStatus.loading;
  // A broken auth stream means we cannot trust the session: treat as signed out.
  if (userId.hasError || userId.value == null) return SessionStatus.signedOut;

  return switch (ref.watch(currentProfileProvider)) {
    AsyncData(:final value) =>
      value?.username == null
          ? SessionStatus.needsUsername
          : SessionStatus.ready,
    AsyncError() => SessionStatus.profileError,
    _ => SessionStatus.loading,
  };
});
