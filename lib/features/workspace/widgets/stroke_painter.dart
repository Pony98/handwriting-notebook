import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../../../models/canvas_text_model.dart';
import '../../../models/stroke_model.dart';

class StrokePainter extends CustomPainter {
  final List<StrokeModel> strokes;
  final List<CanvasTextModel> texts;
  final StrokeModel? activeStroke;

  const StrokePainter({
    required this.strokes,
    this.texts = const [],
    this.activeStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw all Printed Font Text elements on the worksheet
    for (final item in texts) {
      _drawTextItem(canvas, item);
    }

    // 2. Draw all Handwriting Ink Strokes
    for (final stroke in strokes) {
      _drawSingleStroke(canvas, stroke);
    }
    if (activeStroke != null) {
      _drawSingleStroke(canvas, activeStroke!);
    }
  }

  void _drawTextItem(Canvas canvas, CanvasTextModel item) {
    if (item.text.isEmpty) return;

    final weightIndex = item.fontWeightIndex.clamp(0, FontWeight.values.length - 1);
    final textPainter = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(
          color: Color(item.colorValue),
          fontSize: item.fontSize,
          fontWeight: FontWeight.values[weightIndex],
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(item.x, item.y));
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
        .map((p) => PointVector(p.x, p.y, 0.5))
        .toList();

    final outlinePoints = getStroke(
      inputPoints,
      options: StrokeOptions(
        size: isHighlighter ? stroke.strokeWidth * 2.2 : stroke.strokeWidth,
        thinning: 0.0,
        smoothing: 0.58,
        streamline: 0.48,
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
        oldDelegate.texts != texts ||
        oldDelegate.activeStroke != activeStroke;
  }
}
