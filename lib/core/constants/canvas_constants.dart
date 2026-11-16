import 'package:flutter/material.dart';

class CanvasConstants {
  CanvasConstants._();

  /// Standard virtual page dimensions (A4 aspect ratio 1 : 1.414)
  static const double pageWidth = 800.0;
  static const double pageHeight = 1131.0;
  static const Size pageSize = Size(pageWidth, pageHeight);

  /// Ruled line geometry on the virtual page
  static const double pageHorizontalMargin = 36.0;
  static const double leftWritingMargin = 58.0; // Right after the red margin line
  static const double rightWritingMargin = 28.0;
  static const double pageTopMargin = 60.0;
  static const double defaultLineSpacing = 32.0;

  /// Target height for scaled handwriting inside a 32px ruled row
  static const double targetLineFitHeight = 23.0;

  /// Horizontal advance gap after each committed word/group
  static const double wordGap = 10.0;

  /// Horizontal advance when pressing the Space button
  static const double spaceAdvance = 24.0;

  /// Total number of ruled lines on a page
  static int get maxLineCount =>
      ((pageHeight - 24 - pageTopMargin) / defaultLineSpacing).floor();
}
