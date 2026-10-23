import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../core/photo_picker.dart';
import '../core/supabase_client.dart';
import 'supabase_errors.dart';

final auctionRepositoryProvider = Provider<AuctionRepository>(
  (ref) => AuctionRepository(ref.watch(supabaseClientProvider)),
);

/// What the seller fills in on the create form.
class NewAuction {
  const NewAuction({
    required this.title,
    required this.description,
    required this.startPrice,
    required this.minIncrement,
    required this.durationMinutes,
    required this.startsAt,
  });

  final String title;
  final String description;
  final Money startPrice;
  final Money minIncrement;
  final int durationMinutes;
  final DateTime startsAt;
}

/// Writes to `public.auctions` and the `auction-images` bucket.
///
/// The database decides who may do what (RLS, column privileges, the insert
/// trigger); this class does not re-check it. Every method throws
/// [AuctionFailure] on error.
class AuctionRepository {
  AuctionRepository(this._client);

  final SupabaseClient _client;

  static const imageBucket = 'auction-images';

  /// Uploads [photo] into the user's own folder and returns its object path.
  Future<String> uploadImage({
    required String userId,
    required PickedPhoto photo,
  }) => guardAuctions(() async {
    // A random name: never overwrites an earlier photo, and is not guessable
    // before the auction that uses it is public.
    final path = '$userId/${_randomName()}.${photo.extension}';
    await _client.storage
        .from(imageBucket)
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(contentType: photo.contentType),
        );
    return path;
  });

  Future<void> deleteImage(String path) =>
      guardAuctions(() => _client.storage.from(imageBucket).remove([path]));

  /// Creates the auction (it opens as `scheduled`) and returns its id.
  Future<String> create(NewAuction auction, {String? imagePath}) =>
      guardAuctions(() async {
        final row = await _client
            .from('auctions')
            .insert({
              'title': auction.title,
              'description': auction.description,
              'image_path': imagePath,
              // Sent as text, so no amount ever passes through a double.
              'start_price': auction.startPrice.toDb(),
              'min_increment': auction.minIncrement.toDb(),
              'duration_minutes': auction.durationMinutes,
              'starts_at': auction.startsAt.toUtc().toIso8601String(),
            })
            .select('id')
            .single();
        return row['id'] as String;
      });

  static String _randomName() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
