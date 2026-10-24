// Drives the real app (real main(), real Supabase) through the M2 flow:
// create an auction, find it under Sat, go live, see it in Keşfet.
//
// Needs `npx supabase start`. Run on the desktop or a device:
//   flutter test integration_test -d windows --dart-define-from-file=.env
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/features/auctions/discover_screen.dart';
import 'package:mezat_app/features/live_room/live_room_screen.dart';
import 'package:mezat_app/main.dart' as app;

import 'helpers.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create an auction, go live, find it in Keşfet', (tester) async {
    final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final title = 'E2E kamera $run';
    const password = 'Passw0rd!x';

    await app.main();
    await startSignedOut(tester);

    // A fresh seller.
    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await pumpUntilFound(tester, find.byKey(const Key('signUp.email')));
    await tester.enterText(
      find.byKey(const Key('signUp.email')),
      'ia_$run@example.com',
    );
    await tester.enterText(find.byKey(const Key('signUp.password')), password);
    await tester.enterText(
      find.byKey(const Key('signUp.passwordAgain')),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('chooseUsername.username')),
    );
    await tester.enterText(
      find.byKey(const Key('chooseUsername.username')),
      'ia_$run',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
    await pumpUntilFound(tester, find.byType(DiscoverScreen));

    // Sat → create, starting now, with Turkish-style amounts.
    await tester.tap(find.byKey(const Key('tab.1')));
    await pumpUntilFound(tester, find.text('Henüz planlanmış mezatın yok.'));
    await tester.tap(find.widgetWithText(FilledButton, 'Mezat oluştur'));
    await pumpUntilFound(tester, find.byKey(const Key('createAuction.title')));
    await tester.enterText(find.byKey(const Key('createAuction.title')), title);
    await tester.enterText(
      find.byKey(const Key('createAuction.startPrice')),
      '1.250,50',
    );
    await tester.enterText(
      find.byKey(const Key('createAuction.minIncrement')),
      '25',
    );
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Mezatı oluştur'),
    );

    // Back on Sat, the new auction is listed. (Wait for the form to
    // close first: find.text also matches the title typed into its field.)
    await pumpUntilFound(tester, find.text('Planlanmış mezatların'));
    await pumpUntilFound(tester, find.text(title));
    expect(find.textContaining('Açılış ₺1.250,50'), findsOneWidget);

    // Go live: the room opens, the seller cannot bid on their own auction.
    await tester.tap(find.text('Yayını başlat'));
    await pumpUntilFound(tester, find.byType(LiveRoomScreen));
    await pumpUntilFound(tester, find.text(title));
    expect(find.text('Kendi mezatına teklif veremezsin.'), findsOneWidget);
    expect(find.bySemanticsLabel('₺1.250,50'), findsOneWidget);
    expect(find.text('+₺25 teklif ver'), findsOneWidget);
    expect(find.text(AuctionFailure.biddingNotOpen.message), findsNothing);

    // Keşfet now shows it among the live auctions.
    await tester.tap(find.byType(BackButton));
    await pumpUntilFound(tester, find.text('Planlanmış mezatların'));
    await tester.tap(find.byKey(const Key('tab.0')));
    await pumpUntilFound(tester, find.text(title));
    expect(find.text('Şimdi canlı'), findsOneWidget);
  });
}
