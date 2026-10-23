import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/photo_picker.dart';
import 'package:mezat_app/data/profile_repository.dart';

import '../../helpers/fakes.dart';

const _userId = FakeAuthRepository.signedInUserId;

// A 1×1 transparent PNG, so Image.memory has something real to decode.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Signed in with a username, on the create form.
Future<void> _openForm(
  WidgetTester tester, {
  required FakeAuctionRepository auctions,
  FakePhotoPicker? photoPicker,
}) async {
  final profiles = FakeProfileRepository()
    ..profiles[_userId] = const Profile(id: _userId, username: 'deniz');
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedInAs: _userId),
    profiles: profiles,
    auctions: auctions,
    photoPicker: photoPicker,
  );
  // "Mezat oluştur" is on the Yayın aç tab.
  await tester.tap(find.byKey(const Key('tab.2')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Mezat oluştur'));
  await tester.pumpAndSettle();
}

Future<void> _fillForm(
  WidgetTester tester, {
  String title = 'Analog kamera',
  String startPrice = '1.250,50',
  String minIncrement = '25',
}) async {
  await tester.enterText(find.byKey(const Key('createAuction.title')), title);
  await tester.enterText(
    find.byKey(const Key('createAuction.description')),
    '  Çalışır durumda.  ',
  );
  await tester.enterText(
    find.byKey(const Key('createAuction.startPrice')),
    startPrice,
  );
  await tester.enterText(
    find.byKey(const Key('createAuction.minIncrement')),
    minIncrement,
  );
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Mezatı oluştur');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Yayın aç tab opens the create form', (tester) async {
    await _openForm(tester, auctions: FakeAuctionRepository());

    expect(find.byKey(const Key('createAuction.title')), findsOneWidget);
  });

  testWidgets('invalid input is caught before any request', (tester) async {
    final auctions = FakeAuctionRepository();
    await _openForm(tester, auctions: auctions);

    await _fillForm(tester, title: 'ab', startPrice: '', minIncrement: '0');
    await _submit(tester);

    expect(find.text('Başlık 3–80 karakter olmalı.'), findsOneWidget);
    expect(find.text('Bir tutar gir.'), findsOneWidget);
    expect(find.text('Tutar 0\'dan büyük olmalı.'), findsOneWidget);
    expect(auctions.created, isEmpty);
  });

  testWidgets('a valid form creates the auction and goes back', (tester) async {
    final auctions = FakeAuctionRepository();
    await _openForm(tester, auctions: auctions);
    final before = DateTime.now();

    await _fillForm(tester);
    await _submit(tester);

    final auction = auctions.created.single.auction;
    expect(auction.title, 'Analog kamera');
    expect(auction.description, 'Çalışır durumda.');
    expect(auction.startPrice, const Money.kurus(125050));
    expect(auction.minIncrement, const Money.kurus(2500));
    expect(auction.durationMinutes, 30);
    // "Start now" sends the current time.
    expect(auction.startsAt.isBefore(before), isFalse);
    expect(auctions.created.single.imagePath, isNull);

    expect(find.text('Mezat oluşturuldu.'), findsOneWidget);
    expect(find.byKey(const Key('createAuction.title')), findsNothing);
  });

  testWidgets('the chosen photo is uploaded and linked to the auction', (
    tester,
  ) async {
    final auctions = FakeAuctionRepository();
    final picker = FakePhotoPicker()
      ..next = PickedPhoto(
        bytes: _png,
        contentType: 'image/png',
        extension: 'png',
      );
    await _openForm(tester, auctions: auctions, photoPicker: picker);

    await tester.tap(find.byKey(const Key('createAuction.photo')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Fotoğrafı kaldır'), findsOneWidget);

    await _fillForm(tester);
    await _submit(tester);

    expect(auctions.uploaded, ['$_userId/photo-0.png']);
    expect(auctions.created.single.imagePath, '$_userId/photo-0.png');
  });

  testWidgets('if creating fails, the uploaded photo is deleted', (
    tester,
  ) async {
    final auctions = FakeAuctionRepository()
      ..createError = AuctionFailure.invalidStartTime;
    final picker = FakePhotoPicker()
      ..next = PickedPhoto(
        bytes: _png,
        contentType: 'image/png',
        extension: 'png',
      );
    await _openForm(tester, auctions: auctions, photoPicker: picker);

    await tester.tap(find.byKey(const Key('createAuction.photo')));
    await tester.pumpAndSettle();
    await _fillForm(tester);
    await _submit(tester);

    expect(auctions.deleted, ['$_userId/photo-0.png']);
    expect(find.text(AuctionFailure.invalidStartTime.message), findsOneWidget);
    // Still on the form, input kept, so the user can fix and retry.
    expect(find.text('Analog kamera'), findsOneWidget);
  });

  testWidgets('a photo upload error is shown and nothing is created', (
    tester,
  ) async {
    final auctions = FakeAuctionRepository()
      ..uploadError = AuctionFailure.imageTooLarge;
    final picker = FakePhotoPicker()
      ..next = PickedPhoto(
        bytes: _png,
        contentType: 'image/png',
        extension: 'png',
      );
    await _openForm(tester, auctions: auctions, photoPicker: picker);

    await tester.tap(find.byKey(const Key('createAuction.photo')));
    await tester.pumpAndSettle();
    await _fillForm(tester);
    await _submit(tester);

    expect(find.text('Fotoğraf en fazla 5 MB olabilir.'), findsOneWidget);
    expect(auctions.created, isEmpty);
  });

  testWidgets('an unsupported photo type is explained', (tester) async {
    final picker = FakePhotoPicker()..error = AuctionFailure.unsupportedImage;
    await _openForm(
      tester,
      auctions: FakeAuctionRepository(),
      photoPicker: picker,
    );

    await tester.tap(find.byKey(const Key('createAuction.photo')));
    await tester.pumpAndSettle();

    expect(find.text(AuctionFailure.unsupportedImage.message), findsOneWidget);
  });

  testWidgets('a later start needs a date and time', (tester) async {
    final auctions = FakeAuctionRepository();
    await _openForm(tester, auctions: auctions);

    await _fillForm(tester);
    final later = find.text('İleri tarih');
    await tester.ensureVisible(later);
    await tester.tap(later);
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(find.text('Başlangıç tarihi ve saatini seç.'), findsOneWidget);
    expect(auctions.created, isEmpty);
  });

  testWidgets('the date picker is in Turkish', (tester) async {
    await _openForm(tester, auctions: FakeAuctionRepository());

    final later = find.text('İleri tarih');
    await tester.ensureVisible(later);
    await tester.tap(later);
    await tester.pumpAndSettle();
    final pick = find.byKey(const Key('createAuction.startAt'));
    await tester.ensureVisible(pick);
    await tester.tap(pick);
    await tester.pumpAndSettle();

    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Tamam'), findsOneWidget);
  });

  testWidgets('a second tap while creating is ignored', (tester) async {
    final auctions = FakeAuctionRepository()..gate = Completer<void>();
    await _openForm(tester, auctions: auctions);

    await _fillForm(tester);
    final button = find.widgetWithText(FilledButton, 'Mezatı oluştur');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    // The button now shows a spinner and is disabled.
    final submit = find.byType(FilledButton).last;
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(submit, warnIfMissed: false);

    auctions.gate!.complete();
    await tester.pumpAndSettle();
    expect(auctions.created, hasLength(1));
  });
}
