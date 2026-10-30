import 'package:flutter/material.dart';

/// CentsGo brand: warm orange, cream paper, deep charcoal ink.
class Brand {
  static const orange = Color(0xFFEA580C);
  static const orangeDark = Color(0xFFC2410C);
  static const orangeDeep = Color(0xFF9A3412);
  static const ember = Color(0xFF7C2D12);
  static const cream = Color(0xFFFFF1E6);
  static const ink = Color(0xFF1C1410);
  static const clay = Color(0xFF6B5B50);

  static const good = Color(0xFF178A4C);
  static const warn = Color(0xFFD08A0B);
  static const bad = Color(0xFFC0392B);
}

class AppFonts {
  static const body = 'Jakarta';
  static const display = 'Display';
  static const mono = 'Mono';
}

enum AppThemeMode { system, light, dark, amoled }

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.muted,
    required this.brand,
    required this.brandSoft,
    required this.brandOn,
    required this.good,
    required this.warn,
    required this.bad,
    required this.shadow,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color muted;
  final Color brand;
  final Color brandSoft;

  /// Foreground colour on top of [brand] (white in light theme, near-black in
  /// dark themes where the accent is light orange).
  final Color brandOn;
  final Color good;
  final Color warn;
  final Color bad;
  final Color shadow;

  Color get slate => Brand.clay;
  Color get greenSoft => good.withValues(alpha: 0.12);
  Color get amberSoft => warn.withValues(alpha: 0.12);

  static const light = AppPalette(
    bg: Color(0xFFFFFBF8),
    surface: Colors.white,
    surfaceAlt: Color(0xFFFAF3EE),
    border: Color(0xFFF0E2D8),
    ink: Brand.ink,
    muted: Color(0xFF85736A),
    brand: Brand.orange,
    brandSoft: Color(0xFFFFEEE2),
    brandOn: Colors.white,
    good: Brand.good,
    warn: Brand.warn,
    bad: Brand.bad,
    shadow: Color(0x14000000),
  );

  static const dark = AppPalette(
    bg: Color(0xFF14100D),
    surface: Color(0xFF1E1814),
    surfaceAlt: Color(0xFF29211B),
    border: Color(0xFF3A2E26),
    ink: Color(0xFFFBF5F0),
    muted: Color(0xFFB5A79C),
    brand: Color(0xFFFF9159),
    brandSoft: Color(0xFF3A2317),
    brandOn: Color(0xFF2A1305),
    good: Color(0xFF52D08D),
    warn: Color(0xFFFFC46B),
    bad: Color(0xFFFF8078),
    shadow: Color(0x33000000),
  );

  static const amoled = AppPalette(
    bg: Colors.black,
    surface: Color(0xFF0B0906),
    surfaceAlt: Color(0xFF16110C),
    border: Color(0xFF271E17),
    ink: Color(0xFFFDF8F3),
    muted: Color(0xFF9E9088),
    brand: Color(0xFFFFA26B),
    brandSoft: Color(0xFF2A170C),
    brandOn: Color(0xFF2A1305),
    good: Color(0xFF57DB95),
    warn: Color(0xFFFFCB7A),
    bad: Color(0xFFFF8B82),
    shadow: Color(0x66000000),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? ink,
    Color? muted,
    Color? brand,
    Color? brandSoft,
    Color? brandOn,
    Color? good,
    Color? warn,
    Color? bad,
    Color? shadow,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      brandOn: brandOn ?? this.brandOn,
      good: good ?? this.good,
      warn: warn ?? this.warn,
      bad: bad ?? this.bad,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      brandOn: Color.lerp(brandOn, other.brandOn, t)!,
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

ThemeData buildAppTheme(AppThemeMode mode, Brightness platformBrightness) {
  final AppPalette palette;
  switch (mode) {
    case AppThemeMode.light:
      palette = AppPalette.light;
    case AppThemeMode.dark:
      palette = AppPalette.dark;
    case AppThemeMode.amoled:
      palette = AppPalette.amoled;
    case AppThemeMode.system:
      palette = platformBrightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  }
  final isDark = palette.bg.computeLuminance() < 0.4;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.orange,
    brightness: isDark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: palette.brand,
    onPrimary: palette.brandOn,
    secondary: Brand.orangeDeep,
    surface: palette.surface,
    onSurface: palette.ink,
    error: palette.bad,
    outline: palette.border,
  );

  const base = AppFonts.body;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    fontFamily: base,
    splashFactory: InkSparkle.splashFactory,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: palette.ink,
      titleTextStyle: TextStyle(
        fontFamily: base,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: 0.1,
        color: palette.ink,
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: palette.muted, fontWeight: FontWeight.w400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.brand, width: 1.6),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.brand,
        foregroundColor: palette.brandOn,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontFamily: base, fontWeight: FontWeight.w700, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.brand),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.brandOn : palette.surfaceAlt,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.brand : palette.border,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(color: palette.bg, fontFamily: base),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.brand,
      textColor: palette.ink,
    ),
  );
}

/// Display typography for screen titles and section headers.
TextStyle displayStyle(AppPalette p, {double size = 30, Color? color}) => TextStyle(
      fontFamily: AppFonts.display,
      fontSize: size,
      height: 1.05,
      letterSpacing: -0.2,
      color: color ?? p.ink,
    );

/// Prices use a monospaced face so digits line up like a station price board.
class Money {
  static TextStyle style(AppPalette p, {double size = 22, Color? color, FontWeight weight = FontWeight.w600}) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: size,
      fontWeight: weight,
      color: color ?? p.ink,
      letterSpacing: -0.6,
      height: 1.05,
    );
  }
}
