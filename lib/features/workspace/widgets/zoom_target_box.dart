import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ZoomTargetBox extends StatelessWidget {
  final Rect zoomRect;
  final ValueChanged<Offset> onMove;

  const ZoomTargetBox({
    super.key,
    required this.zoomRect,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: zoomRect.left,
      top: zoomRect.top,
      width: zoomRect.width,
      height: zoomRect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) {
          onMove(zoomRect.topLeft + details.delta);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.primary,
              width: 2.2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_with, size: 11, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'ZOOM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
