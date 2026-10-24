import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/app/app.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/auth_failure.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/photo_picker.dart';
import 'package:mezat_app/data/auction_feed_repository.dart';
import 'package:mezat_app/data/auction_repository.dart';
import 'package:mezat_app/data/auth_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:mezat_app/features/auctions/feed_providers.dart';
import 'package:mezat_app/data/spending_limit_repository.dart';
import 'package:mezat_app/features/live_room/bid_safety.dart';

/// In-memory stand-in for Supabase Auth.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? signedInAs}) : _userId = signedInAs;

  final _changes = StreamController<String?>.broadcast();
  String? _userId;

  /// Every call, e.g. `signIn:deniz@example.com`.
  final calls = <String>[];

  /// Thrown (once) by the next call instead of succeeding.
  Object? nextError;

  /// When set, calls wait for it to complete; lets a test see the loading state.
  Completer<void>? gate;

  /// Simulates a project with email confirmation switched on.
  bool requireEmailConfirmation = false;

  static const signedInUserId = 'user-1';

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> userIdChanges() => _changes.stream;

  @override
  Future<bool> signUp({required String email, required String password}) async {
    calls.add('signUp:$email');
    await _proceed();
    if (requireEmailConfirmation) return false;
    _setUser(signedInUserId);
    return true;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    await _proceed();
    _setUser(signedInUserId);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    await _proceed();
    _setUser(null);
  }

  Future<void> _proceed() async {
    await gate?.future;
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
  }

  void _setUser(String? userId) {
    _userId = userId;
    _changes.add(userId);
  }
}

/// In-memory stand-in for the profiles table, including its unique username.
class FakeProfileRepository implements ProfileRepository {
  final profiles = <String, Profile>{};

  /// Thrown by fetchProfile while set.
  Object? fetchError;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    final error = fetchError;
    if (error != null) throw error;
    return profiles[userId] ?? Profile(id: userId, username: null);
  }

  @override
  Future<Profile> setUsername({
    required String userId,
    required String username,
  }) async {
    final taken = profiles.values.any(
      (p) => p.username == username && p.id != userId,
    );
    if (taken) throw AuthFailure.usernameTaken;
    return profiles[userId] = Profile(id: userId, username: username);
  }
}

/// In-memory stand-in for the auctions table and the auction-images bucket.
class FakeAuctionRepository implements AuctionRepository {
  final created = <({NewAuction auction, String? imagePath})>[];
  final uploaded = <String>[];
  final deleted = <String>[];

  /// Thrown (once) by the next create / upload instead of succeeding.
  Object? createError;
  Object? uploadError;

  /// When set, create waits for it; lets a test see the loading state.
  Completer<void>? gate;

  @override
  Future<String> uploadImage({
    required String userId,
    required PickedPhoto photo,
  }) async {
    final error = uploadError;
    uploadError = null;
    if (error != null) throw error;
    final path = '$userId/photo-${uploaded.length}.${photo.extension}';
    uploaded.add(path);
    return path;
  }

  @override
  Future<void> deleteImage(String path) async => deleted.add(path);

  @override
  Future<String> create(NewAuction auction, {String? imagePath}) async {
    await gate?.future;
    final error = createError;
    createError = null;
    if (error != null) throw error;
    created.add((auction: auction, imagePath: imagePath));
    return 'auction-${created.length}';
  }
}

/// Returns [next] (or throws [error]) instead of opening a gallery.
class FakePhotoPicker implements PhotoPicker {
  PickedPhoto? next;
  Object? error;

  @override
  Future<PickedPhoto?> pick() async {
    final error = this.error;
    if (error != null) throw error;
    return next;
  }
}

/// Controllable stand-in for the auction feed: tests set the lists and rooms,
/// then call [emit] to push the change to listening screens.
class FakeAuctionFeedRepository implements AuctionFeedRepository {
  List<AuctionSummary> discover = [];
  List<AuctionSummary> myScheduled = [];
  final rooms = <String, LiveRoom>{};
  Money committed = Money.zero;

  /// Makes the discover stream fail while set.
  Object? discoverError;

  /// Keeps the discover list from ever arriving: the loading state.
  bool discoverPending = false;

  /// Thrown (once) by the next bid instead of succeeding.
  Object? nextBidError;

  /// When set, bids wait for it; lets a test see the sending state.
  Completer<void>? bidGate;

  final placed = <({String auctionId, Money amount})>[];
  final started = <String>[];

  final _changes = StreamController<void>.broadcast();

  void emit() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  /// How many times a screen subscribed to the discover list (pull to
  /// refresh and invalidation subscribe again).
  var discoverCalls = 0;

  @override
  Stream<List<AuctionSummary>> watchDiscover() {
    discoverCalls++;
    if (discoverPending) return StreamController<List<AuctionSummary>>().stream;
    return _watch(() {
      final error = discoverError;
      if (error != null) throw error;
      return discover;
    });
  }

  @override
  Stream<List<AuctionSummary>> watchMyScheduled() => _watch(() => myScheduled);

  @override
  Stream<LiveRoom> watchRoom(String auctionId) =>
      _watch(() => rooms[auctionId] ?? (throw AuctionFailure.notFound));

  @override
  Stream<Money> watchCommitted() => _watch(() => committed);

  @override
  Future<void> startAuction(String auctionId) async => started.add(auctionId);

  @override
  Future<void> placeBid(String auctionId, Money amount) async {
    await bidGate?.future;
    final error = nextBidError;
    nextBidError = null;
    if (error != null) throw error;
    placed.add((auctionId: auctionId, amount: amount));
  }
}

/// Pumps the whole app on top of the fakes and waits for the first screen.
Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeProfileRepository? profiles,
  FakeAuctionRepository? auctions,
  FakePhotoPicker? photoPicker,
  FakeAuctionFeedRepository? feed,
  SpendingLimitRepository? spendingLimit,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(
          profiles ?? FakeProfileRepository(),
        ),
        auctionRepositoryProvider.overrideWithValue(
          auctions ?? FakeAuctionRepository(),
        ),
        photoPickerProvider.overrideWithValue(photoPicker ?? FakePhotoPicker()),
        auctionFeedRepositoryProvider.overrideWithValue(
          feed ?? FakeAuctionFeedRepository(),
        ),
        spendingLimitRepositoryProvider.overrideWithValue(
          spendingLimit ?? InMemorySpendingLimitRepository(),
        ),
      ],
      // Riverpod retries failed providers by default; tests want the failure.
      retry: (retryCount, error) => null,
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}
