import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../auctions/feed_providers.dart';

final liveRoomControllerProvider = AsyncNotifierProvider.autoDispose
    .family<LiveRoomController, void, String>(LiveRoomController.new);

/// Sends the user's bids for one auction. The state is loading while a bid
/// is on its way and holds an [AuctionFailure] if it was refused. Safety
/// checks (limit, confirmation) happen in the screen before this is called.
class LiveRoomController extends AsyncNotifier<void> {
  LiveRoomController(this.auctionId);

  final String auctionId;

  @override
  FutureOr<void> build() {}

  Future<void> placeBid(Money amount) => _run(
    () => ref.read(auctionFeedRepositoryProvider).placeBid(auctionId, amount),
  );

  Future<void> _run(Future<void> Function() action) async {
    // One bid at a time: a double tap must not send two.
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
  }
}
