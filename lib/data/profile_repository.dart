import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import 'supabase_errors.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

class Profile {
  const Profile({required this.id, required this.username, this.avatarUrl});

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    username: json['username'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );

  final String id;

  /// Null until the user picks one after sign-up.
  final String? username;
  final String? avatarUrl;
}

/// Reads and updates rows of `public.profiles`. RLS on the table guarantees a
/// user can only change their own row; this class does not re-check that.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, username, avatar_url';

  /// Throws [AuthFailure] on error.
  Future<Profile?> fetchProfile(String userId) => guardSupabase(() async {
    final row = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  });

  /// Sets the username and returns the stored profile. The database trims and
  /// lowercases it and enforces format and uniqueness; throws [AuthFailure].
  Future<Profile> setUsername({
    required String userId,
    required String username,
  }) => guardSupabase(() async {
    final row = await _client
        .from('profiles')
        .update({'username': username})
        .eq('id', userId)
        .select(_columns)
        .single();
    return Profile.fromJson(row);
  });
}
