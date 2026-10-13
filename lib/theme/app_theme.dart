import 'package:flutter/material.dart';

import '../services/attendance_math.dart';
import 'tokens.dart';

/// Colours the Material scheme doesn't cover.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.line,
    required this.track,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.edge,
    required this.navBg,
    required this.inverse,
    required this.onInverse,
  });

  final Color bg, surface, text, muted, line, track;
  final Color accent, onAccent, danger, edge, navBg;

  /// Ink in light mode, near-white in dark (selected day, primary buttons).
  final Color inverse, onInverse;

  /// Colour for a risk level (rings, small text).
  Color risk(Risk r) => switch (r) {
    Risk.safe => accent,
    Risk.edge => edge,
    Risk.danger => danger,
  };

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  static AppColors light(Color accent) => AppColors(
    bg: const Color(0xFFF5F6F8),
    surface: Colors.white,
    text: Moment.ink,
    muted: const Color(0xFF5A606C),
    line: const Color(0xFFE5E7EB),
    track: const Color(0xFFE9EBEF),
    accent: accent,
    onAccent: Colors.white,
    danger: const Color(0xFFC2410C),
    edge: const Color(0xFF9A6700),
    navBg: const Color(0xFFF5F6F8),
    inverse: Moment.ink,
    onInverse: Colors.white,
  );

  static AppColors dark(Color accent) => AppColors(
    bg: const Color(0xFF0D0E11),
    surface: const Color(0xFF16181C),
    text: const Color(0xFFF1F2F4),
    muted: const Color(0xFFA3A9B4),
    line: const Color(0xFF25282E),
    track: const Color(0xFF24272D),
    accent: accent,
    onAccent: const Color(0xFF0D0E11),
    danger: const Color(0xFFFF8B52),
    edge: const Color(0xFFE4B551),
    navBg: const Color(0xFF0D0E11),
    inverse: const Color(0xFFF1F2F4),
    onInverse: const Color(0xFF0D0E11),
  );

  // Value equality: without it every rebuilt theme looks "new" and
  // MaterialApp animates a whole-app theme change for 400 ms.
  @override
  bool operator ==(Object other) =>
      other is AppColors &&
      other.bg == bg &&
      other.surface == surface &&
      other.text == text &&
      other.muted == muted &&
      other.line == line &&
      other.track == track &&
      other.accent == accent &&
      other.onAccent == onAccent &&
      other.danger == danger &&
      other.edge == edge &&
      other.navBg == navBg &&
      other.inverse == inverse &&
      other.onInverse == onInverse;

  @override
  int get hashCode => Object.hash(
    bg,
    surface,
    text,
    muted,
    line,
    track,
    accent,
    onAccent,
    danger,
    edge,
    navBg,
    inverse,
    onInverse,
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      track: l(track, other.track),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      danger: l(danger, other.danger),
      edge: l(edge, other.edge),
      navBg: l(navBg, other.navBg),
      inverse: l(inverse, other.inverse),
      onInverse: l(onInverse, other.onInverse),
    );
  }
}

/// Bricolage display type for numbers, codes and "moment" copy.
TextStyle display(
  double size, {
  Color? color,
  double weight = 800,
  double? height,
}) => TextStyle(
  fontFamily: Fonts.display,
  fontSize: size,
  fontWeight: weight >= 700 ? FontWeight.w800 : FontWeight.w600,
  fontVariations: [
    FontVariation('wght', weight),
    FontVariation('opsz', size.clamp(12, 96)),
  ],
  letterSpacing: -0.03 * size,
  height: height ?? 1.0,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Geist body text with a real variable weight.
TextStyle body(
  double size, {
  Color? color,
  double weight = 400,
  double? height,
}) => TextStyle(
  fontFamily: Fonts.body,
  fontSize: size,
  fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
  fontVariations: [FontVariation('wght', weight)],
  height: height,
  color: color,
);

final _themes = <(Brightness, int), ThemeData>{};

/// The theme for a brightness and accent, built once and reused (building
/// one, including `ColorScheme.fromSeed`, takes milliseconds).
ThemeData themeFor(Brightness brightness, int accentIndex) =>
    _themes[(brightness, accentIndex)] ??= buildTheme(brightness, accentIndex);

ThemeData buildTheme(Brightness brightness, int accentIndex) {
  final dark = brightness == Brightness.dark;
  final accent = dark
      ? accentChoices[accentIndex].$3
      : accentChoices[accentIndex].$2;
  final c = dark ? AppColors.dark(accent) : AppColors.light(accent);

  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: c.accent,
        onPrimary: c.onAccent,
        surface: c.bg,
        onSurface: c.text,
        onSurfaceVariant: c.muted,
        outline: c.line,
        outlineVariant: c.line,
        error: c.danger,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surface,
        surfaceContainerHighest: c.track,
      );

  TextStyle t(double size, double weight, [double? height]) =>
      body(size, color: c.text, weight: weight, height: height);

  final textTheme = TextTheme(
    displayLarge: display(56, color: c.text),
    displayMedium: display(44, color: c.text),
    displaySmall: display(34, color: c.text),
    headlineLarge: t(34, 700, 1.1).copyWith(letterSpacing: -0.9),
    headlineMedium: t(26, 600, 1.15).copyWith(letterSpacing: -0.4),
    headlineSmall: t(22, 600, 1.2),
    titleLarge: t(19, 600, 1.25),
    titleMedium: t(16, 600, 1.3),
    titleSmall: t(14, 600, 1.3),
    bodyLarge: t(16, 400, 1.45),
    bodyMedium: t(15, 400, 1.4),
    bodySmall: t(13, 400, 1.35).copyWith(color: c.muted),
    labelLarge: t(15, 600),
    labelMedium: t(13, 500),
    labelSmall: t(12, 500).copyWith(color: c.muted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: Fonts.body,
    textTheme: textTheme,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: t(17, 600),
      foregroundColor: c.text,
    ),
    // The iOS back chevron on every platform.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) =>
          const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: body(15, color: c.muted),
      floatingLabelStyle: body(14, color: c.accent, weight: 500),
      helperStyle: body(13, color: c.muted),
      errorStyle: body(13, color: c.danger, weight: 500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: c.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: c.danger, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.inverse,
        foregroundColor: c.onInverse,
        minimumSize: const Size(64, 52),
        textStyle: body(16, weight: 600),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.m),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: c.line),
        textStyle: body(15, weight: 500),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.m),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        minimumSize: const Size(48, 44),
        textStyle: body(15, weight: 600),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(Radii.l),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverse,
      contentTextStyle: body(15, color: c.onInverse, weight: 500),
      actionTextColor: Moment.lime,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(Radii.m),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.track,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onAccent : c.muted,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.accent,
      inactiveTrackColor: c.track,
      thumbColor: c.accent,
      overlayColor: c.accent.withValues(alpha: 0.12),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: c.muted, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? c.inverse : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(dark ? Moment.ink : Moment.lime),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      // iOS push/pop with edge swipe-back on both platforms.
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
