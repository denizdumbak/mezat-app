import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single entry point to Supabase. Repositories in `lib/data` read this
/// provider; widgets never do. Tests override it with a fake client.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
