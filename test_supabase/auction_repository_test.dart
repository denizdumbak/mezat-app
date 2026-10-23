// Runs AuctionRepository against the local Supabase stack: amounts reach the
// numeric columns exactly, and database/storage errors map to AuctionFailure.
//
// Needs `npx supabase start`. Not part of `flutter test`:
//   flutter test test_supabase --dart-define-from-file=.env
@Tags(['supabase'])
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/photo_picker.dart';
import 'package:mezat_app/data/auction_repository.dart';
import 'package:mezat_app/data/auth_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final run = Random().nextInt(1 << 32).toRadixString(36);
  const password = 'Passw0rd!x';

  late SupabaseClient seller;
  late String sellerId;
  late SupabaseClient noUsername;

  PickedPhoto photo(int size, {String contentType = 'image/jpeg'}) =>
      PickedPhoto(
        bytes: Uint8List(size),
        contentType: contentType,
        extension: 'jpg',
      );

  NewAuction auction({
    String title = 'Analog kamera',
    DateTime? startsAt,
    Money startPrice = const Money.kurus(125050),
  }) => NewAuction(
    title: title,
    description: 'Test',
    startPrice: startPrice,
    minIncrement: const Money.kurus(2500),
    durationMinutes: 30,
    startsAt: startsAt ?? DateTime.now(),
  );

  setUpAll(() async {
    seller = newClient();
    await AuthRepository(
      seller.auth,
    ).signUp(email: 'seller_$run@example.com', password: password);
    sellerId = seller.auth.currentUser!.id;
    await ProfileRepository(
      seller,
    ).setUsername(userId: sellerId, username: 's_$run');

    noUsername = newClient();
    await AuthRepository(
      noUsername.auth,
    ).signUp(email: 'nouser_$run@example.com', password: password);
  });

  tearDownAll(() async {
    await seller.dispose();
    await noUsername.dispose();
  });

  test('create stores exact amounts and server-owned defaults', () async {
    final id = await AuctionRepository(
      seller,
    ).create(auction(startPrice: Money.max));

    final row = await seller
        .from('auctions')
        .select(
          'seller_id, status, start_price::text, current_price::text, '
          'min_increment::text, ends_at',
        )
        .eq('id', id)
        .single();
    expect(row['seller_id'], sellerId);
    expect(row['status'], 'scheduled');
    // The largest numeric(12,2) value survives to the last kuruş.
    expect(Money.parseDb(row['start_price'] as String), Money.max);
    expect(Money.parseDb(row['current_price'] as String), Money.max);
    expect(row['min_increment'], '25.00');
    expect(row['ends_at'], isNull);
  });

  test('photo upload, create with it, and delete', () async {
    final repository = AuctionRepository(seller);
    final path = await repository.uploadImage(
      userId: sellerId,
      photo: photo(1024),
    );
    expect(path, startsWith('$sellerId/'));

    final id = await repository.create(auction(), imagePath: path);
    final row = await seller
        .from('auctions')
        .select('image_path')
        .eq('id', id)
        .single();
    expect(row['image_path'], path);

    await repository.deleteImage(path);
    final left = await seller.storage
        .from(AuctionRepository.imageBucket)
        .list(path: sellerId);
    expect(left.map((f) => '$sellerId/${f.name}'), isNot(contains(path)));
  });

  test('a photo over 5 MB is imageTooLarge', () async {
    await expectLater(
      AuctionRepository(
        seller,
      ).uploadImage(userId: sellerId, photo: photo(5 * 1024 * 1024 + 1)),
      throwsA(AuctionFailure.imageTooLarge),
    );
  });

  test('a type the bucket refuses is unsupportedImage', () async {
    await expectLater(
      AuctionRepository(seller).uploadImage(
        userId: sellerId,
        photo: photo(10, contentType: 'image/gif'),
      ),
      throwsA(AuctionFailure.unsupportedImage),
    );
  });

  test("uploading into someone else's folder is notAllowed", () async {
    await expectLater(
      AuctionRepository(
        noUsername,
      ).uploadImage(userId: sellerId, photo: photo(10)),
      throwsA(AuctionFailure.notAllowed),
    );
  });

  test('a start time in the past is invalidStartTime', () async {
    await expectLater(
      AuctionRepository(seller).create(
        auction(startsAt: DateTime.now().subtract(const Duration(hours: 1))),
      ),
      throwsA(AuctionFailure.invalidStartTime),
    );
  });

  test('a title the check constraint rejects is invalidInput', () async {
    await expectLater(
      AuctionRepository(seller).create(auction(title: 'ab')),
      throwsA(AuctionFailure.invalidInput),
    );
  });

  test('a user without a username is notAllowed', () async {
    await expectLater(
      AuctionRepository(noUsername).create(auction()),
      throwsA(AuctionFailure.notAllowed),
    );
  });

  test('an unreachable server is a network failure', () async {
    final client = newClient(url: 'http://127.0.0.1:1');
    addTearDown(client.dispose);
    final repository = AuctionRepository(client);
    await expectLater(
      repository.create(auction()),
      throwsA(AuctionFailure.network),
    );
    await expectLater(
      repository.uploadImage(userId: sellerId, photo: photo(10)),
      throwsA(AuctionFailure.network),
    );
  });
}
