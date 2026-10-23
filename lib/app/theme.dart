import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// The app's only theme: dark, built from [AppColors] and the other tokens.
/// Deliberately not `ColorScheme.fromSeed`, whose generated tones would not
/// match the palette.
final ThemeData appTheme = _buildTheme();

const _scheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.gold,
  onPrimary: AppColors.onGold,
  primaryContainer: AppColors.stageRaised,
  onPrimaryContainer: AppColors.gold,
  secondary: AppColors.gold,
  onSecondary: AppColors.onGold,
  secondaryContainer: AppColors.stageRaised,
  onSecondaryContainer: AppColors.onStage,
  tertiary: AppColors.success,
  onTertiary: AppColors.stage,
  error: AppColors.urgent,
  onError: AppColors.stage,
  surface: AppColors.stage,
  onSurface: AppColors.onStage,
  onSurfaceVariant: AppColors.onStageMuted,
  surfaceContainerLowest: AppColors.stage,
  surfaceContainerLow: AppColors.stageRaised,
  surfaceContainer: AppColors.stageRaised,
  surfaceContainerHigh: AppColors.stageRaised,
  surfaceContainerHighest: AppColors.stageRaised,
  outline: AppColors.line,
  outlineVariant: AppColors.line,
  shadow: AppColors.stage,
  scrim: AppColors.scrim,
  inverseSurface: AppColors.onStage,
  onInverseSurface: AppColors.stage,
  inversePrimary: AppColors.gold,
  surfaceTint: AppColors.stage,
);

const _lineSide = BorderSide(color: AppColors.line, width: AppSize.line);

TextTheme _textTheme() {
  const display = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w600,
    color: AppColors.onStage,
  );
  const body = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w400,
    color: AppColors.onStage,
  );
  return TextTheme(
    displayLarge: display.copyWith(fontSize: 48, height: 1.1),
    displayMedium: display.copyWith(fontSize: 40, height: 1.1),
    displaySmall: display.copyWith(fontSize: 32, height: 1.15),
    headlineLarge: display.copyWith(fontSize: 30, height: 1.2),
    headlineMedium: display.copyWith(fontSize: 26, height: 1.2),
    headlineSmall: display.copyWith(fontSize: 22, height: 1.25),
    titleLarge: display.copyWith(fontSize: 20, height: 1.25),
    titleMedium: body.copyWith(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: body.copyWith(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: body.copyWith(fontSize: 16, height: 1.45),
    bodyMedium: body.copyWith(fontSize: 14, height: 1.45),
    bodySmall: body.copyWith(
      fontSize: 12,
      height: 1.4,
      color: AppColors.onStageMuted,
    ),
    labelLarge: body.copyWith(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: body.copyWith(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: body.copyWith(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.onStageMuted,
    ),
  );
}

ThemeData _buildTheme() {
  final text = _textTheme();
  const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.smallAll);
  const buttonSize = Size(AppSize.touch, AppSize.touch);
  const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpace.l);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _scheme,
    scaffoldBackgroundColor: AppColors.stage,
    canvasColor: AppColors.stage,
    fontFamily: AppFonts.body,
    textTheme: text,
    iconTheme: const IconThemeData(
      color: AppColors.onStage,
      size: AppSize.icon,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: AppSize.line,
      space: AppSize.line,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.stage,
      foregroundColor: AppColors.onStage,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      shape: const Border(bottom: _lineSide),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.stageRaised,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.l,
        vertical: AppSpace.m,
      ),
      labelStyle: text.bodyLarge!.copyWith(color: AppColors.onStageMuted),
      // Gold only while the field has focus.
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => text.bodyMedium!.copyWith(
          color: states.contains(WidgetState.error)
              ? AppColors.urgent
              : states.contains(WidgetState.focused)
              ? AppColors.gold
              : AppColors.onStageMuted,
        ),
      ),
      helperStyle: text.bodySmall,
      hintStyle: text.bodyLarge!.copyWith(color: AppColors.onStageMuted),
      errorStyle: text.bodySmall!.copyWith(color: AppColors.urgent),
      suffixStyle: text.bodyLarge!.copyWith(color: AppColors.onStageMuted),
      prefixStyle: text.bodyLarge!.copyWith(color: AppColors.onStageMuted),
      counterStyle: text.bodySmall,
      border: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: _lineSide,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: _lineSide,
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: _lineSide,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: BorderSide(color: AppColors.gold, width: AppSize.line),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: BorderSide(color: AppColors.urgent, width: AppSize.line),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.smallAll,
        borderSide: BorderSide(color: AppColors.urgent, width: AppSize.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.onGold,
        // The line colour: still reads as a button on raised panels.
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.onStageMuted,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onStage,
        disabledForegroundColor: AppColors.onStageMuted,
        side: _lineSide,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        disabledForegroundColor: AppColors.onStageMuted,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.onStage,
        minimumSize: buttonSize,
        shape: buttonShape,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: AppColors.onStageMuted,
        // Gold text, not a gold fill: the fill belongs to the primary button.
        selectedForegroundColor: AppColors.gold,
        selectedBackgroundColor: AppColors.line,
        side: _lineSide,
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: text.labelMedium,
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: text.bodyLarge,
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.stageRaised),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: AppRadius.smallAll,
            side: _lineSide,
          ),
        ),
      ),
    ),
    // Cards are flat: a raised colour and a 1 dp line, no shadow.
    cardTheme: const CardThemeData(
      color: AppColors.stageRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeAll,
        side: _lineSide,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.stageRaised,
      contentTextStyle: text.bodyMedium,
      actionTextColor: AppColors.gold,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpace.edge),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.smallAll,
        side: _lineSide,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.stageRaised,
      modalBackgroundColor: AppColors.stageRaised,
      modalBarrierColor: AppColors.scrim,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: AppColors.line,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeTop),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.stageRaised,
      barrierColor: AppColors.scrim,
      elevation: 0,
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.largeAll,
        side: _lineSide,
      ),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.stageRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
      headerBackgroundColor: AppColors.stageRaised,
      headerForegroundColor: AppColors.onStage,
      dividerColor: AppColors.line,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.stageRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
      hourMinuteShape: RoundedRectangleBorder(borderRadius: AppRadius.smallAll),
      dayPeriodShape: RoundedRectangleBorder(borderRadius: AppRadius.smallAll),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
      linearTrackColor: AppColors.line,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.onGold
            : AppColors.onStageMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.gold
            : AppColors.stageRaised,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(AppColors.line),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.onStageMuted,
      textColor: AppColors.onStage,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
      minTileHeight: AppSize.touch,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: text.bodySmall!.copyWith(color: AppColors.onStage),
      decoration: const BoxDecoration(
        color: AppColors.stageRaised,
        borderRadius: AppRadius.smallAll,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.gold,
      selectionHandleColor: AppColors.gold,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}
