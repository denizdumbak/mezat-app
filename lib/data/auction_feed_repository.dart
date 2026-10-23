import '../core/money.dart';

/// An auction as the lists show it.
class AuctionSummary {
  const AuctionSummary({
    required this.id,
    required this.title,
    required this.sellerUsername,
    required this.currentPrice,
    required this.startsAt,
    required this.isLive,
    this.imageUrl,
    this.viewerCount = 0,
  });

  final String id;
  final String title;
  final String sellerUsername;
  final Money currentPrice;

  /// Planned start while upcoming, actual start once live.
  final DateTime startsAt;
  final bool isLive;
  final String? imageUrl;
  final int viewerCount;
}

class Bid {
  const Bid({
    required this.id,
    required this.bidderId,
    required this.username,
    required this.amount,
    required this.placedAt,
  });

  final String id;
  final String bidderId;
  final String username;
  final Money amount;
  final DateTime placedAt;
}

/// How an auction ended.
class SoldResult {
  const SoldResult({
    required this.winnerId,
    required this.winnerUsername,
    required this.amount,
  });

  final String winnerId;
  final String winnerUsername;
  final Money amount;
}

/// Everything the live screen shows, as one snapshot.
class LiveRoom {
  const LiveRoom({
    required this.auctionId,
    required this.title,
    required this.sellerId,
    required this.sellerUsername,
    required this.currentPrice,
    required this.endsAt,
    required this.minIncrement,
    required this.increments,
    required this.bids,
    this.viewerCount = 0,
    this.myMaxBid,
    this.ended = false,
    this.sold,
    this.connected = true,
    this.biddingOpen = true,
  });

  final String auctionId;
  final String title;
  final String sellerId;
  final String sellerUsername;
  final Money currentPrice;
  final DateTime endsAt;

  /// The smallest step the server accepts.
  final Money minIncrement;

  /// The seller's increment chips, smallest first; each >= [minIncrement].
  final List<Money> increments;

  /// Newest first.
  final List<Bid> bids;
  final int viewerCount;

  /// The signed-in user's maximum (proxy) bid, if they set one.
  final Money? myMaxBid;

  /// True once the time is up (the server finalizes it).
  final bool ended;

  /// The winner, once ended with at least one bid.
  final SoldResult? sold;

  /// False while the realtime connection is down; bidding is paused.
  final bool connected;

  /// False where bids cannot be placed yet (real auctions until M3 adds
  /// place_bid).
  final bool biddingOpen;

  Bid? get leadingBid => bids.isEmpty ? null : bids.first;

  LiveRoom copyWith({
    Money? currentPrice,
    DateTime? endsAt,
    List<Bid>? bids,
    int? viewerCount,
    Money? myMaxBid,
    bool? ended,
    SoldResult? sold,
    bool? connected,
    bool? biddingOpen,
  }) => LiveRoom(
    auctionId: auctionId,
    title: title,
    sellerId: sellerId,
    sellerUsername: sellerUsername,
    currentPrice: currentPrice ?? this.currentPrice,
    endsAt: endsAt ?? this.endsAt,
    minIncrement: minIncrement,
    increments: increments,
    bids: bids ?? this.bids,
    viewerCount: viewerCount ?? this.viewerCount,
    myMaxBid: myMaxBid ?? this.myMaxBid,
    ended: ended ?? this.ended,
    sold: sold ?? this.sold,
    connected: connected ?? this.connected,
    biddingOpen: biddingOpen ?? this.biddingOpen,
  );
}

/// Read side of auctions for the discover, live and room screens, plus
/// bidding. [SupabaseAuctionFeedRepository] serves real auctions (lists and start
/// now; bids and realtime with M3); [MockAuctionFeedRepository] is the demo
/// mode with simulated bidders.
///
/// Every method throws [AuctionFailure] on error.
abstract interface class AuctionFeedRepository {
  /// Live and upcoming auctions; live ones first.
  Stream<List<AuctionSummary>> watchDiscover();

  /// Auctions the signed-in user is selling that have not started yet.
  Stream<List<AuctionSummary>> watchMyScheduled();

  Stream<LiveRoom> watchRoom(String auctionId);

  /// What the signed-in user has committed today: the sum of the auctions
  /// they lead or won today. Feeds the daily spending limit.
  Stream<Money> watchCommittedToday();

  /// The seller goes live (start_auction).
  Future<void> startAuction(String auctionId);

  Future<void> placeBid(String auctionId, Money amount);

  /// The system bids for the user, one minimum step at a time, up to [max].
  Future<void> setMaxBid(String auctionId, Money max);
}
