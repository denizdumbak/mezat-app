import 'dart:async';
import 'dart:math';

import '../core/auction_failure.dart';
import '../core/auction_rules.dart';
import '../core/money.dart';
import 'auction_feed_repository.dart';
import 'spending_limit_repository.dart';

typedef MockUser = ({String id, String username});

/// In-memory auctions so the screens can be built and tried before the
/// realtime backend exists. Follows the server rules (minimum step, seller
/// cannot bid, anti-sniping, end by time) so the UI behaves as it will.
///
/// With [simulate] on, other bidders bid now and then and auctions end on
/// time; tests turn it off and drive the state themselves.
class MockAuctionFeedRepository implements AuctionFeedRepository {
  MockAuctionFeedRepository({
    required this.currentUser,
    SpendingLimit Function()? spendingLimit,
    this.simulate = true,
    DateTime Function()? clock,
    Random? random,
  }) : _spendingLimit = spendingLimit ?? (() => SpendingLimit.defaults),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random() {
    _seed();
    if (simulate) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  /// The signed-in user, or null.
  final MockUser? Function() currentUser;

  /// The signed-in user's settings, for the window committed_in_window uses.
  final SpendingLimit Function() _spendingLimit;
  final bool simulate;
  final DateTime Function() _clock;
  final Random _random;

  final _auctions = <String, _MockAuction>{};
  final _changes = StreamController<void>.broadcast();
  Timer? _ticker;
  var _nextBidId = 0;

  static const _bots = [
    'retro_avcisi',
    'eskiye_merakli',
    'analogsever',
    'plakarsivi',
    'stickerhane',
  ];

  void dispose() {
    _ticker?.cancel();
    _changes.close();
  }

  // Reading ------------------------------------------------------------------

  @override
  Stream<List<AuctionSummary>> watchDiscover() => _watch(
    () => [
      ..._auctions.values.where((a) => a.isLive).map(_summary),
      ..._auctions.values
          .where((a) => a.isUpcoming && a.sellerId != currentUser()?.id)
          .map(_summary),
    ],
  );

  @override
  Stream<List<AuctionSummary>> watchMyScheduled() => _watch(
    () => [
      for (final a in _auctions.values)
        if (a.isUpcoming && a.sellerId == currentUser()?.id) _summary(a),
    ],
  );

  @override
  Stream<LiveRoom> watchRoom(String auctionId) => _watch(() {
    final auction = _auctions[auctionId];
    if (auction == null || auction.endsAt == null) {
      throw AuctionFailure.notFound;
    }
    return _room(auction);
  });

  @override
  Stream<Money> watchCommitted() => _watch(_committed);

  // Writing ------------------------------------------------------------------

  @override
  Future<void> placeBid(String auctionId, Money amount) async {
    if (simulate) await Future<void>.delayed(const Duration(milliseconds: 250));
    final user = currentUser();
    if (user == null) throw AuctionFailure.notAllowed;
    final auction = _auctions[auctionId];
    if (auction == null) throw AuctionFailure.notFound;
    if (!auction.isLive) throw AuctionFailure.auctionNotLive;
    if (auction.sellerId == user.id) throw AuctionFailure.sellerCannotBid;
    // Same order as place_bid.
    final leader = auction.bids.isEmpty ? null : auction.bids.first;
    if (leader?.bidderId == user.id) throw AuctionFailure.alreadyWinning;
    if (amount.kurus < (auction.currentPrice + auction.minIncrement).kurus) {
      throw AuctionFailure.bidTooLow;
    }
    final limit = _spendingLimit();
    if (limit.enabled && _committed() + amount > limit.amount) {
      throw AuctionFailure.spendingLimitExceeded;
    }
    _bid(auction, user.id, user.username, amount);
    _changes.add(null);
  }

  @override
  Future<void> startAuction(String auctionId) async {
    final auction = _auctions[auctionId];
    if (auction == null) throw AuctionFailure.notFound;
    if (auction.sellerId != currentUser()?.id) throw AuctionFailure.notSeller;
    if (!auction.isUpcoming) throw AuctionFailure.notScheduled;
    final now = _clock();
    auction
      ..startsAt = now
      ..endsAt = now.add(Duration(minutes: auction.durationMinutes));
    _changes.add(null);
  }

  // Internals ----------------------------------------------------------------

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  void _bid(_MockAuction auction, String userId, String username, Money amt) {
    final now = _clock();
    auction.bids.insert(
      0,
      Bid(
        id: 'bid-${_nextBidId++}',
        bidderId: userId,
        username: username,
        amount: amt,
        placedAt: now,
      ),
    );
    auction.currentPrice = amt;
    // Anti-sniping, as the server will do it.
    final endsAt = auction.endsAt!;
    if (endsAt.difference(now) <= antiSnipingWindow) {
      auction.endsAt = endsAt.add(antiSnipingExtension);
    }
  }

  void _tick() {
    final now = _clock();
    for (final auction in _auctions.values.where((a) => a.isLive)) {
      if (!now.isBefore(auction.endsAt!)) {
        auction.ended = true;
        continue;
      }
      // Now and then someone else bids the smallest increment.
      if (_random.nextInt(9) == 0) {
        final bot = _bots[_random.nextInt(_bots.length)];
        if (auction.bids.isEmpty || auction.bids.first.username != bot) {
          _bid(
            auction,
            'bot-$bot',
            bot,
            auction.currentPrice + auction.increments.first,
          );
        }
      }
      auction.viewerCount = max(
        1,
        auction.viewerCount + _random.nextInt(5) - 2,
      );
    }
    _changes.add(null);
  }

  /// As committed_in_window: auctions the user leads, plus those they won
  /// inside the window (the last period, not before their last reset).
  Money _committed() {
    final me = currentUser()?.id;
    if (me == null) return Money.zero;
    final limit = _spendingLimit();
    var windowStart = _clock().subtract(limit.period);
    final resetAt = limit.resetAt;
    if (resetAt != null && resetAt.isAfter(windowStart)) windowStart = resetAt;
    var total = Money.zero;
    for (final auction in _auctions.values) {
      final leader = auction.bids.isEmpty ? null : auction.bids.first;
      if (leader == null || leader.bidderId != me) continue;
      final wonInWindow = auction.ended && auction.endsAt!.isAfter(windowStart);
      if (auction.isLive || wonInWindow) total += leader.amount;
    }
    return total;
  }

  AuctionSummary _summary(_MockAuction a) => AuctionSummary(
    id: a.id,
    title: a.title,
    sellerUsername: a.sellerUsername,
    currentPrice: a.currentPrice,
    startsAt: a.startsAt,
    isLive: a.isLive,
    endsAt: a.endsAt,
    isEnded: a.ended,
    imageUrl: a.imagePath,
    viewerCount: a.viewerCount,
  );

  LiveRoom _room(_MockAuction a) {
    final leader = a.bids.isEmpty ? null : a.bids.first;
    return LiveRoom(
      auctionId: a.id,
      title: a.title,
      sellerId: a.sellerId,
      sellerUsername: a.sellerUsername,
      currentPrice: a.currentPrice,
      endsAt: a.endsAt!,
      minIncrement: a.minIncrement,
      increments: a.increments,
      bids: List.unmodifiable(a.bids.take(20)),
      viewerCount: a.viewerCount,
      ended: a.ended,
      sold: a.ended && leader != null
          ? SoldResult(
              winnerId: leader.bidderId,
              winnerUsername: leader.username,
              amount: leader.amount,
            )
          : null,
    );
  }

  /// The demo catalogue: ten collectables, each with a photo in
  /// `assets/mock/`. Four live, three coming up from other sellers, one of
  /// the signed-in user's own (under Sat) and two already sold.
  void _seed() {
    final now = _clock();
    final me = currentUser();
    void add(_MockAuction a) => _auctions[a.id] = a;

    /// [bids] listed oldest to newest; stored newest first, 25 s apart, the
    /// newest 25 s plus [at] seconds ago.
    List<Bid> history(String id, List<(String, int)> bids, {int at = 0}) => [
      for (final (i, (who, tl)) in bids.reversed.indexed)
        Bid(
          id: 'seed-$id-$i',
          bidderId: 'bot-$who',
          username: who,
          amount: Money.kurus(tl * 100),
          placedAt: now.subtract(Duration(seconds: at + 25 * (i + 1))),
        ),
    ];

    // Live.
    add(
      _MockAuction(
          id: 'canon',
          title: 'Canon AE-1 Program, 50mm f/1.8 lens',
          sellerId: 'seller-analog',
          sellerUsername: 'analogdukkan',
          imagePath: 'assets/mock/canon-ae1.jpg',
          price: const Money.kurus(425000),
          minIncrement: const Money.kurus(2500),
          increments: const [
            Money.kurus(2500),
            Money.kurus(5000),
            Money.kurus(10000),
          ],
          startsAt: now.subtract(const Duration(minutes: 8)),
          endsAt: now.add(const Duration(minutes: 4)),
          viewerCount: 236,
        )
        ..bids.addAll(
          history('canon', [
            ('retro_avcisi', 3900),
            ('analogsever', 4000),
            ('foto_arsiv', 4150),
            ('retro_avcisi', 4250),
          ]),
        ),
    );
    add(
      _MockAuction(
          id: 'panini',
          title: '1998 Panini Dünya Kupası albümü, tam set',
          sellerId: 'seller-kart',
          sellerUsername: 'kartkoleksiyon',
          imagePath: 'assets/mock/panini-album.jpg',
          price: const Money.kurus(310000),
          minIncrement: const Money.kurus(5000),
          increments: const [
            Money.kurus(5000),
            Money.kurus(10000),
            Money.kurus(25000),
          ],
          startsAt: now.subtract(const Duration(minutes: 3)),
          endsAt: now.add(const Duration(minutes: 12)),
          viewerCount: 412,
        )
        ..bids.addAll(
          history('panini', [
            ('albumcu_90lar', 2900),
            ('stickerhane', 3000),
            ('albumcu_90lar', 3100),
          ]),
        ),
    );
    add(
      _MockAuction(
          id: 'seiko',
          title: 'Seiko 5 otomatik saat, 1970’ler, orijinal kordon',
          sellerId: 'seller-saat',
          sellerUsername: 'saatciusta',
          imagePath: 'assets/mock/seiko-5.jpg',
          price: const Money.kurus(275000),
          startsAt: now.subtract(const Duration(minutes: 11)),
          endsAt: now.add(const Duration(seconds: 50)),
          viewerCount: 98,
        )
        ..bids.addAll(
          history('seiko', [('saatsever', 2600), ('kurmali_kol', 2750)]),
        ),
    );
    add(
      _MockAuction(
          id: 'forma',
          title: 'Fenerbahçe 1996 iç saha forması, imzalı',
          sellerId: 'seller-forma',
          sellerUsername: 'formakoleksiyon',
          imagePath: 'assets/mock/fenerbahce-forma.jpg',
          price: const Money.kurus(1850000),
          minIncrement: const Money.kurus(25000),
          increments: const [
            Money.kurus(25000),
            Money.kurus(50000),
            Money.kurus(100000),
          ],
          startsAt: now.subtract(const Duration(minutes: 20)),
          endsAt: now.add(const Duration(minutes: 7)),
          viewerCount: 1240,
        )
        ..bids.addAll(
          history('forma', [
            ('sari_lacivert', 17000),
            ('tribun_arsiv', 17750),
            ('sari_lacivert', 18500),
          ]),
        ),
    );

    // Coming up.
    add(
      _MockAuction(
        id: 'walkman',
        title: 'Sony Walkman WM-F10, kasetli, çalışır',
        sellerId: 'seller-kaset',
        sellerUsername: 'kasetcafe',
        imagePath: 'assets/mock/walkman.jpg',
        price: const Money.kurus(90000),
        startsAt: now.add(const Duration(hours: 2)),
      ),
    );
    add(
      _MockAuction(
        id: 'plak',
        title: '1970’ler Türk pop 45’lik plak seti, 12 adet',
        sellerId: 'seller-plak',
        sellerUsername: 'plakarsivi',
        imagePath: 'assets/mock/plak.jpg',
        price: const Money.kurus(65000),
        startsAt: DateTime(now.year, now.month, now.day + 1, 20, 30),
      ),
    );
    add(
      _MockAuction(
        id: 'kolsaati',
        title: 'Antika kurmalı kol saati, 1950’ler, gümüş kasa',
        sellerId: 'seller-antika',
        sellerUsername: 'antikacimehmet',
        imagePath: 'assets/mock/kol-saati-antika.jpg',
        price: const Money.kurus(550000),
        minIncrement: const Money.kurus(10000),
        startsAt: now.add(const Duration(days: 2, hours: 3)),
      ),
    );

    // The signed-in user's own, planned: shows under Sat.
    add(
      _MockAuction(
        id: 'daktilo',
        title: 'Olivetti Lettera 32 daktilo, Türkçe klavye',
        sellerId: me?.id ?? 'seller-daktilo',
        sellerUsername: me?.username ?? 'eskiyazi',
        imagePath: 'assets/mock/daktilo.jpg',
        price: const Money.kurus(230000),
        startsAt: now.add(const Duration(minutes: 30)),
        durationMinutes: 5,
      ),
    );

    // Sold.
    add(
      _MockAuction(
          id: 'kartlar',
          title: '1990’lar futbolcu kartları, 200 adet',
          sellerId: 'seller-kart',
          sellerUsername: 'kartkoleksiyon',
          imagePath: 'assets/mock/kart-koleksiyon.jpg',
          price: const Money.kurus(115000),
          startsAt: now.subtract(const Duration(hours: 3)),
          endsAt: now.subtract(const Duration(hours: 2, minutes: 50)),
          viewerCount: 154,
        )
        ..ended = true
        ..bids.addAll(
          history('kartlar', [
            ('stickerhane', 1000),
            ('albumcu_90lar', 1150),
          ], at: 600),
        ),
    );
    add(
      _MockAuction(
          id: 'lens',
          title: 'Helios 44-2 58mm lens, M42 bağlantı',
          sellerId: 'seller-analog',
          sellerUsername: 'analogdukkan',
          imagePath: 'assets/mock/kamera-lens.jpg',
          price: const Money.kurus(160000),
          startsAt: now.subtract(const Duration(days: 1, hours: 1)),
          endsAt: now.subtract(const Duration(days: 1)),
          viewerCount: 87,
        )
        ..ended = true
        ..bids.addAll(
          history('lens', [('foto_arsiv', 1500), ('analogsever', 1600)]),
        ),
    );
  }
}

class _MockAuction {
  _MockAuction({
    required this.id,
    required this.title,
    required this.sellerId,
    required this.sellerUsername,
    required Money price,
    required this.startsAt,
    this.endsAt,
    this.imagePath,
    this.minIncrement = const Money.kurus(1000),
    this.increments = defaultIncrements,
    this.viewerCount = 0,
    this.durationMinutes = 10,
  }) : currentPrice = price;

  final String id;
  final String title;
  final String sellerId;
  final String sellerUsername;
  final String? imagePath;
  final Money minIncrement;
  final List<Money> increments;
  final int durationMinutes;
  final bids = <Bid>[];
  Money currentPrice;
  DateTime startsAt;
  DateTime? endsAt;
  int viewerCount;
  bool ended = false;

  bool get isUpcoming => endsAt == null;
  bool get isLive => endsAt != null && !ended;
}
