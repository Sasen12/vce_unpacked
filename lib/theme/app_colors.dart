import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color surfaceBg;
  final Color cardBg;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color statsBg;

  const AppColors({
    required this.surfaceBg,
    required this.cardBg,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.statsBg,
  });

  // Palette values are Apple's system colors — the same ones the rest of
  // the app's macOS-native design language borrows (F5F5F7 group
  // background, white card, E5E5EA separator, 1C1C1E label text, 8E8E93
  // secondary text), so the app reads as built with the platform palette
  // rather than a hand-picked substitute.
  static const light = AppColors(
    surfaceBg: Color(0xFFF5F5F7),
    cardBg: Colors.white,
    border: Color(0xFFE5E5EA),
    borderStrong: Color(0xFFD1D1D6),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF8E8E93),
    statsBg: Color(0xFFF2F2F7),
  );

  // Dark mode mirrors the same roles with the standard dark-system
  // equivalents (pure-black surface, #1C1C1E card, brighter borders).
  static const dark = AppColors(
    surfaceBg: Color(0xFF000000),
    cardBg: Color(0xFF1C1C1E),
    border: Color(0xFF38383A),
    borderStrong: Color(0xFF48484A),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF8E8E93),
    statsBg: Color(0xFF2C2C2E),
  );

  @override
  AppColors copyWith({
    Color? surfaceBg,
    Color? cardBg,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? statsBg,
  }) {
    return AppColors(
      surfaceBg: surfaceBg ?? this.surfaceBg,
      cardBg: cardBg ?? this.cardBg,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      statsBg: statsBg ?? this.statsBg,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surfaceBg: Color.lerp(surfaceBg, other.surfaceBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      statsBg: Color.lerp(statsBg, other.statsBg, t)!,
    );
  }
}

extension AppColorsBuildContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  Color get surfaceBg => appColors.surfaceBg;
  Color get cardBg => appColors.cardBg;
  Color get border => appColors.border;
  Color get borderStrong => appColors.borderStrong;
  Color get textPrimary => appColors.textPrimary;
  Color get textSecondary => appColors.textSecondary;
  Color get statsBg => appColors.statsBg;
}
