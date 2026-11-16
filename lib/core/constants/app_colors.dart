import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Pen & Highlighter preset colors
  static const List<Color> penColors = [
    Color(0xFF0F172A), // Black / Dark Slate
    Color(0xFF1D4ED8), // Royal Blue
    Color(0xFFDC2626), // Red
    Color(0xFF15803D), // Green
    Color(0xFF7E22CE), // Purple
    Color(0xFFEA580C), // Orange
    Color(0xFF0D9488), // Teal
    Color(0xFF854D0E), // Brown
  ];

  static const List<Color> highlighterColors = [
    Color(0xFFFDE047), // Yellow
    Color(0xFF86EFAC), // Green
    Color(0xFF93C5FD), // Blue
    Color(0xFFF9A8D4), // Pink
    Color(0xFFFDBA74), // Orange
    Color(0xFFD8B4FE), // Purple
  ];

  // Folder preset colors
  static const List<Color> folderColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
  ];
}
