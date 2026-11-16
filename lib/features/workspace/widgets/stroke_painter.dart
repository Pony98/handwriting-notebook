import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../../../models/stroke_model.dart';

class StrokePainter extends CustomPainter {
  final List<StrokeModel> strokes;
  final StrokeModel? activeStroke;

  const StrokePainter({
    required this.strokes,
    this.activeStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawSingleStroke(canvas, stroke);
    }
    if (activeStroke != null) {
      _drawSingleStroke(canvas, activeStroke!);
    }
  }

  void _drawSingleStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;

    final isHighlighter = stroke.toolType == DrawingToolType.highlighter;
    final baseColor = Color(stroke.colorValue);

    final paint = Paint()
      ..color = isHighlighter
          ? baseColor.withValues(alpha: 0.38)
          : baseColor
      ..style = PaintingStyle.fill
      ..blendMode = isHighlighter ? BlendMode.multiply : BlendMode.srcOver;

    final inputPoints = stroke.points
        .map((p) => PointVector(p.x, p.y, p.pressure))
        .toList();

    final outlinePoints = getStroke(
      inputPoints,
      options: StrokeOptions(
        size: isHighlighter ? stroke.strokeWidth * 2.4 : stroke.strokeWidth,
        thinning: isHighlighter ? 0.0 : 0.45,
        smoothing: 0.55,
        streamline: 0.45,
        simulatePressure: false,
      ),
    );

    if (outlinePoints.isEmpty) return;

    final path = Path();
    if (outlinePoints.length == 1) {
      path.addOval(
        Rect.fromCircle(
          center: outlinePoints.first,
          radius: stroke.strokeWidth / 2,
        ),
      );
    } else {
      path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
      for (int i = 0; i < outlinePoints.length - 1; i++) {
        final p0 = outlinePoints[i];
        final p1 = outlinePoints[i + 1];
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke;
  }
}
