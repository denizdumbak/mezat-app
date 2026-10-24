import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auction_failure.dart';
import '../core/auction_rules.dart';
import '../core/money.dart';
import 'auction_feed_repository.dart';
import 'auction_repository.dart';
import 'supabase_errors.dart';

/// [AuctionFeedRepository] on the real `auctions` table.
///
/// The lists, starting an auction, the live room and bidding (place_bid).
/// There is no realtime yet (M3 step 8): each list stream emits one snapshot
/// and the screens refresh by pulling down; the room and the total counted
/// against the limit load again after this user's own bids, and the room at
/// its end. Every method throws [AuctionFailure] on error.
class SupabaseAuctionFeedRepository implements AuctionFeedRepository {
  SupabaseAuctionFeedRepository(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  /// Fires after this user's own bid, so the room and the total reload.
  final _changes = StreamController<void>.broadcast();

  /// How many bids the room loads; the feed shows fewer.
  static const _bidsInRoom = 20;

  // Amounts as text so they never pass through a double (see Money). Two
  // foreign keys point at profiles, so the seller one is named.
  static const _columns =
      'id, title, image_path, status, seller_id, starts_at, ends_at, '
      'current_price::text, min_increment::text, bid_increments::text, '
      'current_winner_id, '
      'seller:profiles!auctions_seller_id_fkey(username)';

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Stream<List<AuctionSummary>> watchDiscover() => Stream.fromFuture(
    guardAuctions(() async {
      final rows = await _client
          .from('auctions')
          .select(_columns)
          .inFilter('status', ['scheduled', 'live'])
          .order('starts_at');
      final now = _clock();
      final me = _userId;
      final auctions = rows.map((row) => _Row(row, now)).toList();
      return [
        // Live ones whose time is not up yet (M5 finalizes the rest).
        for (final a in auctions)
          if (a.isLive) a.toSummary(_publicUrl),
        // Upcoming ones of other sellers; your own are under Sat.
        for (final a in auctions)
          if (a.isScheduled && a.sellerId != me) a.toSummary(_publicUrl),
      ];
    }),
  );

  @override
  Stream<List<AuctionSummary>> watchMyScheduled() => Stream.fromFuture(
    guardAuctions(() async {
      final me = _userId;
      if (me == null) return const <AuctionSummary>[];
      final rows = await _client
          .from('auctions')
          .select(_columns)
          .eq('seller_id', me)
          .eq('status', 'scheduled')
          .order('starts_at');
      final now = _clock();
      return [for (final row in rows) _Row(row, now).toSummary(_publicUrl)];
    }),
  );

  @override
  Stream<LiveRoom> watchRoom(String auctionId) async* {
    while (true) {
      // Listen before loading: a bid sent while this loads (or while the
      // screen has not asked for the next room yet) must not be missed.
      final changed = _changes.stream.first;
      final room = await _loadRoom(auctionId);
      yield room;
      // Until realtime, the changes this screen can know about: the user's
      // own bid, and the end.
      final remaining = room.endsAt.difference(_clock());
      await Future.any([
        changed,
        if (!room.ended) Future<void>.delayed(remaining),
      ]);
    }
  }

  Future<LiveRoom> _loadRoom(String auctionId) => guardAuctions(() async {
    final row = await _client
        .from('auctions')
        .select(_columns)
        .eq('id', auctionId)
        .maybeSingle();
    if (row == null) throw AuctionFailure.notFound;
    final now = _clock();
    final auction = _Row(row, now);
    final endsAt = auction.endsAt;
    if (endsAt == null) throw AuctionFailure.auctionNotLive;

    final bidRows = await _client
        .from('bids')
        .select(
          'id, bidder_id, amount::text, created_at, '
          'bidder:profiles(username)',
        )
        .eq('auction_id', auctionId)
        .order('created_at', ascending: false)
        .limit(_bidsInRoom);
    final bids = [for (final bid in bidRows) _parseBid(bid)];

    final ended = !endsAt.isAfter(now);
    final winnerId = auction.currentWinnerId;
    return LiveRoom(
      auctionId: auction.id,
      title: auction.title,
      sellerId: auction.sellerId,
      sellerUsername: auction.sellerUsername,
      currentPrice: auction.currentPrice,
      endsAt: endsAt,
      minIncrement: auction.minIncrement,
      increments: incrementsFor(
        auction.minIncrement,
        chosen: auction.bidIncrements,
      ),
      bids: bids,
      ended: ended,
      // The leader holds the current price, so the newest bid names them.
      sold: ended && winnerId != null && bids.isNotEmpty
          ? SoldResult(
              winnerId: winnerId,
              winnerUsername: bids.first.username,
              amount: auction.currentPrice,
            )
          : null,
    );
  });

  static Bid _parseBid(Map<String, dynamic> row) => Bid(
    id: row['id'] as String,
    bidderId: row['bidder_id'] as String,
    username:
        (row['bidder'] as Map<String, dynamic>?)?['username'] as String? ?? '',
    amount: Money.parseDb(row['amount'] as String),
    placedAt: DateTime.parse(row['created_at'] as String),
  );

  @override
  Stream<Money> watchCommitted() async* {
    while (true) {
      final changed = _changes.stream.first;
      yield await _loadCommitted();
      await changed;
    }
  }

  Future<Money> _loadCommitted() => guardAuctions(() async {
    if (_userId == null) return Money.zero;
    // A scalar result arrives as a JSON number. Its shortest text form is
    // the decimal the database sent ("1250.5"), so it is parsed from that
    // text and never used as a double.
    final total = await _client.rpc<num>('committed_in_window');
    return Money.parseDb(total.toString());
  });

  @override
  Future<void> startAuction(String auctionId) => guardAuctions(
    () => _client.rpc('start_auction', params: {'p_auction_id': auctionId}),
  );

  @override
  Future<void> placeBid(String auctionId, Money amount) =>
      guardAuctions(() async {
        // The bidder comes from the JWT on the server, never from here.
        await _client.rpc(
          'place_bid',
          params: {'p_auction_id': auctionId, 'p_amount': amount.toDb()},
        );
        _changes.add(null);
      });

  String _publicUrl(String path) =>
      _client.storage.from(AuctionRepository.imageBucket).getPublicUrl(path);
}

/// One row of [SupabaseAuctionFeedRepository._columns], parsed.
class _Row {
  _Row(Map<String, dynamic> row, this.now)
    : id = row['id'] as String,
      title = row['title'] as String,
      imagePath = row['image_path'] as String?,
      status = row['status'] as String,
      sellerId = row['seller_id'] as String,
      sellerUsername =
          (row['seller'] as Map<String, dynamic>?)?['username'] as String? ??
          '',
      startsAt = DateTime.parse(row['starts_at'] as String),
      endsAt = row['ends_at'] == null
          ? null
          : DateTime.parse(row['ends_at'] as String),
      currentPrice = Money.parseDb(row['current_price'] as String),
      minIncrement = Money.parseDb(row['min_increment'] as String),
      currentWinnerId = row['current_winner_id'] as String?,
      bidIncrements = _parseDbArray(row['bid_increments'] as String);

  final DateTime now;
  final String id;
  final String title;
  final String? imagePath;
  final String status;
  final String sellerId;
  final String sellerUsername;
  final DateTime startsAt;
  final DateTime? endsAt;
  final Money currentPrice;
  final Money minIncrement;
  final String? currentWinnerId;
  final List<Money> bidIncrements;

  /// A numeric array cast to text: '{10.00,25.50}', or '{}' when empty.
  static List<Money> _parseDbArray(String raw) {
    final inner = raw.substring(1, raw.length - 1);
    return [
      if (inner.isNotEmpty)
        for (final item in inner.split(',')) Money.parseDb(item),
    ];
  }

  bool get isScheduled => status == 'scheduled';
  bool get isLive => status == 'live' && endsAt != null && endsAt!.isAfter(now);

  AuctionSummary toSummary(String Function(String path) publicUrl) =>
      AuctionSummary(
        id: id,
        title: title,
        sellerUsername: sellerUsername,
        currentPrice: currentPrice,
        startsAt: startsAt,
        isLive: isLive,
        endsAt: endsAt,
        isEnded: status == 'ended',
        imageUrl: imagePath == null ? null : publicUrl(imagePath!),
      );
}
