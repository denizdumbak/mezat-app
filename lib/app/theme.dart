import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Light: every screen except the live room. The app's default theme.
final ThemeData browseTheme = _buildTheme(_browseScheme, AppPalette.forBrowse);

/// Dark: the live room (`/auctions/:id/live`), where the video is the stage.
final ThemeData liveTheme = _buildTheme(_liveScheme, AppPalette.forLive);

/// Colours the ColorScheme has no role for. Widgets read them with
/// `context.palette`, so they follow the theme they sit in.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.live,
    required this.success,
    required this.warning,
    required this.panel,
    required this.panelBlurred,
    required this.scrimStrong,
    required this.disabled,
    required this.errorOnInverse,
    this.overlay = AppColors.scrim,
    this.onOverlay = AppColors.liveText,
  });

  static const forBrowse = AppPalette(
    live: AppColors.live,
    success: AppColors.success,
    warning: AppColors.warning,
    panel: AppColors.surfaceAlt,
    panelBlurred: false,
    scrimStrong: AppColors.scrimStrong,
    disabled: AppColors.disabled,
    errorOnInverse: AppColors.errorOnDark,
  );

  static const forLive = AppPalette(
    live: AppColors.live,
    success: AppColors.success,
    warning: AppColors.warning,
    panel: AppColors.scrim,
    panelBlurred: true,
    scrimStrong: AppColors.scrimStrong,
    disabled: AppColors.disabled,
    errorOnInverse: AppColors.error,
  );

  /// The live badge and dot, and the countdown's last seconds.
  final Color live;
  final Color success;

  /// Waiting states; never errors.
  final Color warning;

  /// Background of panels and chips: the secondary surface in the browse
  /// theme, the 60 % black scrim over the video in the live room.
  final Color panel;

  /// Whether [panel] needs a blur behind it (it is see-through).
  final bool panelBlurred;

  /// Over the room for the "sold" and "time is up" moments.
  final Color scrimStrong;

  /// Disabled controls only.
  final Color disabled;

  /// Small pills drawn on photos and video (viewer count): dark in both
  /// themes, since what is behind them is a picture.
  final Color overlay;
  final Color onOverlay;

  /// Error icons on the inverse surface (the snackbar).
  final Color errorOnInverse;

  @override
  AppPalette copyWith({
    Color? live,
    Color? success,
    Color? warning,
    Color? panel,
    bool? panelBlurred,
    Color? scrimStrong,
    Color? disabled,
    Color? overlay,
    Color? onOverlay,
    Color? errorOnInverse,
  }) => AppPalette(
    live: live ?? this.live,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    panel: panel ?? this.panel,
    panelBlurred: panelBlurred ?? this.panelBlurred,
    scrimStrong: scrimStrong ?? this.scrimStrong,
    disabled: disabled ?? this.disabled,
    overlay: overlay ?? this.overlay,
    onOverlay: onOverlay ?? this.onOverlay,
    errorOnInverse: errorOnInverse ?? this.errorOnInverse,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Built by hand from [AppColors] rather than `ColorScheme.fromSeed`, whose
/// generated tones would not match the palette.
const _browseScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.accent,
  onPrimary: AppColors.onAccent,
  primaryContainer: AppColors.surfaceAlt,
  onPrimaryContainer: AppColors.text,
  secondary: AppColors.text,
  onSecondary: AppColors.surface,
  secondaryContainer: AppColors.surfaceAlt,
  onSecondaryContainer: AppColors.text,
  tertiary: AppColors.success,
  onTertiary: AppColors.surface,
  error: AppColors.error,
  onError: AppColors.surface,
  surface: AppColors.surface,
  onSurface: AppColors.text,
  onSurfaceVariant: AppColors.textMuted,
  surfaceContainerLowest: AppColors.surface,
  surfaceContainerLow: AppColors.surfaceAlt,
  surfaceContainer: AppColors.surfaceAlt,
  surfaceContainerHigh: AppColors.surfaceAlt,
  surfaceContainerHighest: AppColors.surfaceAlt,
  outline: AppColors.line,
  outlineVariant: AppColors.line,
  shadow: AppColors.text,
  scrim: AppColors.scrim,
  inverseSurface: AppColors.text,
  onInverseSurface: AppColors.surface,
  inversePrimary: AppColors.accent,
  surfaceTint: AppColors.surface,
);

const _liveScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.accent,
  onPrimary: AppColors.onAccent,
  primaryContainer: AppColors.liveSurface,
  onPrimaryContainer: AppColors.liveText,
  secondary: AppColors.liveText,
  onSecondary: AppColors.liveSurface,
  secondaryContainer: AppColors.liveSurface,
  onSecondaryContainer: AppColors.liveText,
  tertiary: AppColors.success,
  onTertiary: AppColors.liveSurface,
  error: AppColors.errorOnDark,
  onError: AppColors.liveSurface,
  surface: AppColors.liveSurface,
  onSurface: AppColors.liveText,
  onSurfaceVariant: AppColors.liveTextMuted,
  surfaceContainerLowest: AppColors.liveSurface,
  surfaceContainerLow: AppColors.liveSurface,
  surfaceContainer: AppColors.liveSurface,
  surfaceContainerHigh: AppColors.liveSurface,
  surfaceContainerHighest: AppColors.liveSurface,
  outline: AppColors.liveLine,
  outlineVariant: AppColors.liveLine,
  shadow: AppColors.liveSurface,
  scrim: AppColors.scrim,
  inverseSurface: AppColors.liveText,
  onInverseSurface: AppColors.liveSurface,
  inversePrimary: AppColors.accent,
  surfaceTint: AppColors.liveSurface,
);

