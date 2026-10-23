import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/env.dart';

void main() {
  group('Env.parse', () {
    test('accepts valid values', () {
      final env = Env.parse(
        supabaseUrl: 'http://127.0.0.1:54321',
        supabaseAnonKey: 'anon-key',
        livekitUrl: 'wss://example.livekit.cloud',
      );

      expect(env.supabaseUrl, 'http://127.0.0.1:54321');
      expect(env.supabaseAnonKey, 'anon-key');
      expect(env.livekitUrl, 'wss://example.livekit.cloud');
    });

    test('reports every missing value at once', () {
      expect(
        () => Env.parse(supabaseUrl: '', supabaseAnonKey: '', livekitUrl: ''),
        throwsA(
          isA<EnvException>().having((e) => e.problems, 'problems', [
            'SUPABASE_URL is missing',
            'SUPABASE_ANON_KEY is missing',
            'LIVEKIT_URL is missing',
          ]),
        ),
      );
    });

    test('rejects URLs with the wrong scheme', () {
      expect(
        () => Env.parse(
          supabaseUrl: 'ws://127.0.0.1:54321',
          supabaseAnonKey: 'anon-key',
          livekitUrl: 'https://example.livekit.cloud',
        ),
        throwsA(
          isA<EnvException>().having((e) => e.problems, 'problems', [
            'SUPABASE_URL must start with http:// or https://',
            'LIVEKIT_URL must start with ws:// or wss://',
          ]),
        ),
      );
    });

    test('rejects a URL without a host', () {
      expect(
        () => Env.parse(
          supabaseUrl: 'https://',
          supabaseAnonKey: 'anon-key',
          livekitUrl: 'wss://example.livekit.cloud',
        ),
        throwsA(isA<EnvException>()),
      );
    });
  });
}
