import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auction_failure.dart';
import '../../core/photo_picker.dart';
import '../../data/auction_repository.dart';
import '../auth/session.dart';

final createAuctionControllerProvider =
    AsyncNotifierProvider.autoDispose<CreateAuctionController, String?>(
      CreateAuctionController.new,
    );

/// Creates an auction from the form: uploads the photo (if any), then inserts
/// the row. The state holds the new auction's id once it exists, or an
/// [AuctionFailure].
class CreateAuctionController extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<void> submit(NewAuction auction, {PickedPhoto? photo}) async {
    // Ignore a second tap while the first request is still running.
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _create(auction, photo));
    if (ref.mounted) state = result;
  }

  Future<String> _create(NewAuction auction, PickedPhoto? photo) async {
    final userId = ref.read(authUserIdProvider).value;
    if (userId == null) throw AuctionFailure.notAllowed;
    final repository = ref.read(auctionRepositoryProvider);

    final imagePath = photo == null
        ? null
        : await repository.uploadImage(userId: userId, photo: photo);
    try {
      return await repository.create(auction, imagePath: imagePath);
    } catch (_) {
      // Do not leave an unused photo behind. Best effort: if the cleanup
      // fails too, the user should still see why creating failed.
      if (imagePath != null) {
        try {
          await repository.deleteImage(imagePath);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
