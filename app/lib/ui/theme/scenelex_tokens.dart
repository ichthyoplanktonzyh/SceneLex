/// SceneLex v1 design tokens — the single source of the product visual
/// system (see docs/product-v1-app.md §9 for the rationale).
///
/// Not a Material-from-seed patchwork: these tokens ARE the product design.
/// Pages consume tokens via the [SceneLexTheme] extension; raw literal colors
/// outside this file are a code smell.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Core color tokens (4–6 core roles)
// ---------------------------------------------------------------------------

/// Action / check-in / concept-formation warm signal (prototype primary orange).
const Color kColorEmber = Color(0xFFF2701C);

/// Symbol Binding / Grounding teal signal (dark + bright variants).
const Color kColorTealSignal = Color(0xFF0F766E);
const Color kColorTealSignalBright = Color(0xFF0FB99B);

/// Ink: primary text.
const Color kColorInk = Color(0xFF1E1E24);

/// Paper: light page background (learning/content pages).
const Color kColorPaper = Color(0xFFF4F4F6);

/// Dusk: dark emphasis, L2 mode pill, home text.
const Color kColorDusk = Color(0xFF2C2C34);

/// Starry night gradient for the home sky (the visual signature).
const List<Color> kHomeNightGradient = [
  Color(0xFF23232B),
  Color(0xFF0E0E12),
  Color(0xFF08080B),
];

/// Home sky dusk tones (aurora band + hills).
const Color kHomeAuroraTop = Color(0xFFF3C078);
const Color kHomeAuroraMid = Color(0xFFCFC7E6);
const Color kHomeAuroraBottom = Color(0xFFEEC9D8);
const Color kHomeHill = Color(0xFFF0DCEE);
const Color kHomeSpark = Color(0xFFFFF8E0);

// Semantic signals
const Color kSignalSuccess = Color(0xFF0C7A63);
const Color kSignalSuccessBg = Color(0x3D18B796);
const Color kSignalError = Color(0xFFC22B3B);
const Color kSignalErrorBg = Color(0x33F04856);
const Color kSignalCorrectBorder = Color(0x8C14AA8C);
const Color kSignalWrongBorder = Color(0x73E64654);
const Color kSignalWarn = Color(0xFFB7761C);
const Color kSignalWarnBg = Color(0xFFFFF7EC);

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

class SceneLexText extends ThemeExtension<SceneLexText> {
  const SceneLexText({
    required this.kicker,
    required this.statNumber,
    required this.symbolWord,
  });

  /// Uppercase micro-label (stage labels, block labels).
  final TextStyle kicker;

  /// Large statistic numbers.
  final TextStyle statNumber;

  /// The revealed L2 word (Binding / review answer).
  final TextStyle symbolWord;

  @override
  SceneLexText copyWith({
    TextStyle? kicker,
    TextStyle? statNumber,
    TextStyle? symbolWord,
  }) => SceneLexText(
    kicker: kicker ?? this.kicker,
    statNumber: statNumber ?? this.statNumber,
    symbolWord: symbolWord ?? this.symbolWord,
  );

  @override
  SceneLexText lerp(SceneLexText? other, double t) {
    if (other == null) return this;
    return SceneLexText(
      kicker: TextStyle.lerp(kicker, other.kicker, t)!,
      statNumber: TextStyle.lerp(statNumber, other.statNumber, t)!,
      symbolWord: TextStyle.lerp(symbolWord, other.symbolWord, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// Spacing scale
// ---------------------------------------------------------------------------

const double kSpaceXs = 4;
const double kSpaceSm = 8;
const double kSpaceMd = 12;
const double kSpaceLg = 16;
const double kSpaceXl = 20;
const double kSpace2xl = 24;
const double kSpace3xl = 32;

// ---------------------------------------------------------------------------
// Radius
// ---------------------------------------------------------------------------

const double kRadiusSm = 11;
const double kRadiusMd = 13;
const double kRadiusLg = 16;
const double kRadiusCard = 18;
const double kRadiusPill = 26;

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/// Max reading width for content columns.
const double kContentMaxWidth = 720;

/// NavigationRail breakpoint.
const double kBreakpointTablet = 600;

// ---------------------------------------------------------------------------
// Motion timings (per docs/product-v1-app.md §9)
// ---------------------------------------------------------------------------

const Duration kMotionPress = Duration(milliseconds: 120);
const Duration kMotionFeedback = Duration(milliseconds: 220);
const Duration kMotionPage = Duration(milliseconds: 380);
const Duration kMotionReveal = Duration(milliseconds: 450);
const Duration kMotionSheet = Duration(milliseconds: 380);

/// Uniform non-linear ease used across product transitions.
const Curve kMotionCurve = Curves.easeOutCubic;

/// The reveal curve (gentle rise).
const Curve kMotionRise = Cubic(0.2, 0.9, 0.3, 1.0);

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

/// Build the SceneLex light theme (the product is light-first; home/sky
/// surfaces are intentionally dark but scoped to their surfaces).
ThemeData buildSceneLexTheme({bool dark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kColorEmber,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: kColorEmber,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kColorPaper,
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: kColorInk,
    displayColor: kColorInk,
  );

  final sceneLexText = SceneLexText(
    kicker: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      color: Color(0xFF8B8B96),
    ),
    statNumber: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: kColorInk,
      height: 1.1,
    ),
    symbolWord: const TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
      color: Color(0xFF131318),
      height: 1.1,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    extensions: [sceneLexText],
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: kColorEmber.withValues(alpha: 0.16),
      elevation: 0,
      height: 64,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kColorEmber,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFF1F1F4),
      thickness: 1,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: kColorDusk,
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
    ),
  );
}
