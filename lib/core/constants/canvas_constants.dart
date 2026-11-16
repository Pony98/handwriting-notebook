import 'package:flutter/material.dart';

class CanvasConstants {
  CanvasConstants._();

  /// Standard virtual page dimensions (A4 aspect ratio 1 : 1.414)
  static const double pageWidth = 800.0;
  static const double pageHeight = 1131.0;
  static const Size pageSize = Size(pageWidth, pageHeight);

  /// Default Zoom Box size on the virtual page
  static const double defaultZoomBoxWidth = 260.0;
  static const double defaultZoomBoxHeight = 95.0;

  /// Left/Right margin for auto-advance newline wrap
  static const double pageHorizontalMargin = 36.0;
  static const double pageTopMargin = 60.0;
  static const double defaultLineSpacing = 32.0;

  /// Fraction of the writing pad on the right side that triggers Auto-Advance (e.g. last 22%)
  static const double autoAdvanceZoneFraction = 0.22;

  /// How far the zoom box shifts right on auto-advance (as fraction of zoomBoxWidth)
  static const double autoAdvanceStepFraction = 0.65;
}
