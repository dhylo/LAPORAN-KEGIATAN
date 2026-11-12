import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'mac_tokens.dart';

ThemeData macLightTheme() => _macTheme(
  brightness: Brightness.light,
  accent: MacColors.accent,
  window: MacColors.windowLight,
  sidebar: MacColors.sidebarLight,
  surface: MacColors.surfaceLight,
  separator: MacColors.separatorLight,
  text: MacColors.textLight,
  secondary: MacColors.secondaryLight,
  danger: MacColors.danger,
);

ThemeData macDarkTheme() => _macTheme(
  brightness: Brightness.dark,
  accent: MacColors.accentDark,
  window: MacColors.windowDark,
  sidebar: MacColors.sidebarDark,
  surface: MacColors.surfaceDark,
  separator: MacColors.separatorDark,
  text: MacColors.textDark,
  secondary: MacColors.secondaryDark,
  danger: MacColors.dangerDark,
);

ThemeData _macTheme({
  required Brightness brightness,
  required Color accent,
  required Color window,
  required Color sidebar,
  required Color surface,
  required Color separator,
  required Color text,
  required Color secondary,
  required Color danger,
}) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: Colors.white,
    primaryContainer: accent.withValues(alpha: 0.14),
    onPrimaryContainer: accent,
    secondary: accent,
    onSecondary: Colors.white,
    secondaryContainer: accent.withValues(alpha: 0.14),
    onSecondaryContainer: accent,
    error: danger,
    onError: Colors.white,
    surface: surface,
    onSurface: text,
    surfaceContainerHighest: brightness == Brightness.light
        ? const Color(0xFFF2F2F4)
        : const Color(0xFF343436),
    onSurfaceVariant: secondary,
    outline: separator,
    outlineVariant: separator,
    shadow: Colors.black.withValues(alpha: 0.12),
    scrim: Colors.black.withValues(alpha: 0.35),
    inverseSurface: text,
    onInverseSurface: surface,
    inversePrimary: accent,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: window,
    canvasColor: window,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: surface,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MacMetrics.cardRadius),
        side: BorderSide(color: separator),
      ),
    ),
    dividerTheme: DividerThemeData(color: separator, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? const Color(0xFFF2F2F4)
          : const Color(0xFF343436),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
      labelStyle: TextStyle(color: secondary, fontSize: 12),
      hintStyle: TextStyle(color: secondary, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, MacMetrics.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, MacMetrics.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(color: separator),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, MacMetrics.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: const EdgeInsets.all(7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
      ),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      minVerticalPadding: 4,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.light
          ? const Color(0xDD1D1D1F)
          : const Color(0xDDF5F5F7),
      contentTextStyle: TextStyle(
        color: brightness == Brightness.light ? Colors.white : Colors.black,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MacMetrics.radius),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: separator),
      ),
      titleTextStyle: TextStyle(
        color: text,
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.12),
    ),
  );
}
