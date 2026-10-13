import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design tokens: "calm base, B moments".
///
/// The base (A) is quiet: off-white / near-black grounds, hairlines, one
/// accent. The moments (B) are loud and used sparingly: lime, coral, ink
/// outlines with hard shadows, Bricolage display type, bouncy springs.

/// Moment colours, identical in light and dark.
abstract final class Moment {
  static const ink = Color(0xFF17121F);
  static const lime = Color(0xFFD4FF3F);
  static const coral = Color(0xFFFF6B4A);
  static const sun = Color(0xFFFFD84A);
}

abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const gutter = 20.0;
}

abstract final class Radii {
  static const s = 10.0;
  static const m = 16.0;
  static const l = 22.0;
  static const xl = 28.0;
}

abstract final class Fonts {
  static const body = 'Geist';
  static const display = 'Bricolage';
}

/// Motion: calm transitions for the base, overshooting springs for moments.
abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 560);

  /// Smooth deceleration for fades and slides.
  static const calm = Cubic(0.05, 0.7, 0.1, 1.0);

  /// iOS-style springs. Damping 1 settles without overshoot; lower values
  /// overshoot slightly and settle, never wobble.
  static const spring = SpringCurve(1);
  static const bounce = SpringCurve(0.8);
  static const pop = SpringCurve(0.62);

  /// Honour the OS "reduce motion" setting.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration d(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  static Curve c(BuildContext context, Curve c) =>
      reduced(context) ? Curves.linear : c;
}

/// A damped spring as a [Curve], normalised so it has settled at t = 1.
///
/// Matches how UIKit springs feel: fast start, soft landing, at most one
/// small overshoot.
class SpringCurve extends Curve {
  const SpringCurve(this.damping);

  /// Damping ratio, 0 < damping <= 1.
  final double damping;

  @override
  double transformInternal(double t) {
    // Natural frequency picked so the envelope has decayed to ~0.1% at t = 1.
    final z = damping.clamp(0.05, 1.0);
    final w = 6.9 / z;
    if (z >= 0.999) return 1 - math.exp(-w * t) * (1 + w * t);
    final wd = w * math.sqrt(1 - z * z);
    return 1 -
        math.exp(-z * w * t) *
            (math.cos(wd * t) + (z * w / wd) * math.sin(wd * t));
  }
}

/// A subject colour: a soft fill for cards plus a strong hue for rings/dots.
class SubjectColor {
  const SubjectColor(
    this.name,
    this.lightFill,
    this.lightBorder,
    this.darkFill,
    this.darkBorder,
    this.lightHue,
    this.darkHue,
  );

  final String name;
  final Color lightFill, lightBorder, darkFill, darkBorder, lightHue, darkHue;

  Color fill(Brightness b) => b == Brightness.dark ? darkFill : lightFill;
  Color border(Brightness b) => b == Brightness.dark ? darkBorder : lightBorder;
  Color hue(Brightness b) => b == Brightness.dark ? darkHue : lightHue;
}

const subjectPalette = <SubjectColor>[
  SubjectColor(
    'Violet',
    Color(0xFFEEE8FF),
    Color(0xFFDCD1FF),
    Color(0xFF241E3A),
    Color(0xFF3A3060),
    Color(0xFF7C5CE0),
    Color(0xFFA28BFF),
  ),
  SubjectColor(
    'Apricot',
    Color(0xFFFFECDD),
    Color(0xFFFAD3B3),
    Color(0xFF33231A),
    Color(0xFF57381F),
    Color(0xFFE0782B),
    Color(0xFFFF9E57),
  ),
  SubjectColor(
    'Mint',
    Color(0xFFDDF5EC),
    Color(0xFFB9E9D7),
    Color(0xFF14302A),
    Color(0xFF1E4A40),
    Color(0xFF1F9E89),
    Color(0xFF3CCBB2),
  ),
  SubjectColor(
    'Pink',
    Color(0xFFFFE6F1),
    Color(0xFFF8C9DE),
    Color(0xFF371B2A),
    Color(0xFF5A2B44),
    Color(0xFFD14D8B),
    Color(0xFFF07AB0),
  ),
  SubjectColor(
    'Sky',
    Color(0xFFE3EDFF),
    Color(0xFFC6D8FF),
    Color(0xFF1A2740),
    Color(0xFF2A3F66),
    Color(0xFF2F6FE0),
    Color(0xFF7FA8FF),
  ),
  SubjectColor(
    'Lemon',
    Color(0xFFFFF6CC),
    Color(0xFFF3E39A),
    Color(0xFF33301A),
    Color(0xFF574F22),
    Color(0xFFB08A00),
    Color(0xFFF2D04B),
  ),
  SubjectColor(
    'Rose',
    Color(0xFFFFE5E0),
    Color(0xFFF9C6BC),
    Color(0xFF3A1D19),
    Color(0xFF5E2C25),
    Color(0xFFD9483B),
    Color(0xFFFF7F70),
  ),
  SubjectColor(
    'Olive',
    Color(0xFFEAF2DC),
    Color(0xFFD2E3B5),
    Color(0xFF232D17),
    Color(0xFF3B4C26),
    Color(0xFF6A9A2B),
    Color(0xFFA6D45F),
  ),
];

SubjectColor subjectColor(int index) =>
    subjectPalette[index % subjectPalette.length];

/// Accent choices in Settings: (light, dark).
const accentChoices = <(String, Color, Color)>[
  ('Blue', Color(0xFF2B59E0), Color(0xFF7E9BFF)),
  ('Violet', Color(0xFF6D4AE0), Color(0xFFA58CFF)),
  ('Emerald', Color(0xFF0F8A5F), Color(0xFF4FD6A2)),
  ('Rose', Color(0xFFD03A6A), Color(0xFFFF7FA5)),
];