/// Material's roles on the app's type scale (AppTypeScale): every title role
/// is "title", the smaller titles and button text "headline", body "body",
/// small text "caption".
TextTheme _textTheme(ColorScheme scheme) {
  final title = AppTypeScale.title.copyWith(color: scheme.onSurface);
  final headline = AppTypeScale.headline.copyWith(color: scheme.onSurface);
  final body = AppTypeScale.body.copyWith(color: scheme.onSurface);
  final label = AppTypeScale.label.copyWith(color: scheme.onSurface);
  final caption = AppTypeScale.caption.copyWith(color: scheme.onSurfaceVariant);
  return TextTheme(
    displayLarge: title,
    displayMedium: title,
    displaySmall: title,
    headlineLarge: title,
    headlineMedium: title,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: headline,
    titleSmall: headline,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: headline,
    labelMedium: label,
    labelSmall: caption,
  );
}

ThemeData _buildTheme(ColorScheme scheme, AppPalette palette) {
  final text = _textTheme(scheme);
  final line = BorderSide(color: scheme.outlineVariant, width: AppSize.line);
  const pill = StadiumBorder();
  const buttonSize = Size(AppSize.touch, AppSize.touch);
  const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpace.xl);
  OutlineInputBorder field(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.imageAll,
    borderSide: BorderSide(color: color, width: AppSize.line),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    extensions: [palette],
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    fontFamily: AppFonts.body,
    textTheme: text,
    iconTheme: IconThemeData(color: scheme.onSurface, size: AppSize.icon),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: AppSize.line,
      space: AppSize.line,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.panel,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.l,
        vertical: AppSpace.m,
      ),
      labelStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => text.bodySmall!.copyWith(
          color: states.contains(WidgetState.error)
              ? scheme.error
              : states.contains(WidgetState.focused)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      helperStyle: text.bodySmall,
      hintStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      errorStyle: text.bodySmall!.copyWith(color: scheme.error),
      suffixStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      prefixStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      counterStyle: text.bodySmall,
      border: field(scheme.outlineVariant),
      enabledBorder: field(scheme.outlineVariant),
      disabledBorder: field(scheme.outlineVariant),
      // Focus is shown in the text colour: the accent is for actions.
      focusedBorder: field(scheme.onSurface),
      errorBorder: field(scheme.error),
      focusedErrorBorder: field(scheme.error),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: palette.panel,
        disabledForegroundColor: palette.disabled,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: pill,
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: palette.disabled,
        side: line,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: pill,
        textStyle: text.labelLarge,
      ),
    ),
    // Text buttons and links are in the text colour; the accent is for the
    // primary action only.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: palette.disabled,
        minimumSize: buttonSize,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
        shape: pill,
        textStyle: text.labelLarge!.copyWith(
          decoration: TextDecoration.underline,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: buttonSize,
        shape: pill,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        selectedForegroundColor: scheme.surface,
        selectedBackgroundColor: scheme.onSurface,
        side: line,
        minimumSize: buttonSize,
        shape: pill,
        textStyle: text.labelMedium,
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: text.bodyLarge,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.imageAll, side: line),
        ),
      ),
    ),
    // Cards have no frame: space and the photo separate them.
    cardTheme: CardThemeData(
      color: palette.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium!.copyWith(
        color: scheme.onInverseSurface,
      ),
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpace.edge),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    // Bottom panels are the one place with a shadow.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      modalBarrierColor: AppColors.scrim,
      elevation: AppSpace.s,
      modalElevation: AppSpace.s,
      shadowColor: AppColors.scrim,
      showDragHandle: true,
      dragHandleColor: scheme.outlineVariant,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      barrierColor: AppColors.scrim,
      elevation: 0,
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: scheme.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      headerBackgroundColor: scheme.surface,
      headerForegroundColor: scheme.onSurface,
      dividerColor: scheme.outlineVariant,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: scheme.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      hourMinuteShape: const RoundedRectangleBorder(
        borderRadius: AppRadius.imageAll,
      ),
      dayPeriodShape: const RoundedRectangleBorder(
        borderRadius: AppRadius.imageAll,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.onSurface,
      linearTrackColor: scheme.outlineVariant,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.surface
            : scheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onSurface
            : palette.panel,
      ),
      trackOutlineColor: WidgetStatePropertyAll(scheme.outlineVariant),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
      minTileHeight: AppSize.touch,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: text.bodySmall!.copyWith(color: scheme.onInverseSurface),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: AppRadius.imageAll,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.onSurface,
      selectionHandleColor: scheme.onSurface,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}
