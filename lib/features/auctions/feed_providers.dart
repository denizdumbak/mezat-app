import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/supabase_client.dart';
import '../../data/auction_feed_repository.dart';
import '../../data/mock_auction_feed_repository.dart';
import '../../data/spending_limit_repository.dart';
import '../../data/supabase_auction_feed_repository.dart';
import '../auth/session.dart';
import '../live_room/bid_safety.dart';

/// Demo mode: `--dart-define=MOCK_FEED=true` runs the lists and the live
/// room on simulated auctions and bidders, to show bidding before M3.
const useMockFeed = bool.fromEnvironment('MOCK_FEED');

/// Real auctions from Supabase, or the demo mock. Tests override this with
/// their own fake.
final auctionFeedRepositoryProvider = Provider<AuctionFeedRepository>((ref) {
  if (!useMockFeed) {
    return SupabaseAuctionFeedRepository(ref.watch(supabaseClientProvider));
  }
  final repository = MockAuctionFeedRepository(
    currentUser: () {
      final id = ref.read(authUserIdProvider).value;
      final username = ref.read(currentProfileProvider).value?.username;
      return id == null || username == null
          ? null
          : (id: id, username: username);
    },
    spendingLimit: () =>
        ref.read(spendingLimitProvider).value ?? SpendingLimit.defaults,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final discoverProvider = StreamProvider.autoDispose<List<AuctionSummary>>(
  (ref) => ref.watch(auctionFeedRepositoryProvider).watchDiscover(),
);

final myScheduledProvider = StreamProvider.autoDispose<List<AuctionSummary>>(
  (ref) => ref.watch(auctionFeedRepositoryProvider).watchMyScheduled(),
);

final liveRoomProvider = StreamProvider.autoDispose.family<LiveRoom, String>(
  (ref, auctionId) =>
      ref.watch(auctionFeedRepositoryProvider).watchRoom(auctionId),
);

/// The total counted against the user's spending limit right now.
final committedProvider = StreamProvider.autoDispose<Money>(
  (ref) => ref.watch(auctionFeedRepositoryProvider).watchCommitted(),
);

/// Reloads the lists after something changed them (an auction created or
/// started). Until realtime arrives in M3, nothing else would.
void refreshAuctionLists(WidgetRef ref) {
  ref
    ..invalidate(discoverProvider)
    ..invalidate(myScheduledProvider);
}
