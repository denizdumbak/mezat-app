import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_failure.dart';

/// Translates an error thrown by the Supabase client into an [AuthFailure].
///
/// The codes come from the Auth server's `error_code` field and Postgres
/// SQLSTATE codes; they were checked against the local Supabase stack.
AuthFailure toAuthFailure(Object error) => switch (error) {
  AuthFailure() => error,
  // Thrown by the auth client when the request never got a response.
  AuthRetryableFetchException() => AuthFailure.network,
  AuthWeakPasswordException() => AuthFailure.weakPassword,
  AuthException(:final code, :final statusCode) => _fromAuthCode(
    code,
    statusCode,
  ),
  // 23505 = unique_violation, 23514 = check_violation on profiles.username.
  PostgrestException(code: '23505') => AuthFailure.usernameTaken,
  PostgrestException(code: '23514') => AuthFailure.invalidUsername,
  http.ClientException() ||
  SocketException() ||
  TimeoutException() => AuthFailure.network,
  _ => AuthFailure.unknown,
};

AuthFailure _fromAuthCode(String? code, String? statusCode) => switch (code) {
  'invalid_credentials' => AuthFailure.invalidCredentials,
  'email_not_confirmed' => AuthFailure.emailNotConfirmed,
  'user_already_exists' || 'email_exists' => AuthFailure.emailAlreadyRegistered,
  'weak_password' => AuthFailure.weakPassword,
  'validation_failed' || 'email_address_invalid' => AuthFailure.invalidEmail,
  'over_request_rate_limit' ||
  'over_email_send_rate_limit' => AuthFailure.tooManyRequests,
  _ when statusCode == '429' => AuthFailure.tooManyRequests,
  _ => AuthFailure.unknown,
};

/// Runs [action] and rethrows any failure as an [AuthFailure].
Future<T> guardSupabase<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw toAuthFailure(error);
  }
}
