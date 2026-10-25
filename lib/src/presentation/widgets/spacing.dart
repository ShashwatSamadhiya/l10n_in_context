import 'package:flutter/widgets.dart';

/// Spacing used by the editor UI.
abstract final class Spacing {
  /// 4 logical pixels.
  static const double xs = 4;

  /// 8 logical pixels.
  static const double sm = 8;

  /// 16 logical pixels.
  static const double md = 16;
}

/// Padding of [Spacing.md] on every side.
const EdgeInsets paddingMd = EdgeInsets.all(Spacing.md);

/// A gap of [Spacing.sm] in a row or column.
const SizedBox gapSm = SizedBox(height: Spacing.sm, width: Spacing.sm);

/// A gap of [Spacing.md] in a row or column.
const SizedBox gapMd = SizedBox(height: Spacing.md, width: Spacing.md);
