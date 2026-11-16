import 'package:flutter/material.dart';
import '../../../core/constants/canvas_constants.dart';
import '../../../models/note_page_model.dart';

class PageBackgroundPainter extends CustomPainter {
  final PaperBackgroundStyle style;
  final double lineSpacing;

  const PageBackgroundPainter({
    required this.style,
    this.lineSpacing = CanvasConstants.defaultLineSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Base warm paper background
    final bgPaint = Paint()..color = const Color(0xFFFFFEF9);
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (style == PaperBackgroundStyle.blank) return;

    final linePaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.65)
      ..strokeWidth = 1.0;

    if (style == PaperBackgroundStyle.ruled) {
      // Draw horizontal lines starting from top margin
      for (double y = CanvasConstants.pageTopMargin;
          y < size.height - 24;
          y += lineSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }

      // Draw red vertical margin line on the left
      final marginPaint = Paint()
        ..color = const Color(0xFFFCA5A5).withValues(alpha: 0.75)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        const Offset(CanvasConstants.pageHorizontalMargin * 1.4, 0),
        Offset(CanvasConstants.pageHorizontalMargin * 1.4, size.height),
        marginPaint,
      );
    } else if (style == PaperBackgroundStyle.grid) {
      // Draw square grid
      for (double y = lineSpacing; y < size.height; y += lineSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
      for (double x = lineSpacing; x < size.width; x += lineSpacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PageBackgroundPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.lineSpacing != lineSpacing;
  }
}
