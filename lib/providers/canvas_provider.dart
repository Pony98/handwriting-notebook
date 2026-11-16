import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/canvas_constants.dart';
import '../core/services/local_storage_service.dart';
import '../core/utils/handwriting_recognizer.dart';
import '../models/canvas_image_model.dart';
import '../models/canvas_text_model.dart';
import '../models/note_page_model.dart';
import '../models/notebook_model.dart';
import '../models/stroke_model.dart';
import 'notebook_provider.dart';

class UndoSnapshot {
  final List<StrokeModel> strokes;
  final List<CanvasTextModel> texts;
  final double cursorX;
  final int cursorLineIndex;

  const UndoSnapshot({
    required this.strokes,
    required this.texts,
    required this.cursorX,
    required this.cursorLineIndex,
  });
}

class NormalizedPadResult {
  final List<StrokeModel> placedStrokes;
  final double scaledWidth;
  final double targetCursorX;
  final int targetLineIndex;

  const NormalizedPadResult({
    required this.placedStrokes,
    required this.scaledWidth,
    required this.targetCursorX,
    required this.targetLineIndex,
  });
}

class _StrokeCluster {
  final List<StrokeModel> strokes;
  double minX;
  double minY;
  double maxX;
  double maxY;

  _StrokeCluster({
    required this.strokes,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  double get width => math.max(1.0, maxX - minX);
  double get height => math.max(1.0, maxY - minY);
  double get centerX => (minX + maxX) / 2.0;

  bool overlapsHorizontally(_StrokeCluster other) {
    final overlapStart = math.max(minX, other.minX);
    final overlapEnd = math.min(maxX, other.maxX);
    final overlap = overlapEnd - overlapStart;
    final minWidth = math.min(width, other.width);

    if (overlap >= -6.0 &&
        (overlap >= minWidth * 0.22 ||
            (other.centerX >= minX - 8.0 && other.centerX <= maxX + 8.0) ||
            (centerX >= other.minX - 8.0 && centerX <= other.maxX + 8.0))) {
      return true;
    }
    return false;
  }

  void merge(_StrokeCluster other) {
    strokes.addAll(other.strokes);
    minX = math.min(minX, other.minX);
    minY = math.min(minY, other.minY);
    maxX = math.max(maxX, other.maxX);
    maxY = math.max(maxY, other.maxY);
  }
}

class CanvasState {
  final NotebookModel notebook;
  final int currentPageIndex;
  final DrawingToolType activeTool;
  final Color penColor;
  final Color highlighterColor;
  final double penWidth;
  final double highlighterWidth;
  final double eraserRadius;

  /// Handwriting Pad Mode
  final bool isZoomMode;
  final bool autoCommitPad;

  /// Printed Font Mode (អក្សរពុម្ភ) vs Handwriting Ink Mode (អក្សរដៃ)
  final bool isPrintedTextMode;
  final RecognitionLanguage recognitionLanguage;
  final bool strictStrokeValidation;
  final bool isRecognizing;
  final String? validationFeedback;
  final bool isValidationError;
  final List<String> recognizedCandidates;

  /// Current writing cursor on the worksheet (line index & horizontal X)
  final int cursorLineIndex;
  final double cursorX;

  /// Strokes currently written in the bottom Handwriting Pad before committing to the line
  final List<StrokeModel> padStrokes;
  final StrokeModel? activePadStroke;

  /// Palm rejection: when true, only Stylus input is accepted
  final bool stylusOnlyPalmRejection;

  /// Active stroke when drawing directly on the top full page (when pad mode is off)
  final StrokeModel? activeStroke;

  /// Undo / Redo stacks (including cursor position)
  final List<UndoSnapshot> undoStack;
  final List<UndoSnapshot> redoStack;

  const CanvasState({
    required this.notebook,
    this.currentPageIndex = 0,
    this.activeTool = DrawingToolType.pen,
    this.penColor = const Color(0xFF0F172A),
    this.highlighterColor = const Color(0xFFFDE047),
    this.penWidth = 3.5,
    this.highlighterWidth = 14.0,
    this.eraserRadius = 18.0,
    this.isZoomMode = true,
    this.autoCommitPad = true,
    this.isPrintedTextMode = true,
    this.recognitionLanguage = RecognitionLanguage.chinese,
    this.strictStrokeValidation = true,
    this.isRecognizing = false,
    this.validationFeedback,
    this.isValidationError = false,
    this.recognizedCandidates = const [],
    this.cursorLineIndex = 1,
    this.cursorX = CanvasConstants.leftWritingMargin,
    this.padStrokes = const [],
    this.activePadStroke,
    this.stylusOnlyPalmRejection = false,
    this.activeStroke,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  NotePageModel get currentPage => notebook.pages[currentPageIndex];

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get hasUncommittedPadInk =>
      padStrokes.isNotEmpty || activePadStroke != null;

  double get currentLineBaselineY =>
      CanvasConstants.pageTopMargin +
      (cursorLineIndex * CanvasConstants.defaultLineSpacing);

  double get currentLineTopY =>
      currentLineBaselineY - CanvasConstants.defaultLineSpacing;

  /// Font size for Printed Font Mode scaled according to Pen Width setting
  double get printedFontSize => (17.0 + (penWidth - 1.0) * 0.95).clamp(16.0, 26.0);

  /// Font weight index (3=w400, 4=w500, 5=w600, 6=w700, 7=w800) based on Pen Width
  int get printedFontWeightIndex =>
      (3 + ((penWidth - 1.0) / 2.2).floor()).clamp(3, 7);

  NormalizedPadResult? computeNormalizedPadPreview() {
    final allPadStrokes = [
      ...padStrokes,
      if (activePadStroke != null) activePadStroke!,
    ];
    if (allPadStrokes.isEmpty) return null;

    final List<_StrokeCluster> clusters = [];
    for (final s in allPadStrokes) {
      if (s.points.isEmpty) continue;
      double sMinX = double.infinity;
      double sMinY = double.infinity;
      double sMaxX = double.negativeInfinity;
      double sMaxY = double.negativeInfinity;
      for (final p in s.points) {
        sMinX = math.min(sMinX, p.x);
        sMinY = math.min(sMinY, p.y);
        sMaxX = math.max(sMaxX, p.x);
        sMaxY = math.max(sMaxY, p.y);
      }
      clusters.add(
        _StrokeCluster(
          strokes: [s],
          minX: sMinX,
          minY: sMinY,
          maxX: sMaxX,
          maxY: sMaxY,
        ),
      );
    }

    if (clusters.isEmpty) return null;

    clusters.sort((a, b) => a.minX.compareTo(b.minX));
    final List<_StrokeCluster> mergedClusters = [];
    for (final c in clusters) {
      if (mergedClusters.isEmpty) {
        mergedClusters.add(c);
      } else {
        final prev = mergedClusters.last;
        if (prev.overlapsHorizontally(c)) {
          prev.merge(c);
        } else {
          mergedClusters.add(c);
        }
      }
    }

    const targetHeight = CanvasConstants.targetLineFitHeight;
    const charGap = CanvasConstants.uniformCharGap;
    // Direct reflection of user's chosen penWidth on the worksheet!
    final double uniformPenStrokeWidth = (penWidth * 0.72).clamp(1.0, 9.0);

    final List<double> clusterScales = [];
    double totalWidth = 0.0;

    for (int i = 0; i < mergedClusters.length; i++) {
      final c = mergedClusters[i];
      double scale;
      if (c.height < 32.0 && c.width < 32.0) {
        scale = targetHeight / 64.0;
      } else {
        scale = targetHeight / c.height;
      }
      clusterScales.add(scale);
      totalWidth += c.width * scale;
      if (i < mergedClusters.length - 1) {
        totalWidth += charGap;
      }
    }

    const maxLineWidth = CanvasConstants.pageWidth -
        CanvasConstants.leftWritingMargin -
        CanvasConstants.rightWritingMargin;
    double lineFitFactor = 1.0;
    if (totalWidth > maxLineWidth && totalWidth > 0) {
      lineFitFactor = maxLineWidth / totalWidth;
      totalWidth = maxLineWidth;
    }

    int targetLine = cursorLineIndex;
    double startX = cursorX;
    if (startX + totalWidth >
            CanvasConstants.pageWidth - CanvasConstants.rightWritingMargin &&
        startX > CanvasConstants.leftWritingMargin + 8.0) {
      targetLine = math.min(cursorLineIndex + 1, CanvasConstants.maxLineCount);
      startX = CanvasConstants.leftWritingMargin;
    }

    final lineBottomY = CanvasConstants.pageTopMargin +
        (targetLine * CanvasConstants.defaultLineSpacing);
    final lineTopY = lineBottomY - CanvasConstants.defaultLineSpacing;

    final List<StrokeModel> transformedStrokes = [];
    double runningX = startX;

    for (int i = 0; i < mergedClusters.length; i++) {
      final c = mergedClusters[i];
      final scale = clusterScales[i] * lineFitFactor;
      final scaledClusterWidth = c.width * scale;
      final scaledClusterHeight = c.height * scale;

      final verticalOffset = lineTopY +
          (CanvasConstants.defaultLineSpacing - scaledClusterHeight) / 2.0;

      for (final stroke in c.strokes) {
        final newPoints = stroke.points.map((p) {
          return StrokePoint(
            x: runningX + (p.x - c.minX) * scale,
            y: verticalOffset + (p.y - c.minY) * scale,
            pressure: 0.5,
          );
        }).toList();

        final normalizedWidth =
            stroke.toolType == DrawingToolType.highlighter
                ? 12.0
                : uniformPenStrokeWidth;

        transformedStrokes.add(
          stroke.copyWith(
            points: newPoints,
            strokeWidth: normalizedWidth,
          ),
        );
      }

      runningX += scaledClusterWidth + (charGap * lineFitFactor);
    }

    return NormalizedPadResult(
      placedStrokes: transformedStrokes,
      scaledWidth: totalWidth,
      targetCursorX: startX,
      targetLineIndex: targetLine,
    );
  }

  CanvasState copyWith({
    NotebookModel? notebook,
    int? currentPageIndex,
    DrawingToolType? activeTool,
    Color? penColor,
    Color? highlighterColor,
    double? penWidth,
    double? highlighterWidth,
    double? eraserRadius,
    bool? isZoomMode,
    bool? autoCommitPad,
    bool? isPrintedTextMode,
    RecognitionLanguage? recognitionLanguage,
    bool? strictStrokeValidation,
    bool? isRecognizing,
    String? validationFeedback,
    bool clearValidationFeedback = false,
    bool? isValidationError,
    List<String>? recognizedCandidates,
    int? cursorLineIndex,
    double? cursorX,
    List<StrokeModel>? padStrokes,
    StrokeModel? activePadStroke,
    bool clearActivePadStroke = false,
    bool? stylusOnlyPalmRejection,
    StrokeModel? activeStroke,
    bool clearActiveStroke = false,
    List<UndoSnapshot>? undoStack,
    List<UndoSnapshot>? redoStack,
  }) {
    return CanvasState(
      notebook: notebook ?? this.notebook,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      activeTool: activeTool ?? this.activeTool,
      penColor: penColor ?? this.penColor,
      highlighterColor: highlighterColor ?? this.highlighterColor,
      penWidth: penWidth ?? this.penWidth,
      highlighterWidth: highlighterWidth ?? this.highlighterWidth,
      eraserRadius: eraserRadius ?? this.eraserRadius,
      isZoomMode: isZoomMode ?? this.isZoomMode,
      autoCommitPad: autoCommitPad ?? this.autoCommitPad,
      isPrintedTextMode: isPrintedTextMode ?? this.isPrintedTextMode,
      recognitionLanguage: recognitionLanguage ?? this.recognitionLanguage,
      strictStrokeValidation:
          strictStrokeValidation ?? this.strictStrokeValidation,
      isRecognizing: isRecognizing ?? this.isRecognizing,
      validationFeedback: clearValidationFeedback
          ? null
          : (validationFeedback ?? this.validationFeedback),
      isValidationError: isValidationError ?? this.isValidationError,
      recognizedCandidates: recognizedCandidates ?? this.recognizedCandidates,
      cursorLineIndex: cursorLineIndex ?? this.cursorLineIndex,
      cursorX: cursorX ?? this.cursorX,
      padStrokes: padStrokes ?? this.padStrokes,
      activePadStroke: clearActivePadStroke
          ? null
          : (activePadStroke ?? this.activePadStroke),
      stylusOnlyPalmRejection:
          stylusOnlyPalmRejection ?? this.stylusOnlyPalmRejection,
      activeStroke:
          clearActiveStroke ? null : (activeStroke ?? this.activeStroke),
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}

class CanvasNotifier extends FamilyNotifier<CanvasState, NotebookModel> {
  static const _uuid = Uuid();

  @override
  CanvasState build(NotebookModel arg) {
    return CanvasState(
      notebook: arg,
      penColor: AppColors.penColors.first,
      highlighterColor: AppColors.highlighterColors.first,
    );
  }

  // ---------------- TOOL & SETTINGS ----------------

  void selectTool(DrawingToolType tool) {
    state = state.copyWith(activeTool: tool);
  }

  void selectPenColor(Color color) {
    state = state.copyWith(penColor: color, activeTool: DrawingToolType.pen);
  }

  void selectHighlighterColor(Color color) {
    state = state.copyWith(
      highlighterColor: color,
      activeTool: DrawingToolType.highlighter,
    );
  }

  void setPenWidth(double width) {
    state = state.copyWith(penWidth: width);
  }

  void toggleZoomMode() {
    if (state.hasUncommittedPadInk) {
      commitPadStrokesToLine();
    }
    state = state.copyWith(isZoomMode: !state.isZoomMode);
  }

  void toggleAutoCommitPad() {
    state = state.copyWith(autoCommitPad: !state.autoCommitPad);
  }

  void togglePrintedTextMode() {
    state = state.copyWith(
      isPrintedTextMode: !state.isPrintedTextMode,
      clearValidationFeedback: true,
      isValidationError: false,
    );
  }

  void setRecognitionLanguage(RecognitionLanguage lang) {
    state = state.copyWith(
      recognitionLanguage: lang,
      clearValidationFeedback: true,
      isValidationError: false,
    );
  }

  void toggleStrictStrokeValidation() {
    state = state.copyWith(
      strictStrokeValidation: !state.strictStrokeValidation,
      clearValidationFeedback: true,
      isValidationError: false,
    );
  }

  void toggleStylusOnlyMode() {
    state = state.copyWith(
      stylusOnlyPalmRejection: !state.stylusOnlyPalmRejection,
    );
  }

  void setPaperBackgroundStyle(PaperBackgroundStyle style) {
    final updatedPage = state.currentPage.copyWith(backgroundStyle: style);
    _updateCurrentPage(updatedPage);
  }

  // ---------------- WORKSHEET LINE CURSOR NAVIGATION ----------------

  Future<void> setCursorFromPageTap(Offset pagePoint) async {
    if (state.hasUncommittedPadInk) {
      await commitPadStrokesToLine();
    }

    final rawIndex = ((pagePoint.dy -
                (CanvasConstants.pageTopMargin -
                    CanvasConstants.defaultLineSpacing)) /
            CanvasConstants.defaultLineSpacing)
        .floor();
    final lineIndex = rawIndex.clamp(1, CanvasConstants.maxLineCount);

    final clampedX = pagePoint.dx.clamp(
      CanvasConstants.leftWritingMargin,
      CanvasConstants.pageWidth - CanvasConstants.rightWritingMargin - 20.0,
    );

    state = state.copyWith(
      cursorLineIndex: lineIndex,
      cursorX: clampedX,
    );
  }

  Future<void> insertSpace() async {
    if (state.hasUncommittedPadInk) {
      await commitPadStrokesToLine();
      return;
    }

    double nextX = state.cursorX + CanvasConstants.spaceAdvance;
    int nextLine = state.cursorLineIndex;
    if (nextX >
        CanvasConstants.pageWidth - CanvasConstants.rightWritingMargin) {
      nextX = CanvasConstants.leftWritingMargin;
      nextLine = math.min(nextLine + 1, CanvasConstants.maxLineCount);
    }

    state = state.copyWith(cursorX: nextX, cursorLineIndex: nextLine);
  }

  Future<void> insertNewline() async {
    if (state.hasUncommittedPadInk) {
      await commitPadStrokesToLine();
    }
    final nextLine =
        math.min(state.cursorLineIndex + 1, CanvasConstants.maxLineCount);
    state = state.copyWith(
      cursorLineIndex: nextLine,
      cursorX: CanvasConstants.leftWritingMargin,
    );
  }

  void clearPadStrokes() {
    state = state.copyWith(
      padStrokes: const [],
      clearActivePadStroke: true,
      clearValidationFeedback: true,
      isValidationError: false,
    );
  }

  // ---------------- BOTTOM HANDWRITING PAD DRAWING ----------------

  void startPadStroke(Offset padPoint, {double pressure = 0.5}) {
    final color = state.activeTool == DrawingToolType.highlighter
        ? state.highlighterColor.toARGB32()
        : state.penColor.toARGB32();
    final width = state.activeTool == DrawingToolType.highlighter
        ? state.highlighterWidth
        : state.penWidth;

    final stroke = StrokeModel(
      points: [
        StrokePoint(x: padPoint.dx, y: padPoint.dy, pressure: 0.5),
      ],
      colorValue: color,
      strokeWidth: width,
      toolType: state.activeTool == DrawingToolType.eraser
          ? DrawingToolType.pen
          : state.activeTool,
    );

    state = state.copyWith(
      activePadStroke: stroke,
      clearValidationFeedback: true,
      isValidationError: false,
    );
  }

  void appendPadStrokePoint(Offset padPoint, {double pressure = 0.5}) {
    final current = state.activePadStroke;
    if (current == null) return;

    final updatedPoints = [
      ...current.points,
      StrokePoint(x: padPoint.dx, y: padPoint.dy, pressure: 0.5),
    ];

    state = state.copyWith(
      activePadStroke: current.copyWith(points: updatedPoints),
    );
  }

  void endPadStroke() {
    final current = state.activePadStroke;
    if (current == null || current.points.isEmpty) {
      state = state.copyWith(clearActivePadStroke: true);
      return;
    }

    // Immediate real-time check for backwards stroke direction in Strict Mode
    final updatedPadStrokes = [...state.padStrokes, current];
    String? liveFeedback;
    bool liveError = false;

    if (state.isPrintedTextMode && state.strictStrokeValidation) {
      final primitive = HandwritingRecognizer.classifyStroke(current);
      if (primitive == StrokePrimitive.hengBackwards) {
        liveFeedback =
            '⚠️ Stroke ទី ${updatedPadStrokes.length} គូសដេកបញ្ច្រាស (←)! ត្រូវគូសពីឆ្វេងទៅស្តាំ (→)';
        liveError = true;
      } else if (primitive == StrokePrimitive.shuBackwards) {
        liveFeedback =
            '⚠️ Stroke ទី ${updatedPadStrokes.length} គូសឈរបញ្ច្រាស (↑)! ត្រូវគូសពីលើចុះក្រោម (↓)';
        liveError = true;
      } else {
        liveFeedback =
            'Stroke ទី ${updatedPadStrokes.length}: ${primitive.label}';
      }
    }

    state = state.copyWith(
      padStrokes: updatedPadStrokes,
      clearActivePadStroke: true,
      validationFeedback: liveFeedback,
      isValidationError: liveError,
    );
  }

  /// Commits pad strokes:
  /// - In Printed Font Mode (`isPrintedTextMode = true`): validates stroke order/form and inserts Printed Font Text (`CanvasTextModel`).
  /// - In Handwriting Ink Mode (`isPrintedTextMode = false`): inserts normalized handwriting strokes.
  Future<void> commitPadStrokesToLine() async {
    final allPadStrokes = [
      ...state.padStrokes,
      if (state.activePadStroke != null) state.activePadStroke!,
    ];
    if (allPadStrokes.isEmpty) return;

    if (state.isPrintedTextMode) {
      state = state.copyWith(isRecognizing: true);
      final validation = await HandwritingRecognizer.validateAndRecognize(
        strokes: allPadStrokes,
        language: state.recognitionLanguage,
        strictStrokeValidation: state.strictStrokeValidation,
      );

      if (!validation.isValid || validation.recognizedText == null) {
        // Blocked due to invalid stroke form or wrong stroke order!
        state = state.copyWith(
          isRecognizing: false,
          padStrokes: const [],
          clearActivePadStroke: true,
          validationFeedback: validation.feedbackMessage,
          isValidationError: true,
          recognizedCandidates: const [],
        );
        return;
      }

      await _insertPrintedTextAtCursor(
        validation.recognizedText!,
        candidates: validation.candidates,
        feedback: validation.feedbackMessage,
      );
      return;
    }

    // Handwriting Ink Mode fallback
    final normalized = state.computeNormalizedPadPreview();
    if (normalized == null || normalized.placedStrokes.isEmpty) {
      clearPadStrokes();
      return;
    }

    _pushUndoSnapshot();

    final updatedStrokes = [
      ...state.currentPage.strokes,
      ...normalized.placedStrokes,
    ];
    final updatedPage = state.currentPage.copyWith(strokes: updatedStrokes);

    double nextCursorX = normalized.targetCursorX +
        normalized.scaledWidth +
        CanvasConstants.uniformCharGap;
    int nextLineIndex = normalized.targetLineIndex;

    if (nextCursorX >
        CanvasConstants.pageWidth - CanvasConstants.rightWritingMargin) {
      nextCursorX = CanvasConstants.leftWritingMargin;
      nextLineIndex = math.min(nextLineIndex + 1, CanvasConstants.maxLineCount);
    }

    state = state.copyWith(
      padStrokes: const [],
      clearActivePadStroke: true,
      cursorX: nextCursorX,
      cursorLineIndex: nextLineIndex,
    );

    await _updateCurrentPage(updatedPage);
  }

  /// Inserts a Printed Font character/word at the current cursor position on the worksheet
  Future<void> _insertPrintedTextAtCursor(
    String text, {
    List<String> candidates = const [],
    String? feedback,
  }) async {
    final fontSize = state.printedFontSize;
    final weightIdx = state.printedFontWeightIndex;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.values[weightIdx],
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = tp.width;
    final textHeight = tp.height;

    int targetLine = state.cursorLineIndex;
    double targetX = state.cursorX;

    if (targetX + textWidth >
            CanvasConstants.pageWidth - CanvasConstants.rightWritingMargin &&
        targetX > CanvasConstants.leftWritingMargin + 8.0) {
      targetLine =
          math.min(state.cursorLineIndex + 1, CanvasConstants.maxLineCount);
      targetX = CanvasConstants.leftWritingMargin;
    }

    final lineBottomY = CanvasConstants.pageTopMargin +
        (targetLine * CanvasConstants.defaultLineSpacing);
    final lineTopY = lineBottomY - CanvasConstants.defaultLineSpacing;
    final targetY =
        lineTopY + (CanvasConstants.defaultLineSpacing - textHeight) / 2.0;

    _pushUndoSnapshot();

    final newTextItem = CanvasTextModel(
      id: _uuid.v4(),
      text: text,
      x: targetX,
      y: targetY,
      fontSize: fontSize,
      colorValue: state.penColor.toARGB32(),
      fontWeightIndex: weightIdx,
    );

    final updatedTexts = [...state.currentPage.texts, newTextItem];
    final updatedPage = state.currentPage.copyWith(texts: updatedTexts);

    double nextCursorX =
        targetX + textWidth + CanvasConstants.uniformCharGap;
    int nextLineIndex = targetLine;

    if (nextCursorX >
        CanvasConstants.pageWidth - CanvasConstants.rightWritingMargin) {
      nextCursorX = CanvasConstants.leftWritingMargin;
      nextLineIndex = math.min(nextLineIndex + 1, CanvasConstants.maxLineCount);
    }

    state = state.copyWith(
      isRecognizing: false,
      padStrokes: const [],
      clearActivePadStroke: true,
      cursorX: nextCursorX,
      cursorLineIndex: nextLineIndex,
      validationFeedback: feedback,
      isValidationError: false,
      recognizedCandidates: candidates,
    );

    await _updateCurrentPage(updatedPage);
  }

  /// Replaces the last inserted Printed Font character if the user taps an alternative candidate chip
  Future<void> replaceLastInsertedCandidate(String candidate) async {
    if (state.currentPage.texts.isEmpty || state.undoStack.isEmpty) return;

    // Restore previous cursor & texts from top of undoStack, then insert the chosen candidate
    final lastUndo = state.undoStack.last;
    final nextUndo = state.undoStack.sublist(0, state.undoStack.length - 1);

    state = state.copyWith(
      undoStack: nextUndo,
      cursorX: lastUndo.cursorX,
      cursorLineIndex: lastUndo.cursorLineIndex,
      notebook: state.notebook.copyWith(
        pages: [
          for (int i = 0; i < state.notebook.pages.length; i++)
            if (i == state.currentPageIndex)
              state.currentPage.copyWith(texts: lastUndo.texts)
            else
              state.notebook.pages[i],
        ],
      ),
    );

    await _insertPrintedTextAtCursor(
      candidate,
      candidates: state.recognizedCandidates,
      feedback: '✅ បានជ្រើសរើសអក្សរពុម្ភ៖ «$candidate»',
    );
  }

  // ---------------- DIRECT PAGE DRAWING & ERASING ----------------

  void startStroke(Offset pagePoint, {double pressure = 0.5}) {
    if (state.activeTool == DrawingToolType.eraser) {
      _pushUndoSnapshot();
      _eraseAt(pagePoint);
      return;
    }

    final color = state.activeTool == DrawingToolType.highlighter
        ? state.highlighterColor.toARGB32()
        : state.penColor.toARGB32();
    final width = state.activeTool == DrawingToolType.highlighter
        ? state.highlighterWidth
        : state.penWidth;

    final stroke = StrokeModel(
      points: [
        StrokePoint(x: pagePoint.dx, y: pagePoint.dy, pressure: 0.5),
      ],
      colorValue: color,
      strokeWidth: width,
      toolType: state.activeTool,
    );

    state = state.copyWith(activeStroke: stroke);
  }

  void appendStrokePoint(Offset pagePoint, {double pressure = 0.5}) {
    if (state.activeTool == DrawingToolType.eraser) {
      _eraseAt(pagePoint);
      return;
    }

    final current = state.activeStroke;
    if (current == null) return;

    final updatedPoints = [
      ...current.points,
      StrokePoint(x: pagePoint.dx, y: pagePoint.dy, pressure: 0.5),
    ];

    state = state.copyWith(
      activeStroke: current.copyWith(points: updatedPoints),
    );
  }

  Future<void> endStroke() async {
    if (state.activeTool == DrawingToolType.eraser) {
      await _persistNotebook();
      return;
    }

    final finishedStroke = state.activeStroke;
    if (finishedStroke == null || finishedStroke.points.isEmpty) {
      state = state.copyWith(clearActiveStroke: true);
      return;
    }

    _pushUndoSnapshot();

    final updatedStrokes = [...state.currentPage.strokes, finishedStroke];
    final updatedPage = state.currentPage.copyWith(strokes: updatedStrokes);

    state = state.copyWith(clearActiveStroke: true);
    await _updateCurrentPage(updatedPage);
  }

  void _eraseAt(Offset pagePoint) {
    final radiusSq = state.eraserRadius * state.eraserRadius;

    final remainingStrokes = state.currentPage.strokes.where((stroke) {
      for (final p in stroke.points) {
        final dx = p.x - pagePoint.dx;
        final dy = p.y - pagePoint.dy;
        if (dx * dx + dy * dy <= radiusSq) {
          return false;
        }
      }
      return true;
    }).toList();

    final remainingTexts = state.currentPage.texts.where((t) {
      final center = Offset(t.x + t.fontSize / 2, t.y + t.fontSize / 2);
      final dx = center.dx - pagePoint.dx;
      final dy = center.dy - pagePoint.dy;
      return dx * dx + dy * dy > radiusSq * 1.4;
    }).toList();

    if (remainingStrokes.length != state.currentPage.strokes.length ||
        remainingTexts.length != state.currentPage.texts.length) {
      final updatedPage = state.currentPage.copyWith(
        strokes: remainingStrokes,
        texts: remainingTexts,
      );
      _updateCurrentPageSync(updatedPage);
    }
  }

  // ---------------- UNDO / REDO / BACKSPACE ----------------

  void _pushUndoSnapshot() {
    final snapshot = UndoSnapshot(
      strokes: state.currentPage.strokes,
      texts: state.currentPage.texts,
      cursorX: state.cursorX,
      cursorLineIndex: state.cursorLineIndex,
    );
    final nextUndo = [...state.undoStack, snapshot];
    if (nextUndo.length > 50) {
      nextUndo.removeAt(0);
    }
    state = state.copyWith(undoStack: nextUndo, redoStack: []);
  }

  Future<void> undo() async {
    if (state.hasUncommittedPadInk) {
      clearPadStrokes();
      return;
    }
    if (!state.canUndo) return;

    final nextUndo = [...state.undoStack];
    final previous = nextUndo.removeLast();
    final currentSnapshot = UndoSnapshot(
      strokes: state.currentPage.strokes,
      texts: state.currentPage.texts,
      cursorX: state.cursorX,
      cursorLineIndex: state.cursorLineIndex,
    );
    final nextRedo = [...state.redoStack, currentSnapshot];

    state = state.copyWith(
      undoStack: nextUndo,
      redoStack: nextRedo,
      cursorX: previous.cursorX,
      cursorLineIndex: previous.cursorLineIndex,
      recognizedCandidates: const [],
    );
    final updatedPage = state.currentPage.copyWith(
      strokes: previous.strokes,
      texts: previous.texts,
    );
    await _updateCurrentPage(updatedPage);
  }

  Future<void> redo() async {
    if (!state.canRedo) return;
    final nextRedo = [...state.redoStack];
    final restored = nextRedo.removeLast();
    final currentSnapshot = UndoSnapshot(
      strokes: state.currentPage.strokes,
      texts: state.currentPage.texts,
      cursorX: state.cursorX,
      cursorLineIndex: state.cursorLineIndex,
    );
    final nextUndo = [...state.undoStack, currentSnapshot];

    state = state.copyWith(
      undoStack: nextUndo,
      redoStack: nextRedo,
      cursorX: restored.cursorX,
      cursorLineIndex: restored.cursorLineIndex,
    );
    final updatedPage = state.currentPage.copyWith(
      strokes: restored.strokes,
      texts: restored.texts,
    );
    await _updateCurrentPage(updatedPage);
  }

  // ---------------- ADD-ONS: INSERT & MOVE IMAGE ----------------

  Future<void> addImageToPage(String imagePath) async {
    final newImage = CanvasImageModel(
      id: _uuid.v4(),
      imagePath: imagePath,
      x: 120,
      y: 140,
      width: 240,
      height: 180,
    );
    final updatedImages = [...state.currentPage.images, newImage];
    final updatedPage = state.currentPage.copyWith(images: updatedImages);
    await _updateCurrentPage(updatedPage);
  }

  Future<void> updateImagePosition(String imageId, Offset delta) async {
    final updatedImages = state.currentPage.images.map((img) {
      if (img.id != imageId) return img;
      return img.copyWith(
        x: (img.x + delta.dx).clamp(0.0, CanvasConstants.pageWidth - 60),
        y: (img.y + delta.dy).clamp(0.0, CanvasConstants.pageHeight - 60),
      );
    }).toList();
    final updatedPage = state.currentPage.copyWith(images: updatedImages);
    await _updateCurrentPage(updatedPage);
  }

  Future<void> removeImage(String imageId) async {
    final updatedImages =
        state.currentPage.images.where((img) => img.id != imageId).toList();
    final updatedPage = state.currentPage.copyWith(images: updatedImages);
    await _updateCurrentPage(updatedPage);
  }

  // ---------------- MULTI-PAGE MANAGEMENT ----------------

  Future<void> addNewPage() async {
    if (state.hasUncommittedPadInk) {
      await commitPadStrokesToLine();
    }
    final newPage = NotePageModel(
      id: _uuid.v4(),
      backgroundStyle: state.currentPage.backgroundStyle,
    );
    final updatedPages = [...state.notebook.pages, newPage];
    final updatedNotebook = state.notebook.copyWith(
      pages: updatedPages,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(
      notebook: updatedNotebook,
      currentPageIndex: updatedPages.length - 1,
      cursorLineIndex: 1,
      cursorX: CanvasConstants.leftWritingMargin,
      undoStack: [],
      redoStack: [],
    );
    await _persistNotebook();
  }

  Future<void> switchPage(int index) async {
    if (index < 0 || index >= state.notebook.pages.length) return;
    if (state.hasUncommittedPadInk) {
      await commitPadStrokesToLine();
    }
    state = state.copyWith(
      currentPageIndex: index,
      cursorLineIndex: 1,
      cursorX: CanvasConstants.leftWritingMargin,
      undoStack: [],
      redoStack: [],
    );
  }

  // ---------------- PERSISTENCE (AUTO-SAVE) ----------------

  void _updateCurrentPageSync(NotePageModel updatedPage) {
    final pages = [...state.notebook.pages];
    pages[state.currentPageIndex] = updatedPage;
    final updatedNotebook = state.notebook.copyWith(
      pages: pages,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(notebook: updatedNotebook);
  }

  Future<void> _updateCurrentPage(NotePageModel updatedPage) async {
    _updateCurrentPageSync(updatedPage);
    await _persistNotebook();
  }

  Future<void> _persistNotebook() async {
    await LocalStorageService.saveNotebook(state.notebook);
    ref.read(notebookListProvider.notifier).refresh();
  }
}

final canvasProvider =
    NotifierProvider.family<CanvasNotifier, CanvasState, NotebookModel>(
  CanvasNotifier.new,
);
