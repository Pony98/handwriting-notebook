import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/canvas_constants.dart';
import '../../../providers/canvas_provider.dart';
import 'page_background_painter.dart';
import 'stroke_painter.dart';

class ZoomWritingPad extends StatefulWidget {
  final CanvasState state;
  final CanvasNotifier notifier;

  const ZoomWritingPad({
    super.key,
    required this.state,
    required this.notifier,
  });

  @override
  State<ZoomWritingPad> createState() => _ZoomWritingPadState();
}

class _ZoomWritingPadState extends State<ZoomWritingPad> {
  /// Active pointer ID for strict single-pointer + palm rejection
  int? _activePointerId;

  bool _shouldRejectPalm(PointerEvent event) {
    // 1. If Stylus-Only mode is turned on, ignore non-stylus input
    if (widget.state.stylusOnlyPalmRejection &&
        event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return true;
    }

    // 2. Built-in Palm Guard: reject large contact area (palm resting on screen)
    if (event.kind == PointerDeviceKind.touch && event.size > 14.0) {
      return true;
    }

    return false;
  }

  /// Converts a local point inside the zoomed Writing Pad into virtual Page coordinates
  Offset _padToPageCoordinates(Offset localPoint, double scale) {
    final zoomTopLeft = widget.state.zoomBoxRect.topLeft;
    return zoomTopLeft + (localPoint / scale);
  }

  @override
  Widget build(BuildContext context) {
    final zoomRect = widget.state.zoomBoxRect;
    final page = widget.state.currentPage;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: const Border(
          top: BorderSide(color: AppColors.primary, width: 2.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Zoom Writing Pad Header Bar (Navigation & Auto-advance controls)
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFE2E8F0),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.scanSearch,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'ផ្ទាំងពង្រីកសរសេរដៃ (Zoom Writing Pad)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Manual Zoom Box Controls (Left, Right, Newline)
                _SmallNavButton(
                  icon: LucideIcons.arrowLeft,
                  tooltip: 'រំកិលទៅឆ្វេង',
                  onTap: () => widget.notifier.moveZoomBoxTo(
                    zoomRect.topLeft - const Offset(80, 0),
                  ),
                ),
                const SizedBox(width: 6),
                _SmallNavButton(
                  icon: LucideIcons.arrowRight,
                  tooltip: 'រំកិលទៅស្តាំ (Advance)',
                  onTap: widget.notifier.advanceZoomBox,
                ),
                const SizedBox(width: 6),
                _SmallNavButton(
                  icon: LucideIcons.cornerDownLeft,
                  tooltip: 'ចុះបន្ទាត់ថ្មី (New Line)',
                  onTap: widget.notifier.newlineZoomBox,
                ),
              ],
            ),
          ),

          // Magnified Writing Canvas Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate uniform scale so zoomBoxRect fits comfortably inside the pad
                final scaleX = constraints.maxWidth / zoomRect.width;
                final scaleY = constraints.maxHeight / zoomRect.height;
                final scale = scaleX < scaleY ? scaleX : scaleY;

                final padWidth = zoomRect.width * scale;
                final padHeight = zoomRect.height * scale;
                final autoAdvanceLeft =
                    padWidth * (1.0 - CanvasConstants.autoAdvanceZoneFraction);

                return Center(
                  child: SizedBox(
                    width: padWidth,
                    height: padHeight,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (_shouldRejectPalm(event)) return;
                        // If a stylus touches down, override any accidental finger stroke
                        if (_activePointerId != null &&
                            event.kind != PointerDeviceKind.stylus) {
                          return;
                        }
                        _activePointerId = event.pointer;

                        final inAutoZone =
                            event.localPosition.dx >= autoAdvanceLeft;
                        final pagePt =
                            _padToPageCoordinates(event.localPosition, scale);
                        final pressure =
                            event.pressure > 0 ? event.pressure : 0.5;

                        widget.notifier.startStroke(
                          pagePt,
                          pressure: pressure,
                          inAutoAdvanceZone: inAutoZone,
                        );
                      },
                      onPointerMove: (event) {
                        if (event.pointer != _activePointerId) return;
                        if (_shouldRejectPalm(event)) return;

                        final inAutoZone =
                            event.localPosition.dx >= autoAdvanceLeft;
                        final pagePt =
                            _padToPageCoordinates(event.localPosition, scale);
                        final pressure =
                            event.pressure > 0 ? event.pressure : 0.5;

                        widget.notifier.appendStrokePoint(
                          pagePt,
                          pressure: pressure,
                          inAutoAdvanceZone: inAutoZone,
                        );
                      },
                      onPointerUp: (event) {
                        if (event.pointer != _activePointerId) return;
                        _activePointerId = null;
                        widget.notifier.endStroke();
                      },
                      onPointerCancel: (event) {
                        if (event.pointer != _activePointerId) return;
                        _activePointerId = null;
                        widget.notifier.endStroke();
                      },
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Magnified Viewport of the actual Virtual Page!
                            Transform(
                              transform: Matrix4.diagonal3Values(
                                scale,
                                scale,
                                1.0,
                              )..translateByDouble(
                                  -zoomRect.left,
                                  -zoomRect.top,
                                  0.0,
                                  1.0,
                                ),
                              child: SizedBox(
                                width: CanvasConstants.pageWidth,
                                height: CanvasConstants.pageHeight,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: PageBackgroundPainter(
                                          style: page.backgroundStyle,
                                        ),
                                      ),
                                    ),
                                    // Inserted Images visible inside zoomed area
                                    for (final img in page.images)
                                      if (File(img.imagePath).existsSync())
                                        Positioned(
                                          left: img.x,
                                          top: img.y,
                                          width: img.width,
                                          height: img.height,
                                          child: Image.file(
                                            File(img.imagePath),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                    // Real-time Strokes
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: StrokePainter(
                                          strokes: page.strokes,
                                          activeStroke:
                                              widget.state.activeStroke,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 2. Right-side Auto-Advance Zone Overlay
                            Positioned(
                              left: autoAdvanceLeft,
                              top: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.06),
                                    border: Border(
                                      left: BorderSide(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.all(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Auto-Advance »',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 15, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
