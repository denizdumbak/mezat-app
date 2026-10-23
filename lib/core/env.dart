/// Public runtime configuration, injected at build time with
/// `--dart-define-from-file=.env`.
///
/// Only public values belong here (Supabase URL, anon key, LiveKit URL).
/// Secrets such as the LiveKit API secret never reach the app.
class Env {
  const Env._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.livekitUrl,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String livekitUrl;

  /// Reads the values compiled in via `--dart-define-from-file`.
  factory Env.fromDefines() => Env.parse(
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    livekitUrl: const String.fromEnvironment('LIVEKIT_URL'),
  );

  /// Validates raw values and fails fast with a message that names every
  /// problem, so a misconfigured build is caught at startup.
  factory Env.parse({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String livekitUrl,
  }) {
    final problems = <String>[
      if (supabaseUrl.isEmpty)
        'SUPABASE_URL is missing'
      else if (!_hasScheme(supabaseUrl, const {'http', 'https'}))
        'SUPABASE_URL must start with http:// or https://',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY is missing',
      if (livekitUrl.isEmpty)
        'LIVEKIT_URL is missing'
      else if (!_hasScheme(livekitUrl, const {'ws', 'wss'}))
        'LIVEKIT_URL must start with ws:// or wss://',
    ];
    if (problems.isNotEmpty) throw EnvException(problems);

    return Env._(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      livekitUrl: livekitUrl,
    );
  }

  static bool _hasScheme(String value, Set<String> schemes) {
    final uri = Uri.tryParse(value);
    return uri != null && schemes.contains(uri.scheme) && uri.host.isNotEmpty;
  }
}

class EnvException implements Exception {
  const EnvException(this.problems);

  final List<String> problems;

  @override
  String toString() => 'Invalid configuration:\n- ${problems.join('\n- ')}';
}
