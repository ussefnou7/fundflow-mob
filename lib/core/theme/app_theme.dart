import 'package:flutter/material.dart';

enum FundFlowBrand {
  evergreen,
  navy,
  petrol,
  graphite,
  indigo,
  teal,
  olive,
  pink,
  burgundy;

  factory FundFlowBrand.fromApi(String? value) {
    return FundFlowBrand.values.firstWhere(
      (theme) => theme.name.toUpperCase() == value,
      orElse: () => FundFlowBrand.evergreen,
    );
  }
}

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brand,
    required this.brandStrong,
    required this.brandFocus,
    required this.brandTint,
    required this.canvas,
    required this.line,
    required this.muted,
    required this.ink,
  });

  final Color brand;
  final Color brandStrong;
  final Color brandFocus;
  final Color brandTint;
  final Color canvas;
  final Color line;
  final Color muted;
  final Color ink;

  static const success = Color(0xFF2C8055);
  static const successTint = Color(0xFFE8F6EF);
  static const warning = Color(0xFFD68C28);
  static const warningTint = Color(0xFFFFF8ED);
  static const danger = Color(0xFFB42318);
  static const dangerTint = Color(0xFFFDEDEC);
  static const info = Color(0xFF52647C);
  static const infoTint = Color(0xFFE9F0FA);
  static const lockedField = Color(0xFFE2E8E5);
  static const lockedFieldBorder = Color(0xFFB8C8C3);
  // Snag is a manager-only marker, so it gets its own light orange, never the brand.
  static const snag = Color(0xFFB45309);
  static const snagTint = Color(0xFFFFF1E2);

  static AppTokens forBrand(FundFlowBrand theme) => switch (theme) {
    FundFlowBrand.evergreen => const AppTokens(
      brand: Color(0xFF1C5A4C),
      brandStrong: Color(0xFF173E36),
      brandFocus: Color(0xFF6D8B74),
      brandTint: Color(0xFFC7E2D3),
      canvas: Color(0xFFF9FBF8),
      line: Color(0xFFE5EBE4),
      muted: Color(0xFF53655C),
      ink: Color(0xFF273F3B),
    ),
    FundFlowBrand.navy => const AppTokens(
      brand: Color(0xFF334E77),
      brandStrong: Color(0xFF253751),
      brandFocus: Color(0xFF6A85A4),
      brandTint: Color(0xFFC9DCF5),
      canvas: Color(0xFFF9FAFC),
      line: Color(0xFFE6E9ED),
      muted: Color(0xFF5A6169),
      ink: Color(0xFF333A43),
    ),
    FundFlowBrand.petrol => const AppTokens(
      brand: Color(0xFF185666),
      brandStrong: Color(0xFF163C46),
      brandFocus: Color(0xFF5F8B93),
      brandTint: Color(0xFFC1E1E8),
      canvas: Color(0xFFF8FAFB),
      line: Color(0xFFE5EAEC),
      muted: Color(0xFF586266),
      ink: Color(0xFF303C40),
    ),
    FundFlowBrand.graphite => const AppTokens(
      brand: Color(0xFF474E5B),
      brandStrong: Color(0xFF31363F),
      brandFocus: Color(0xFF7C838D),
      brandTint: Color(0xFFD6DBE3),
      canvas: Color(0xFFFAFAFB),
      line: Color(0xFFE8E9EB),
      muted: Color(0xFF5E6064),
      ink: Color(0xFF373A3E),
    ),
    FundFlowBrand.indigo => const AppTokens(
      brand: Color(0xFF4A4874),
      brandStrong: Color(0xFF33324F),
      brandFocus: Color(0xFF7B7FA3),
      brandTint: Color(0xFFD6D8F4),
      canvas: Color(0xFFFAFAFB),
      line: Color(0xFFE8E8EC),
      muted: Color(0xFF5E5F68),
      ink: Color(0xFF383942),
    ),
    FundFlowBrand.teal => const AppTokens(
      brand: Color(0xFF005A5A),
      brandStrong: Color(0xFF0C3E3E),
      brandFocus: Color(0xFF5C8D88),
      brandTint: Color(0xFFBFE3E0),
      canvas: Color(0xFFF8FBFA),
      line: Color(0xFFE4EAEA),
      muted: Color(0xFF566363),
      ink: Color(0xFF2F3D3D),
    ),
    FundFlowBrand.olive => const AppTokens(
      brand: Color(0xFF46542A),
      brandStrong: Color(0xFF313A1F),
      brandFocus: Color(0xFF808765),
      brandTint: Color(0xFFD7DEC5),
      canvas: Color(0xFFFAFAF8),
      line: Color(0xFFE9E9E4),
      muted: Color(0xFF606155),
      ink: Color(0xFF3A3B2E),
    ),
    FundFlowBrand.pink => const AppTokens(
      brand: Color(0xFFB8497C),
      brandStrong: Color(0xFF914766),
      brandFocus: Color(0xFFD582A8),
      brandTint: Color(0xFFFFCEE9),
      canvas: Color(0xFFFBFAFA),
      line: Color(0xFFECE7E9),
      muted: Color(0xFF665D60),
      ink: Color(0xFF40373A),
    ),
    FundFlowBrand.burgundy => const AppTokens(
      brand: Color(0xFF733944),
      brandStrong: Color(0xFF4F292F),
      brandFocus: Color(0xFFA3737C),
      brandTint: Color(0xFFF6CFD5),
      canvas: Color(0xFFFBFAFA),
      line: Color(0xFFEBE8E8),
      muted: Color(0xFF655E5E),
      ink: Color(0xFF3F3837),
    ),
  };

  @override
  AppTokens copyWith({
    Color? brand,
    Color? brandStrong,
    Color? brandFocus,
    Color? brandTint,
    Color? canvas,
    Color? line,
    Color? muted,
    Color? ink,
  }) => AppTokens(
    brand: brand ?? this.brand,
    brandStrong: brandStrong ?? this.brandStrong,
    brandFocus: brandFocus ?? this.brandFocus,
    brandTint: brandTint ?? this.brandTint,
    canvas: canvas ?? this.canvas,
    line: line ?? this.line,
    muted: muted ?? this.muted,
    ink: ink ?? this.ink,
  );

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandFocus: Color.lerp(brandFocus, other.brandFocus, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      line: Color.lerp(line, other.line, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

/// Surfaces derived from the brand, so every one of the nine identities keeps the same depth.
extension AppTokenShades on AppTokens {
  Color get wash =>
      Color.alphaBlend(brand.withValues(alpha: .08), Colors.white);
  Color get washStrong =>
      Color.alphaBlend(brand.withValues(alpha: .15), Colors.white);
  Color get sunken =>
      Color.alphaBlend(ink.withValues(alpha: .025), Colors.white);
  Color get faint =>
      Color.alphaBlend(muted.withValues(alpha: .7), Colors.white);
  Color get brandDeep =>
      Color.alphaBlend(Colors.black.withValues(alpha: .22), brandStrong);
}

/// Shared motion language. Keep movement unless the user requests reduced motion.
abstract final class AppMotion {
  static const feedback = Duration(milliseconds: 160);
  static const expand = Duration(milliseconds: 180);
  static const enter = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;

  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 18.0;
}

class AppColors {
  const AppColors._();
  static const petrolDark = Color(0xFF173E36);
  static const petrol = Color(0xFF1C5A4C);
  static const petrolFocus = Color(0xFF6D8B74);
  static const canvas = Color(0xFFF9FBF8);
  static const line = Color(0xFFE5EBE4);
  static const muted = Color(0xFF53655C);
  static const danger = AppTokens.danger;
  static const dangerLight = AppTokens.dangerTint;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light([FundFlowBrand brand = FundFlowBrand.evergreen]) {
    final tokens = AppTokens.forBrand(brand);
    final scheme = ColorScheme.fromSeed(
      seedColor: tokens.brand,
      primary: tokens.brand,
      surface: Colors.white,
      error: AppTokens.danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.canvas,
      fontFamily: 'Cairo',
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.brandStrong,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: 16, height: 1.65, color: tokens.ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.6, color: tokens.ink),
        titleLarge: TextStyle(
          fontSize: 23,
          height: 1.6,
          fontWeight: FontWeight.w700,
          color: tokens.brandStrong,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: tokens.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: tokens.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: Colors.white,
          elevation: 2.5,
          shadowColor: tokens.brandStrong.withValues(alpha: .24),
          minimumSize: const Size(96, 46),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.brandFocus, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppTokens.danger, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: tokens.brandTint,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
