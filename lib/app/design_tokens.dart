import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;

/// The single source of colours, sizes, durations and type for the app.
///
/// Widgets never use hex values, `Colors.*` or bare numbers for these. Sizes,
/// spacing, radii and type come from here; colours come from the theme
/// (`ColorScheme` and `AppPalette` in theme.dart), which is built from
/// [AppColors], so one widget looks right in both the light browse theme and
/// the dark live-room theme. DESIGN.md explains each token.
abstract final class AppColors {
  // Browse (light): every screen except the live room.

  /// Screen background.
  static const surface = Color(0xFFFFFFFF);

  /// Secondary surface: panels, fields, chips.
  static const surfaceAlt = Color(0xFFF4F4F5);

  /// Separators and outlines.
  static const line = Color(0xFFE4E4E7);

  /// Main text and icons: 19.8:1 on [surface].
  static const text = Color(0xFF0A0A0B);

  /// Secondary text: 7.7:1 on [surface], 7.0:1 on [surfaceAlt].
  static const textMuted = Color(0xFF52525B);

  /// Disabled controls only, never readable text.
  static const disabled = Color(0xFFA1A1AA);

  /// Error text and outlines on light: 4.8:1 on [surface].
  static const error = Color(0xFFDC2626);

  // Live room (dark).

  static const liveSurface = Color(0xFF0A0A0B);
  static const liveText = Color(0xFFFFFFFF);

  /// 7.7:1 on [liveSurface].
  static const liveTextMuted = Color(0xFFA1A1AA);

  /// White at 12 %.
  static const liveLine = Color(0x1FFFFFFF);

  /// Error text on dark: 7.2:1 on [liveSurface].
  static const errorOnDark = Color(0xFFF87171);

  /// Panels over the video: black at 60 %, always with a blur behind.
  static const scrim = Color(0x99000000);

  /// Nearly hides what is behind: the "sold" and "time is up" moments.
  static const scrimStrong = Color(0xEB000000);

  // Both themes.

  /// The one accent: bid button, primary call to action, selected tab.
  /// Never text links or large areas.
  static const accent = Color(0xFFFFB020);

  /// Text on [accent]: 10.8:1.
  static const onAccent = Color(0xFF0A0A0B);

  /// Live: only the live badge and dot, and the countdown in its last
  /// seconds.
  static const live = Color(0xFFEF4444);

  /// Won, done. 6.0:1 on [scrimStrong] over [liveSurface].
  static const success = Color(0xFF16A34A);

  /// Waiting states (a connection coming back), never errors.
  static const warning = Color(0xFFF59E0B);
}

/// Corner radii.
abstract final class AppRadius {
  /// Photos and form fields.
  static const image = 12.0;

  /// Cards and panels.
  static const card = 16.0;

  /// Top corners of a bottom panel or sheet.
  static const sheet = 24.0;

  /// Fully round: chips, pill buttons, badges.
  static const pill = 999.0;

  static const imageAll = BorderRadius.all(Radius.circular(image));
  static const cardAll = BorderRadius.all(Radius.circular(card));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Spacing scale: 4, 8, 12, 16, 24, 32, 48. Screen edges are [edge].
abstract final class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Horizontal screen padding.
  static const edge = l;
}

abstract final class AppSize {
  /// Smallest tap target.
  static const touch = 48.0;

  /// Height of the bid button.
  static const bidButton = 56.0;

  /// Separator and outline width.
  static const line = 1.0;

  /// Outline of a selected chip: heavier than a separator.
  static const selectedLine = 2.0;

  static const icon = 24.0;
  static const iconSmall = 16.0;

  /// Thumbnail of the seller next to their name.
  static const avatar = 32.0;

  /// The seller's avatar on an auction card, next to a caption.
  static const avatarSmall = 20.0;

  /// The user's own avatar on the profile screen.
  static const avatarLarge = 56.0;

  /// Frame of the "SATILDI" stamp: heavier than a separator on purpose.
  static const stampBorder = 3.0;

  /// Square photo in the live list.
  static const thumbnail = 88.0;

  /// Width of a card in the "live now" strip.
  static const liveCardWidth = 168.0;

  /// Room under a live card's photo for the seller, a two-line title and
  /// the price (before text scaling).
  static const liveCardInfo = 112.0;

  /// Height of an item in the tab bar.
  static const tabBar = 64.0;

  /// Width of the bid feed on the live screen.
  static const bidFeedWidth = 220.0;

  /// Widest a form or list gets on large screens.
  static const contentMaxWidth = 480.0;

  /// Blur behind the panels that sit on the live video.
  static const panelBlur = 20.0;
}

/// Motion durations. Entering uses [AppCurves.enter], leaving [AppCurves.exit].
abstract final class AppDurations {
  static const press = Duration(milliseconds: 120);
  static const entry = Duration(milliseconds: 180);
  static const price = Duration(milliseconds: 220);
  static const extend = Duration(milliseconds: 240);
  static const sold = Duration(milliseconds: 700);
}

abstract final class AppCurves {
  static const enter = Curves.easeOut;
  static const exit = Curves.easeIn;
}

/// False when the user asked the system to reduce motion; animated widgets
/// then only fade.
bool motionAllowed(BuildContext context) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

abstract final class AppFonts {
  /// The only family.
  static const body = 'Manrope';

  /// Prices and timers: every digit equally wide, so numbers do not jitter
  /// while they change.
  static const tabular = [FontFeature.tabularFigures()];
}

/// The type scale. Material's TextTheme roles map onto it in theme.dart;
/// nothing is smaller than [caption].
abstract final class AppTypeScale {
  /// Page and sheet titles. 22/28 w700.
  static const title = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );

  /// Section heads, row titles, button text. 17/22 w700.
  static const headline = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w700,
  );

  /// Running text, including long explanations. 15/22 w400.
  static const body = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );

  /// Chips, segments, small controls. 13/18 w600.
  static const label = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );

  /// Short helper text and meta lines. 12/16 w500.
  static const caption = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
}

/// Numbers. Tabular and w800 everywhere; colour comes from the surrounding
/// theme.
abstract final class AppTextStyles {
  /// The current price in the live room, and nowhere else. 40/44.
  static const priceDisplay = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w800,
    fontFeatures: AppFonts.tabular,
  );

  /// Prices in lists, cards and rows. 17/22.
  static const price = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w800,
    fontFeatures: AppFonts.tabular,
  );

  /// The countdown. 22/28.
  static const timer = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w800,
    fontFeatures: AppFonts.tabular,
  );

  /// The "SATILDI" stamp, at the live price size. Success green.
  static const stamp = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 40,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    color: AppColors.success,
  );
}
