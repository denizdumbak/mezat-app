import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auction_failure.dart';
import '../core/auction_rules.dart';
import '../core/money.dart';
import 'auction_feed_repository.dart';
import 'auction_repository.dart';
import 'supabase_errors.dart';

/// [AuctionFeedRepository] on the real `auctions` table.
///
/// M2 scope: the lists, starting an auction, and a read-only live room.
/// There is no realtime yet, so each list stream emits one snapshot and the
/// screens refresh by pulling down; bids, the bid feed and today's total
/// arrive with place_bid and Realtime in M3, until then the room says that
/// bidding is not open. Every method throws [AuctionFailure] on error.
class SupabaseAuctionFeedRepository implements AuctionFeedRepository {
  SupabaseAuctionFeedRepository(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  // Amounts as text so they never pass through a double (see Money). Two
  // foreign keys point at profiles, so the seller one is named.
  static const _columns =
      'id, title, image_path, status, seller_id, starts_at, ends_at, '
      'current_price::text, min_increment::text, '
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
    final row = await guardAuctions(
      () => _client
          .from('auctions')
          .select(_columns)
          .eq('id', auctionId)
          .maybeSingle(),
    );
    if (row == null) throw AuctionFailure.notFound;
    final auction = _Row(row, _clock());
    final endsAt = auction.endsAt;
    if (endsAt == null) throw AuctionFailure.auctionNotLive;

    final room = LiveRoom(
      auctionId: auction.id,
      title: auction.title,
      sellerId: auction.sellerId,
      sellerUsername: auction.sellerUsername,
      currentPrice: auction.currentPrice,
      endsAt: endsAt,
      minIncrement: auction.minIncrement,
      increments: incrementsFor(auction.minIncrement),
      bids: const [],
      ended: !endsAt.isAfter(_clock()),
      biddingOpen: false,
    );
    yield room;
    // Without realtime, the end is the one change this screen can know
    // about in advance.
    if (!room.ended) {
      await Future<void>.delayed(endsAt.difference(_clock()));
      yield room.copyWith(ended: true);
    }
  }

  @override
  Stream<Money> watchCommitted() => Stream.value(Money.zero);

  @override
  Future<void> startAuction(String auctionId) => guardAuctions(
    () => _client.rpc('start_auction', params: {'p_auction_id': auctionId}),
  );

  @override
  Future<void> placeBid(String auctionId, Money amount) =>
      Future.error(AuctionFailure.biddingNotOpen);

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
      minIncrement = Money.parseDb(row['min_increment'] as String);

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
