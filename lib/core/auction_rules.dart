import 'money.dart';

// Auction rules the UI shows. The server is the judge (place_bid, M3); these
// mirror it so the rule line and the extension chip tell the truth.

/// A bid this close to the end extends the auction (anti-sniping).
const antiSnipingWindow = Duration(seconds: 30);

/// How far such a bid moves the end.
const antiSnipingExtension = Duration(seconds: 30);

/// Increment chips when the seller has not chosen their own: +₺10, +₺50,
/// +₺100.
const defaultIncrements = [
  Money.kurus(1000),
  Money.kurus(5000),
  Money.kurus(10000),
];

/// Most chips a seller can choose (the database allows three).
const maxIncrementChips = 3;

/// The chips the room shows: the seller's [chosen] ones, or when there are
/// none, the defaults if they all meet [minIncrement], otherwise 1×, 5× and
/// 10× of it (the server refuses a step below the minimum).
List<Money> incrementsFor(
  Money minIncrement, {
  List<Money> chosen = const [],
}) => chosen.isNotEmpty
    ? chosen
    : defaultIncrements.first >= minIncrement
    ? defaultIncrements
    : [minIncrement, minIncrement * 5, minIncrement * 10];
