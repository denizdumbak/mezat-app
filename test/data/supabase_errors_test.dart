import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mezat_app/core/app_failure.dart';
import 'package:mezat_app/core/auction_failure.dart';
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
      expect(failureMessage(StateError('boom')), isNot(contains('boom')));
    });

    test('an AuthFailure passes through unchanged', () {
      expect(
        toAuthFailure(AuthFailure.usernameTaken),
        AuthFailure.usernameTaken,
      );
    });
  });

  group('toAuctionFailure', () {
    // Codes raised by the auctions trigger and start_auction.
    final domainCodes = {
      'INVALID_START_TIME': AuctionFailure.invalidStartTime,
      'NOT_AUCTION_SELLER': AuctionFailure.notSeller,
      'AUCTION_NOT_SCHEDULED': AuctionFailure.notScheduled,
      'AUCTION_NOT_FOUND': AuctionFailure.notFound,
      'BID_TOO_LOW': AuctionFailure.bidTooLow,
      'AUCTION_NOT_LIVE': AuctionFailure.auctionNotLive,
      'SELLER_CANNOT_BID': AuctionFailure.sellerCannotBid,
      'SOME_NEW_CODE': AuctionFailure.unknown,
    };
    for (final MapEntry(key: code, value: failure) in domainCodes.entries) {
      test('P0001 $code -> ${failure.name}', () {
        expect(
          toAuctionFailure(PostgrestException(message: code, code: 'P0001')),
          failure,
        );
      });
    }

    test('check violation and missing privilege', () {
      expect(
        toAuctionFailure(const PostgrestException(message: 'x', code: '23514')),
        AuctionFailure.invalidInput,
      );
      expect(
        toAuctionFailure(const PostgrestException(message: 'x', code: '42501')),
        AuctionFailure.notAllowed,
      );
    });

    test('storage limits and permissions', () {
      expect(
        toAuctionFailure(const StorageException('big', statusCode: '413')),
        AuctionFailure.imageTooLarge,
      );
      expect(
        toAuctionFailure(const StorageException('type', statusCode: '415')),
        AuctionFailure.unsupportedImage,
      );
      expect(
        toAuctionFailure(const StorageException('rls', statusCode: '403')),
        AuctionFailure.notAllowed,
      );
      expect(
        toAuctionFailure(const StorageException('boom', statusCode: '500')),
        AuctionFailure.unknown,
      );
    });

    test('a storage request without a response is a network failure', () {
      // The storage client puts the error type's name into statusCode.
      expect(
        toAuctionFailure(
          const StorageException('x', statusCode: 'ClientException'),
        ),
        AuctionFailure.network,
      );
      expect(
        toAuctionFailure(const SocketException('x')),
        AuctionFailure.network,
      );
    });

    test('anything else is unknown, never raw text', () {
      expect(toAuctionFailure(StateError('boom')), AuctionFailure.unknown);
    });
  });
}
