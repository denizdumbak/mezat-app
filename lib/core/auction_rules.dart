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
