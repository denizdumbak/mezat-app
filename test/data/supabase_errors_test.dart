import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mezat_app/core/auth_failure.dart';
import 'package:mezat_app/data/supabase_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('toAuthFailure', () {
    // error_code values as returned by the local Supabase Auth server.
    final authCodes = {
      'invalid_credentials': AuthFailure.invalidCredentials,
      'email_not_confirmed': AuthFailure.emailNotConfirmed,
      'user_already_exists': AuthFailure.emailAlreadyRegistered,
      'email_exists': AuthFailure.emailAlreadyRegistered,
      'weak_password': AuthFailure.weakPassword,
      'validation_failed': AuthFailure.invalidEmail,
      'over_request_rate_limit': AuthFailure.tooManyRequests,
      'some_new_code': AuthFailure.unknown,
    };
    for (final MapEntry(key: code, value: failure) in authCodes.entries) {
      test('auth code $code -> ${failure.name}', () {
        expect(
          toAuthFailure(AuthApiException('msg', statusCode: '400', code: code)),
          failure,
        );
      });
    }

    test('HTTP 429 without a code is a rate limit', () {
      expect(
        toAuthFailure(const AuthException('slow down', statusCode: '429')),
        AuthFailure.tooManyRequests,
      );
    });

    test('auth request that never got a response is a network failure', () {
      expect(
        toAuthFailure(AuthRetryableFetchException(message: 'offline')),
        AuthFailure.network,
      );
    });

    test('duplicate username (23505) and bad format (23514)', () {
      expect(
        toAuthFailure(const PostgrestException(message: 'dup', code: '23505')),
        AuthFailure.usernameTaken,
      );
      expect(
        toAuthFailure(const PostgrestException(message: 'chk', code: '23514')),
        AuthFailure.invalidUsername,
      );
    });

    test('connection errors are network failures', () {
      expect(toAuthFailure(http.ClientException('x')), AuthFailure.network);
      expect(toAuthFailure(const SocketException('x')), AuthFailure.network);
      expect(toAuthFailure(TimeoutException('x')), AuthFailure.network);
    });

    test('anything else is unknown, never raw text', () {
      expect(toAuthFailure(StateError('boom')), AuthFailure.unknown);
      expect(
        AuthFailure.messageFor(StateError('boom')),
        isNot(contains('boom')),
      );
    });

    test('an AuthFailure passes through unchanged', () {
      expect(
        toAuthFailure(AuthFailure.usernameTaken),
        AuthFailure.usernameTaken,
      );
    });
  });
}
