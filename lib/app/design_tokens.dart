import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;

/// The single source of colours, sizes, durations and type for the app.
///
/// Widgets never use hex values, `Colors.*` or bare numbers for these; they
/// read them from here (or from the theme built from here). DESIGN.md
/// explains each token; the Turkish token names there map as noted.
abstract final class AppColors {
  /// Background of every screen ("stage").
  static const stage = Color(0xFF0C1424);

  /// Raised surfaces: sheets, panels, fields ("stageRaised").
  static const stageRaised = Color(0xFF152036);

  /// Main text and icons ("onStage").
  static const onStage = Color(0xFFEEF1F7);

  /// Secondary text ("onStageMuted"): 8.5:1 on stage, 7.5:1 on stageRaised.
  static const onStageMuted = Color(0xFFA7B1C6);

  /// Accent and primary button fill ("altın").
  static const gold = Color(0xFFD9A93A);

  /// Text on [gold]: 8.5:1.
  static const onGold = stage;

  /// Last seconds, errors, limit warnings ("zaman"): 6.6:1 on stage.
  static const urgent = Color(0xFFFF6B5B);

  /// Won, success ("onay"): 8.3:1 on stage.
  static const success = Color(0xFF4CC38A);

  /// 1 dp separators and outlines instead of shadows: onStage at 14 %.
  static const line = Color(0x24EEF1F7);

  /// Dims what sits behind a sheet or the "sold" stamp.
  static const scrim = Color(0xB30C1424);
}

/// Only two corner radii exist.
abstract final class AppRadius {
  /// Fields, chips, buttons.
  static const small = 8.0;

  /// Sheets, cards, panels.
  static const large = 16.0;

  static const smallAll = BorderRadius.all(Radius.circular(small));
  static const largeAll = BorderRadius.all(Radius.circular(large));
  static const largeTop = BorderRadius.vertical(top: Radius.circular(large));
}

/// Spacing scale: 4, 8, 12, 16, 24, 32. Screen edges are [edge].
abstract final class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

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

  static const icon = 24.0;
  static const iconSmall = 16.0;

  /// Thumbnail of the seller next to their name.
  static const avatar = 32.0;

  /// Width of the bid feed on the live screen.
  static const bidFeedWidth = 220.0;

  /// Widest a form or list gets on large screens.
  static const contentMaxWidth = 480.0;
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
  /// Headings.
  static const display = 'Fraunces';

  /// Everything else.
  static const body = 'Manrope';

  /// Prices and timers: every digit equally wide, so numbers do not jitter
  /// while they change.
  static const tabular = [FontFeature.tabularFigures()];
}

/// Text styles that are not part of Material's TextTheme.
abstract final class AppTextStyles {
  /// The current price on the live screen.
  static const priceLarge = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 40,
    height: 1.1,
    fontWeight: FontWeight.w800,
    fontFeatures: AppFonts.tabular,
    color: AppColors.onStage,
  );

  /// Prices in lists and rows.
  static const price = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: AppFonts.tabular,
    color: AppColors.onStage,
  );

  /// The countdown.
  static const timer = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: AppFonts.tabular,
    color: AppColors.onStage,
  );

  /// The "SATILDI" stamp.
  static const stamp = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 48,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.gold,
  );
}
