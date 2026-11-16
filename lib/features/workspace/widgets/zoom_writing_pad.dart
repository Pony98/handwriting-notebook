import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/handwriting_recognizer.dart';
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

  static const Duration _autoCommitDelay = Duration(milliseconds: 1200);

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
    final feedback = widget.state.validationFeedback;
    final isError = widget.state.isValidationError;
    final candidates = widget.state.recognizedCandidates;

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
          // 1. Interactive Draggable Blue Splitter Bar + Mode Controls Header
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
                  height: 15,
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

                // Control Sub-bar (Printed Font vs Ink, Language, Strict Stroke Check, Auto-Insert)
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFFE2E8F0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Mode Switch: អក្សរពុម្ភ (Printed Font) vs អក្សរដៃ (Handwriting Ink)
                        _HeaderPill(
                          label: widget.state.isPrintedTextMode
                              ? 'ប្រភេទ: អក្សរពុម្ភ'
                              : 'ប្រភេទ: អក្សរដៃ',
                          icon: widget.state.isPrintedTextMode
                              ? Icons.font_download_rounded
                              : Icons.gesture_rounded,
                          isActive: widget.state.isPrintedTextMode,
                          onTap: widget.notifier.togglePrintedTextMode,
                        ),
                        const SizedBox(width: 6),

                        // Language Picker (Only in Printed Font Mode)
                        if (widget.state.isPrintedTextMode) ...[
                          PopupMenuButton<RecognitionLanguage>(
                            tooltip: 'ជ្រើសរើសភាសាអក្សរពុម្ភ',
                            onSelected: widget.notifier.setRecognitionLanguage,
                            itemBuilder: (ctx) => RecognitionLanguage.values
                                .map(
                                  (lang) => PopupMenuItem(
                                    value: lang,
                                    child: Text(lang.label),
                                  ),
                                )
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.translate_rounded,
                                    size: 13,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.state.recognitionLanguage.label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Strict Stroke Order Check Toggle
                          _HeaderPill(
                            label: widget.state.strictStrokeValidation
                                ? 'ពិនិត្យ Stroke: បើក'
                                : 'ពិនិត្យ Stroke: បិទ',
                            icon: Icons.verified_outlined,
                            isActive: widget.state.strictStrokeValidation,
                            activeColor: Colors.teal.shade700,
                            onTap: widget.notifier.toggleStrictStrokeValidation,
                          ),
                          const SizedBox(width: 6),
                        ],

                        // Auto-commit toggle chip
                        _HeaderPill(
                          label: widget.state.autoCommitPad
                              ? 'ដាក់ចូលស្វ័យប្រវត្តិ: បើក'
                              : 'ដាក់ចូលស្វ័យប្រវត្តិ: បិទ',
                          icon: Icons.timer_outlined,
                          isActive: widget.state.autoCommitPad,
                          onTap: widget.notifier.toggleAutoCommitPad,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Stroke Validation Feedback / Candidate Bar
          if (feedback != null || candidates.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: isError
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFDCFCE7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      feedback ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isError
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                  if (!isError && candidates.length > 1)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: candidates.take(4).map((cand) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: InkWell(
                              onTap: () => widget.notifier
                                  .replaceLastInsertedCandidate(cand),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  cand,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

          // 3. Large Freeform Handwriting Pad Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEF9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isError
                        ? Colors.red
                        : (hasPadInk
                            ? AppColors.primary
                            : const Color(0xFFCBD5E1)),
                    width: (hasPadInk || isError) ? 2.0 : 1.2,
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
                      // Chinese Tianzige (田字格) + Baseline guide lines inside the pad
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
                                widget.state.isPrintedTextMode
                                    ? Icons.translate_rounded
                                    : Icons.gesture_rounded,
                                size: 32,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.state.isPrintedTextMode
                                    ? 'សរសេរតាមលំដាប់ Stroke (${widget.state.recognitionLanguage.label}) ដើម្បីបំប្លែងជាអក្សរពុម្ភ'
                                    : 'សរសេរអក្សរដោយដៃនៅទីនេះ (ទំហំប៉ុនណាក៏បាន)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // User's actual strokes in the pad
                      CustomPaint(
                        painter: StrokePainter(
                          strokes: widget.state.padStrokes
                              .map(
                                (s) => s.copyWith(
                                  strokeWidth: s.strokeWidth * 1.8,
                                ),
                              )
                              .toList(),
                          activeStroke: widget.state.activePadStroke?.copyWith(
                            strokeWidth:
                                widget.state.activePadStroke!.strokeWidth * 1.8,
                          ),
                        ),
                      ),

                      // Loading spinner when recognizing
                      if (widget.state.isRecognizing)
                        const Positioned(
                          right: 10,
                          top: 10,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Bottom Keyboard-style Action Bar (Clear, Backspace, Space/Insert, New Line)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            child: Row(
              children: [
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
                      icon: Icon(
                        hasPadInk
                            ? Icons.check_circle_outline_rounded
                            : Icons.space_bar_rounded,
                        size: 18,
                      ),
                      label: Text(
                        hasPadInk ? 'ផ្ទៀងផ្ទាត់ & ដាក់ចូល' : 'ដកឃ្លា (Space)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

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

class _HeaderPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  const _HeaderPill({
    required this.label,
    required this.icon,
    required this.isActive,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? Colors.white : color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : color,
              ),
            ),
          ],
        ),
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

    final midY = size.height * 0.5;
    final midX = size.width * 0.5;

    // Horizontal center dashed guide (Tianzige style)
    for (double x = 16; x < size.width - 16; x += 12) {
      canvas.drawLine(Offset(x, midY), Offset(x + 6, midY), dashedPaint);
    }

    // Vertical center dashed guide (Tianzige style)
    for (double y = 12; y < size.height - 12; y += 12) {
      canvas.drawLine(Offset(midX, y), Offset(midX, y + 6), dashedPaint);
    }
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
