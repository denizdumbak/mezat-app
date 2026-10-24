import 'package:mezat_app/core/auction_rules.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/data/auction_feed_repository.dart';

import 'fakes.dart';

const me = FakeAuthRepository.signedInUserId;

/// 20 characters: the longest username the database allows.
const longUsername = 'cok_uzun_kullanici_1';

/// ₺999.999: the six-digit amount every screen must fit.
const sixDigits = Money.kurus(99999900);

AuctionSummary liveAuction({
  String id = 'zenit',
  String title = 'Zenit-E analog fotoğraf makinesi (1978)',
  String seller = 'antikaci_mert',
  Money price = const Money.kurus(125000),
  int viewers = 128,
}) => AuctionSummary(
  id: id,
  title: title,
  sellerUsername: seller,
  currentPrice: price,
  startsAt: DateTime.now().subtract(const Duration(minutes: 6)),
  isLive: true,
  viewerCount: viewers,
);

AuctionSummary upcomingAuction({
  String id = 'telkari',
  String title = 'Gümüş telkari broş, Midyat işi',
  String seller = 'eskici_ayse',
  Money price = const Money.kurus(35000),
  Duration startsIn = const Duration(hours: 2),
}) => AuctionSummary(
  id: id,
  title: title,
  sellerUsername: seller,
  currentPrice: price,
  startsAt: DateTime.now().add(startsIn),
  isLive: false,
);

Bid bid(String id, String who, int lira, {String? bidderId}) => Bid(
  id: id,
  bidderId: bidderId ?? 'bot-$who',
  username: who,
  amount: Money.kurus(lira * 100),
  placedAt: DateTime.now(),
);

/// A live room; bids are newest first.
LiveRoom liveRoom({
  String id = 'zenit',
  String title = 'Zenit-E analog fotoğraf makinesi (1978)',
  String sellerId = 'seller-mert',
  String seller = 'antikaci_mert',
  Money price = const Money.kurus(125000),
  List<Bid>? bids,
  Duration endsIn = const Duration(minutes: 4),
  List<Money> increments = defaultIncrements,
  Money minIncrement = const Money.kurus(1000),
  int viewers = 128,
  bool ended = false,
  SoldResult? sold,
  bool connected = true,
}) => LiveRoom(
  auctionId: id,
  title: title,
  sellerId: sellerId,
  sellerUsername: seller,
  currentPrice: price,
  endsAt: DateTime.now().add(endsIn),
  minIncrement: minIncrement,
  increments: increments,
  bids:
      bids ??
      [
        bid('b3', 'plakci_baris', 1250),
        bid('b2', 'zeynep_antik', 1200),
        bid('b1', 'koleksiyoncu_can', 1150),
      ],
  viewerCount: viewers,
  ended: ended,
  sold: sold,
  connected: connected,
);
