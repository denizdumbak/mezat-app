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
    'koleksiyoncu_can',
    'eskiye_merakli',
    'zeynep_antik',
    'plakci_baris',
    'vintage_sevgi',
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
    if (amount.kurus < (auction.currentPrice + auction.minIncrement).kurus) {
      throw AuctionFailure.bidTooLow;
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

  void _seed() {
    final now = _clock();
    final me = currentUser();
    void add(_MockAuction a) => _auctions[a.id] = a;

    add(
      _MockAuction(
          id: 'zenit',
          title: 'Zenit-E analog fotoğraf makinesi (1978)',
          sellerId: 'seller-mert',
          sellerUsername: 'antikaci_mert',
          price: const Money.kurus(125000),
          startsAt: now.subtract(const Duration(minutes: 6)),
          endsAt: now.add(const Duration(minutes: 4)),
          viewerCount: 128,
        )
        ..bids.addAll([
          for (final (i, (who, tl)) in [
            ('plakci_baris', 1250),
            ('zeynep_antik', 1200),
            ('koleksiyoncu_can', 1150),
          ].indexed)
            Bid(
              id: 'seed-zenit-$i',
              bidderId: 'bot-$who',
              username: who,
              amount: Money.kurus(tl * 100),
              placedAt: now.subtract(Duration(seconds: 20 * (i + 1))),
            ),
        ]),
    );
    add(
      _MockAuction(
        id: 'kilim',
        title: 'El dokuması Uşak kilimi, 120×180 cm',
        sellerId: 'seller-kilim',
        sellerUsername: 'kilim_evi',
        price: const Money.kurus(480000),
        minIncrement: const Money.kurus(5000),
        increments: const [
          Money.kurus(5000),
          Money.kurus(10000),
          Money.kurus(25000),
        ],
        startsAt: now.subtract(const Duration(minutes: 3)),
        endsAt: now.add(const Duration(minutes: 12)),
        viewerCount: 64,
      ),
    );
    add(
      _MockAuction(
        id: 'telkari',
        title: 'Gümüş telkari broş, Midyat işi',
        sellerId: 'seller-ayse',
        sellerUsername: 'eskici_ayse',
        price: const Money.kurus(35000),
        startsAt: now.add(const Duration(hours: 2)),
      ),
    );
    add(
      _MockAuction(
        id: 'tutunamayanlar',
        title: 'Tutunamayanlar, ilk baskı (1972)',
        sellerId: 'seller-sahaf',
        sellerUsername: 'sahaf_kadikoy',
        price: const Money.kurus(200000),
        startsAt: DateTime(now.year, now.month, now.day + 1, 20),
      ),
    );
    add(
      _MockAuction(
        id: 'seiko',
        title: 'Seiko 5 otomatik kol saati, 1970’ler',
        sellerId: 'seller-levent',
        sellerUsername: 'saatci_levent',
        price: const Money.kurus(90000),
        startsAt: now.add(const Duration(days: 1, hours: 3)),
      ),
    );
    if (me != null) {
      add(
        _MockAuction(
          id: 'cezve',
          title: 'Pirinç cezve takımı, el işi',
          sellerId: me.id,
          sellerUsername: me.username,
          price: const Money.kurus(40000),
          startsAt: now.add(const Duration(minutes: 30)),
          durationMinutes: 5,
        ),
      );
    }
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
    this.minIncrement = const Money.kurus(1000),
    this.increments = defaultIncrements,
    this.viewerCount = 0,
    this.durationMinutes = 10,
  }) : currentPrice = price;

  final String id;
  final String title;
  final String sellerId;
  final String sellerUsername;
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
