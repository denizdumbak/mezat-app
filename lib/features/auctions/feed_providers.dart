import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/auction_feed_repository.dart';
import '../../data/mock_auction_feed_repository.dart';
import '../auth/session.dart';

/// The app runs on the in-memory mock until the realtime backend exists
/// (M2 lists, M3 bids); tests override this with their own fake.
final auctionFeedRepositoryProvider = Provider<AuctionFeedRepository>((ref) {
  final repository = MockAuctionFeedRepository(
    currentUser: () {
      final id = ref.read(authUserIdProvider).value;
      final username = ref.read(currentProfileProvider).value?.username;
      return id == null || username == null
          ? null
          : (id: id, username: username);
    },
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

final committedTodayProvider = StreamProvider.autoDispose<Money>(
  (ref) => ref.watch(auctionFeedRepositoryProvider).watchCommittedToday(),
);
