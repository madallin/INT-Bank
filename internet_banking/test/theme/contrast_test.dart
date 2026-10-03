import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/theme/app_tokens.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Composites a translucent token (e.g. brandSurface) over [base].
Color flatten(Color c, Color base) => Color.alphaBlend(c, base);

// Flutter's textContrastGuideline samples anti-aliased pixels and
// under-reports thin text, so contrast is asserted here from the tokens.
void main() {
  const aa = 4.5; // WCAG AA, normal-size text

  for (final (name, c) in [('light', AppColors.light), ('dark', AppColors.dark)]) {
    group('$name theme', () {
      final backgrounds = {
        'surface': c.surface,
        'background': c.background,
        'surfaceMuted': flatten(c.surfaceMuted, c.surface),
      };
      final texts = {
        'textPrimary': c.textPrimary,
        'textSecondary': c.textSecondary,
        'textMuted': c.textMuted,
        'brand': c.brand,
        'positive': c.positive,
        'negative': c.negative,
        'danger': c.danger,
      };

      for (final t in texts.entries) {
        for (final b in backgrounds.entries) {
          test('${t.key} on ${b.key} meets AA', () {
            expect(contrast(t.value, b.value), greaterThanOrEqualTo(aa));
          });
        }
      }

      test('brand text on brand tint meets AA', () {
        expect(contrast(c.brand, flatten(c.brandSurface, c.surface)), greaterThanOrEqualTo(aa));
      });
      test('danger text on danger surface meets AA', () {
        expect(contrast(c.danger, c.dangerSurface), greaterThanOrEqualTo(aa));
      });
      test('onBrand on brand-filled controls meets AA', () {
        expect(contrast(c.onBrand, c.brand), greaterThanOrEqualTo(aa));
      });
      test('white text on hero panels and the bank card meets AA', () {
        for (final bg in [c.heroStart, c.heroEnd, c.cardGradientStart, c.cardGradientEnd]) {
          expect(contrast(Colors.white, bg), greaterThanOrEqualTo(aa), reason: '$bg');
        }
      });
      test('onDanger on danger buttons and badges meets AA', () {
        expect(contrast(c.onDanger, c.danger), greaterThanOrEqualTo(aa));
      });
    });
  }
}
