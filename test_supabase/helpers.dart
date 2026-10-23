import 'package:mezat_app/core/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final env = Env.fromDefines();

/// A client of its own, so each test user has an independent session.
///
/// Supabase.initialize gives the app a persistent storage for the PKCE flow;
/// a bare client in a test needs one passed in.
SupabaseClient newClient({String? url}) => SupabaseClient(
  url ?? env.supabaseUrl,
  env.supabaseAnonKey,
  authOptions: AuthClientOptions(
    autoRefreshToken: false,
    pkceAsyncStorage: _MemoryStorage(),
  ),
);

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
