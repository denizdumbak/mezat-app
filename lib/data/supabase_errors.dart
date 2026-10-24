import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auction_failure.dart';
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
  _ when _isNetworkError(error) => AuthFailure.network,
  _ => AuthFailure.unknown,
};

/// Translates an error from the auctions table, its functions or the
/// auction-images bucket into an [AuctionFailure].
AuctionFailure toAuctionFailure(Object error) => switch (error) {
  AuctionFailure() => error,
  // The auctions trigger and functions raise the code as the message
  // (SQLSTATE P0001 = raise_exception).
  PostgrestException(code: 'P0001', :final message) => switch (message) {
    'INVALID_START_TIME' => AuctionFailure.invalidStartTime,
    'INVALID_INCREMENTS' => AuctionFailure.invalidIncrements,
    'NOT_AUCTION_SELLER' => AuctionFailure.notSeller,
    'AUCTION_NOT_SCHEDULED' => AuctionFailure.notScheduled,
    'AUCTION_NOT_FOUND' => AuctionFailure.notFound,
    // Raised by place_bid (M3).
    'BID_TOO_LOW' => AuctionFailure.bidTooLow,
    'AUCTION_NOT_LIVE' => AuctionFailure.auctionNotLive,
    'SELLER_CANNOT_BID' => AuctionFailure.sellerCannotBid,
    _ => AuctionFailure.unknown,
  },
  PostgrestException(code: '23514') => AuctionFailure.invalidInput,
  // 42501 = insufficient_privilege: RLS or column privileges refused it.
  PostgrestException(code: '42501') => AuctionFailure.notAllowed,
  // Storage reports the HTTP status of its own check in statusCode.
  StorageException(statusCode: '413') => AuctionFailure.imageTooLarge,
  StorageException(statusCode: '415') => AuctionFailure.unsupportedImage,
  StorageException(statusCode: '403') => AuctionFailure.notAllowed,
  _ when _isNetworkError(error) => AuctionFailure.network,
  _ => AuctionFailure.unknown,
};

bool _isNetworkError(Object error) => switch (error) {
  http.ClientException() || SocketException() || TimeoutException() => true,
  // The storage client wraps a request that got no response and puts the
  // error's type name, not an HTTP status, into statusCode.
  StorageException(:final statusCode) => int.tryParse(statusCode ?? '') == null,
  _ => false,
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

/// Runs [action] and rethrows any failure as an [AuctionFailure].
Future<T> guardAuctions<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw toAuctionFailure(error);
  }
}
