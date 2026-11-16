import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/canvas_constants.dart';
import '../../../providers/canvas_provider.dart';
import 'stroke_painter.dart';

class ZoomTargetBox extends StatelessWidget {
  final CanvasState state;

  const ZoomTargetBox({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final preview = state.computeNormalizedPadPreview();
    final activeLineIndex = preview?.targetLineIndex ?? state.cursorLineIndex;
    final activeCursorX = preview != null
        ? preview.targetCursorX + preview.scaledWidth
        : state.cursorX;

    final lineBottomY = CanvasConstants.pageTopMargin +
        (activeLineIndex * CanvasConstants.defaultLineSpacing);
    final lineTopY = lineBottomY - CanvasConstants.defaultLineSpacing;

    return IgnorePointer(
      child: Stack(
        children: [
          // 1. Highlight band along the active ruled row
          Positioned(
            left: CanvasConstants.leftWritingMargin - 6,
            right: CanvasConstants.rightWritingMargin - 6,
            top: lineTopY,
            height: CanvasConstants.defaultLineSpacing,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(4),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // 2. Live auto-scaled preview of uncommitted strokes right inside the row!
          if (preview != null && preview.placedStrokes.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: StrokePainter(
                  strokes: preview.placedStrokes,
                ),
              ),
            ),

          // 3. Writing Cursor Bar (|) showing exact insertion point on the line
          Positioned(
            left: activeCursorX,
            top: lineTopY + 3,
            height: CanvasConstants.defaultLineSpacing - 6,
            child: Column(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2.4,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
