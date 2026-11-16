import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/canvas_provider.dart';
import 'stroke_painter.dart';

class ZoomWritingPad extends StatefulWidget {
  final CanvasState state;
  final CanvasNotifier notifier;
  final ValueChanged<double>? onVerticalResizeDelta;

  const ZoomWritingPad({
    super.key,
    required this.state,
    required this.notifier,
    this.onVerticalResizeDelta,
  });

  @override
  State<ZoomWritingPad> createState() => _ZoomWritingPadState();
}

class _ZoomWritingPadState extends State<ZoomWritingPad> {
  int? _activePointerId;
  Timer? _autoCommitTimer;

  static const Duration _autoCommitDelay = Duration(milliseconds: 1050);

  @override
  void dispose() {
    _autoCommitTimer?.cancel();
    super.dispose();
  }

  void _cancelAutoCommitTimer() {
    _autoCommitTimer?.cancel();
    _autoCommitTimer = null;
  }

  void _scheduleAutoCommitIfEnabled() {
    _cancelAutoCommitTimer();
    if (!widget.state.autoCommitPad) return;

    _autoCommitTimer = Timer(_autoCommitDelay, () {
      if (!mounted) return;
      if (widget.state.hasUncommittedPadInk && _activePointerId == null) {
        widget.notifier.commitPadStrokesToLine();
      }
    });
  }

  bool _shouldRejectPalm(PointerEvent event) {
    if (widget.state.stylusOnlyPalmRejection &&
        event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return true;
    }
    if (event.kind == PointerDeviceKind.touch && event.size > 14.0) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasPadInk = widget.state.hasUncommittedPadInk;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Interactive Draggable Blue Splitter Bar + Header
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              widget.onVerticalResizeDelta?.call(details.delta.dy);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Blue Interactive Drag Handle Bar
                Container(
                  width: double.infinity,
                  height: 16,
                  color: AppColors.primary,
                  alignment: Alignment.center,
                  child: Container(
                    width: 46,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Header Sub-bar (Also draggable to resize!)
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFFE2E8F0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.swap_vert_rounded,
                        size: 17,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasPadInk
                              ? 'កំពុងសរសេរ... (នឹងបង្រួមដាក់ចូលជួរដោយស្វ័យប្រវត្តិ)'
                              : 'អូសបន្ទាត់ខៀវឡើង/ចុះដើម្បីពង្រីកផ្ទាំងសរសេរ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Auto-commit toggle chip
                      InkWell(
                        onTap: widget.notifier.toggleAutoCommitPad,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: widget.state.autoCommitPad
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Text(
                            widget.state.autoCommitPad
                                ? 'ដាក់ចូលស្វ័យប្រវត្តិ: បើក'
                                : 'ដាក់ចូលស្វ័យប្រវត្តិ: បិទ',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: widget.state.autoCommitPad
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Large Freeform Handwriting Pad Area (Google Handwriting Keyboard style)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEF9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasPadInk
                        ? AppColors.primary
                        : const Color(0xFFCBD5E1),
                    width: hasPadInk ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    if (_shouldRejectPalm(event)) return;
                    if (_activePointerId != null &&
                        event.kind != PointerDeviceKind.stylus) {
                      return;
                    }
                    _cancelAutoCommitTimer();
                    _activePointerId = event.pointer;

                    final pressure =
                        event.pressure > 0 ? event.pressure : 0.5;
                    widget.notifier.startPadStroke(
                      event.localPosition,
                      pressure: pressure,
                    );
                  },
                  onPointerMove: (event) {
                    if (event.pointer != _activePointerId) return;
                    if (_shouldRejectPalm(event)) return;

                    final pressure =
                        event.pressure > 0 ? event.pressure : 0.5;
                    widget.notifier.appendPadStrokePoint(
                      event.localPosition,
                      pressure: pressure,
                    );
                  },
                  onPointerUp: (event) {
                    if (event.pointer != _activePointerId) return;
                    _activePointerId = null;
                    widget.notifier.endPadStroke();
                    _scheduleAutoCommitIfEnabled();
                  },
                  onPointerCancel: (event) {
                    if (event.pointer != _activePointerId) return;
                    _activePointerId = null;
                    widget.notifier.endPadStroke();
                    _scheduleAutoCommitIfEnabled();
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Subtle handwriting guide lines inside the pad
                      CustomPaint(
                        painter: _PadGuideLinesPainter(),
                      ),

                      // Watermark hint when pad is empty
                      if (!hasPadInk)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.gesture_rounded,
                                size: 34,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.25),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'សរសេរអក្សរដោយដៃនៅទីនេះ (ទំហំប៉ុនណាក៏បាន)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // User's actual strokes in the pad (scaled up nicely for bold visibility)
                      CustomPaint(
                        painter: StrokePainter(
                          strokes: widget.state.padStrokes
                              .map(
                                (s) => s.copyWith(
                                  strokeWidth: s.strokeWidth * 2.1,
                                ),
                              )
                              .toList(),
                          activeStroke: widget.state.activePadStroke?.copyWith(
                            strokeWidth:
                                widget.state.activePadStroke!.strokeWidth * 2.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Keyboard-style Action Bar (Clear, Backspace, Space, Insert, New Line)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            child: Row(
              children: [
                // Clear uncommitted pad strokes
                _PadActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'សម្អាត',
                  onTap: hasPadInk
                      ? () {
                          _cancelAutoCommitTimer();
                          widget.notifier.clearPadStrokes();
                        }
                      : null,
                ),
                const SizedBox(width: 8),

                // Backspace / Undo last placed word
                _PadActionButton(
                  icon: Icons.backspace_outlined,
                  label: 'លុបពាក្យមុន',
                  onTap: (hasPadInk || widget.state.canUndo)
                      ? () {
                          _cancelAutoCommitTimer();
                          widget.notifier.undo();
                        }
                      : null,
                ),
                const SizedBox(width: 8),

                // Wide Space Bar Button (Commits current word OR inserts space)
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _cancelAutoCommitTimer();
                        widget.notifier.insertSpace();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.space_bar_rounded, size: 18),
                      label: Text(
                        hasPadInk ? 'ដាក់ចូលបន្ទាត់ (Insert)' : 'ដកឃ្លា (Space)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // New Line Button (Enter)
                SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: () {
                      _cancelAutoCommitTimer();
                      widget.notifier.insertNewline();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.keyboard_return_rounded, size: 18),
                    label: const Text(
                      'ចុះបន្ទាត់',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
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

class _PadGuideLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dashedPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.55)
      ..strokeWidth = 1.0;

    final midY = size.height * 0.52;
    final baselineY = size.height * 0.78;

    // Draw dashed midline
    for (double x = 16; x < size.width - 16; x += 12) {
      canvas.drawLine(Offset(x, midY), Offset(x + 6, midY), dashedPaint);
    }

    // Draw solid baseline guide
    final basePaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.45)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(16, baselineY),
      Offset(size.width - 16, baselineY),
      basePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PadActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PadActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
