import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Semantic colour tokens. Widgets read these via `context.colors` instead of
/// hard-coding `Colors.white` / hex values, so light and dark stay in sync.
@immutable
class AppColors extends ThemeExtension<AppColors>
{
  const AppColors({
    required this.brand,
    required this.brandStrong,
    required this.onBrand,
    required this.brandSurface,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.positive,
    required this.negative,
    required this.danger,
    required this.onDanger,
    required this.dangerSurface,
    required this.dangerBorder,
    required this.cardGradientStart,
    required this.cardGradientEnd,
    required this.heroStart,
    required this.heroEnd,
    required this.shadow,
  });

  final Color brand;
  final Color brandStrong;
  final Color onBrand;

  /// Tinted fill behind brand-coloured icons and chips.
  final Color brandSurface;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Money in / money out.
  final Color positive;
  final Color negative;
  final Color danger;

  /// Text/icons on [danger] fills (destructive buttons, badges).
  final Color onDanger;
  final Color dangerSurface;
  final Color dangerBorder;
  final Color cardGradientStart;
  final Color cardGradientEnd;

  /// Brand-filled panels that carry white text (hero totals, badges). Darker
  /// than [brand] in dark mode, where [brand] is tuned for text on dark.
  final Color heroStart;
  final Color heroEnd;
  final Color shadow;

  static const light = AppColors(
    brand: Color(lightForestGreenColor),
    brandStrong: Color(darkForestGreenColor),
    onBrand: Colors.white,
    brandSurface: Color(0x1A00695C),
    background: Color(0xFFF5F7FA),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF1F5F3),
    border: Color(0xFFE5E7EB),
    textPrimary: Color(darkGreyColor),
    // Text colours meet WCAG AA (4.5:1) on surface, background and surfaceMuted.
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF5F6775),
    positive: Color(lightForestGreenColor),
    negative: Color(0xFFC62828),
    danger: Color(0xFFC62828),
    onDanger: Colors.white,
    dangerSurface: Color(0xFFFFEBEE),
    dangerBorder: Color(0xFFEF9A9A),
    cardGradientStart: Color(0xFF00796B),
    cardGradientEnd: Color(0xFF005F52),
    heroStart: Color(lightForestGreenColor),
    heroEnd: Color(darkForestGreenColor),
    shadow: Color(0x0F000000),
  );

  static const dark = AppColors(
    brand: Color(0xFF4DB6AC),
    brandStrong: Color(0xFF80CBC4),
    onBrand: Color(0xFF0B0F17),
    brandSurface: Color(0x264DB6AC),
    background: Color(0xFF0B0F17),
    surface: Color(0xFF151C28),
    surfaceMuted: Color(0xFF1E2633),
    border: Color(0xFF233044),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFFB4BCCB),
    textMuted: Color(0xFF98A1B3),
    positive: Color(0xFF4DB6AC),
    negative: Color(0xFFF26B6B),
    danger: Color(0xFFF26B6B),
    onDanger: Color(0xFF1A0B0B),
    dangerSurface: Color(0xFF3A1D1F),
    dangerBorder: Color(0xFF7F2E31),
    cardGradientStart: Color(0xFF00796B),
    cardGradientEnd: Color(0xFF005F52),
    heroStart: Color(0xFF00796B),
    heroEnd: Color(0xFF004D40),
    shadow: Color(0x66000000),
  );

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandStrong,
    Color? onBrand,
    Color? brandSurface,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? positive,
    Color? negative,
    Color? danger,
    Color? onDanger,
    Color? dangerSurface,
    Color? dangerBorder,
    Color? cardGradientStart,
    Color? cardGradientEnd,
    Color? heroStart,
    Color? heroEnd,
    Color? shadow,
  })
  {
    return AppColors(
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      onBrand: onBrand ?? this.onBrand,
      brandSurface: brandSurface ?? this.brandSurface,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      cardGradientStart: cardGradientStart ?? this.cardGradientStart,
      cardGradientEnd: cardGradientEnd ?? this.cardGradientEnd,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t)
  {
    if(other is! AppColors) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      cardGradientStart: Color.lerp(cardGradientStart, other.cardGradientStart, t)!,
      cardGradientEnd: Color.lerp(cardGradientEnd, other.cardGradientEnd, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// 4-point spacing scale.
abstract final class AppSpacing
{
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter used by most screens.
  static const double gutter = 24;
}

abstract final class AppRadii
{
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double sheet = 28;
}

/// Minimum touch target (Material / WCAG guidance).
const double kMinTapTarget = 48;

extension AppThemeContext on BuildContext
{
  /// Colour tokens for the current theme; falls back to light when a widget is
  /// built outside the app theme (e.g. in isolated tests).
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;

  TextTheme get text => Theme.of(this).textTheme;
}
