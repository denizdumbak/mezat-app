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
  String id = 'canon',
  String title = 'Canon AE-1 Program, 50mm f/1.8 lens',
  String seller = 'analogdukkan',
  Money price = const Money.kurus(125000),
  int viewers = 236,
  String? imageUrl = 'assets/mock/canon-ae1.jpg',
  Duration endsIn = const Duration(minutes: 4),
}) => AuctionSummary(
  id: id,
  title: title,
  sellerUsername: seller,
  currentPrice: price,
  startsAt: DateTime.now().subtract(const Duration(minutes: 6)),
  isLive: true,
  endsAt: DateTime.now().add(endsIn),
  imageUrl: imageUrl,
  viewerCount: viewers,
);

AuctionSummary upcomingAuction({
  String id = 'walkman',
  String title = 'Sony Walkman WM-F10, kasetli, çalışır',
  String seller = 'kasetcafe',
  Money price = const Money.kurus(35000),
  Duration startsIn = const Duration(hours: 2),
  String? imageUrl = 'assets/mock/walkman.jpg',
}) => AuctionSummary(
  id: id,
  title: title,
  sellerUsername: seller,
  currentPrice: price,
  startsAt: DateTime.now().add(startsIn),
  isLive: false,
  imageUrl: imageUrl,
);

AuctionSummary endedAuction({
  String id = 'lens',
  String title = 'Helios 44-2 58mm lens, M42 bağlantı',
  String seller = 'analogdukkan',
  Money price = const Money.kurus(160000),
  String? imageUrl = 'assets/mock/kamera-lens.jpg',
}) => AuctionSummary(
  id: id,
  title: title,
  sellerUsername: seller,
  currentPrice: price,
  startsAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
  endsAt: DateTime.now().subtract(const Duration(days: 1)),
  isLive: false,
  isEnded: true,
  imageUrl: imageUrl,
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
  String id = 'canon',
  String title = 'Canon AE-1 Program, 50mm f/1.8 lens',
  String sellerId = 'seller-mert',
  String seller = 'analogdukkan',
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
        bid('b3', 'retro_avcisi', 1250),
        bid('b2', 'analogsever', 1200),
        bid('b1', 'foto_arsiv', 1150),
      ],
  viewerCount: viewers,
  ended: ended,
  sold: sold,
  connected: connected,
);
