import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/canvas_constants.dart';
import '../core/services/local_storage_service.dart';
import '../models/canvas_image_model.dart';
import '../models/note_page_model.dart';
import '../models/notebook_model.dart';
import '../models/stroke_model.dart';
import 'notebook_provider.dart';

class UndoSnapshot {
  final List<StrokeModel> strokes;
  final double cursorX;
  final int cursorLineIndex;

  const UndoSnapshot({
    required this.strokes,
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

class CanvasState {
  final NotebookModel notebook;
  final int currentPageIndex;
  final DrawingToolType activeTool;
  final Color penColor;
  final Color highlighterColor;
  final double penWidth;
  final double highlighterWidth;
  final double eraserRadius;

  /// Handwriting Pad Mode (Google Keyboard Handwriting style)
  final bool isZoomMode;
  final bool autoCommitPad;

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
    this.penWidth = 3.2,
    this.highlighterWidth = 14.0,
    this.eraserRadius = 18.0,
    this.isZoomMode = true,
    this.autoCommitPad = true,
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

  /// Y coordinate of the baseline of the current ruled row
  double get currentLineBaselineY =>
      CanvasConstants.pageTopMargin +
      (cursorLineIndex * CanvasConstants.defaultLineSpacing);

  /// Top Y coordinate of the current ruled row
  double get currentLineTopY =>
      currentLineBaselineY - CanvasConstants.defaultLineSpacing;

  /// Computes how the current pad strokes will be scaled and positioned on the active worksheet line
  NormalizedPadResult? computeNormalizedPadPreview() {
    final allPadStrokes = [
      ...padStrokes,
      if (activePadStroke != null) activePadStroke!,
    ];
    if (allPadStrokes.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    int pointCount = 0;

    for (final s in allPadStrokes) {
      for (final p in s.points) {
        minX = math.min(minX, p.x);
        minY = math.min(minY, p.y);
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
        pointCount++;
      }
    }

    if (pointCount == 0) return null;

    final rawWidth = math.max(1.0, maxX - minX);
    final rawHeight = math.max(1.0, maxY - minY);

    // Determine scale so that no matter how big or small the user writes in the pad,
    // the resulting handwriting fits neatly inside one ruled line height (23px inside 32px row).
    const targetHeight = CanvasConstants.targetLineFitHeight;
    double scale;
    if (rawHeight < 32.0 && rawWidth < 32.0) {
      // Small punctuation mark (dot, comma, dash): keep proportional without blowing up huge
      scale = targetHeight / 64.0;
    } else {
      scale = targetHeight / rawHeight;
    }

    // Ensure a very wide phrase doesn't exceed a full line width
    const maxLineWidth = CanvasConstants.pageWidth -
        CanvasConstants.leftWritingMargin -
        CanvasConstants.rightWritingMargin;
    if (rawWidth * scale > maxLineWidth) {
      scale = maxLineWidth / rawWidth;
    }

    final scaledWidth = rawWidth * scale;
    final scaledHeight = rawHeight * scale;

    // Check if we need to wrap to the next ruled line
    int targetLine = cursorLineIndex;
    double targetX = cursorX;
    if (targetX + scaledWidth >
            CanvasConstants.pageWidth - CanvasConstants.rightWritingMargin &&
        targetX > CanvasConstants.leftWritingMargin + 8.0) {
      targetLine = math.min(cursorLineIndex + 1, CanvasConstants.maxLineCount);
      targetX = CanvasConstants.leftWritingMargin;
    }

    final lineBottomY = CanvasConstants.pageTopMargin +
        (targetLine * CanvasConstants.defaultLineSpacing);
    final lineTopY = lineBottomY - CanvasConstants.defaultLineSpacing;

    // Center vertically inside the ruled line with a slight baseline bias
    final verticalOffset =
        lineTopY + (CanvasConstants.defaultLineSpacing - scaledHeight) / 2.0;

    final transformedStrokes = allPadStrokes.map((stroke) {
      final newPoints = stroke.points.map((p) {
        return StrokePoint(
          x: targetX + (p.x - minX) * scale,
          y: verticalOffset + (p.y - minY) * scale,
          pressure: p.pressure,
        );
      }).toList();

      // Normalize stroke thickness so scaled handwriting looks crisp on the worksheet
      final normalizedWidth = stroke.toolType == DrawingToolType.highlighter
          ? 12.0
          : (stroke.strokeWidth * 0.68).clamp(1.6, 4.2);

      return stroke.copyWith(
        points: newPoints,
        strokeWidth: normalizedWidth,
      );
    }).toList();

    return NormalizedPadResult(
      placedStrokes: transformedStrokes,
      scaledWidth: scaledWidth,
      targetCursorX: targetX,
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

  /// Moves the writing cursor to wherever the user tapped on the worksheet
  Future<void> setCursorFromPageTap(Offset pagePoint) async {
    if (state.hasUncommittedPadInk) {
      await commitPadStrokesToLine();
    }

    // Calculate nearest ruled line index
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
        StrokePoint(x: padPoint.dx, y: padPoint.dy, pressure: pressure),
      ],
      colorValue: color,
      strokeWidth: width,
      toolType: state.activeTool == DrawingToolType.eraser
          ? DrawingToolType.pen
          : state.activeTool,
    );

    state = state.copyWith(activePadStroke: stroke);
  }

  void appendPadStrokePoint(Offset padPoint, {double pressure = 0.5}) {
    final current = state.activePadStroke;
    if (current == null) return;

    final updatedPoints = [
      ...current.points,
      StrokePoint(x: padPoint.dx, y: padPoint.dy, pressure: pressure),
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

    state = state.copyWith(
      padStrokes: [...state.padStrokes, current],
      clearActivePadStroke: true,
    );
  }

  /// Takes whatever was handwritten in the bottom pad, scales it to fit the line height,
  /// places it at the current cursor position on the worksheet, advances the cursor, and clears the pad!
  Future<void> commitPadStrokesToLine() async {
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

    double nextCursorX =
        normalized.targetCursorX + normalized.scaledWidth + CanvasConstants.wordGap;
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
        StrokePoint(x: pagePoint.dx, y: pagePoint.dy, pressure: pressure),
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
      StrokePoint(x: pagePoint.dx, y: pagePoint.dy, pressure: pressure),
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
    final remaining = state.currentPage.strokes.where((stroke) {
      for (final p in stroke.points) {
        final dx = p.x - pagePoint.dx;
        final dy = p.y - pagePoint.dy;
        if (dx * dx + dy * dy <= radiusSq) {
          return false;
        }
      }
      return true;
    }).toList();

    if (remaining.length != state.currentPage.strokes.length) {
      final updatedPage = state.currentPage.copyWith(strokes: remaining);
      _updateCurrentPageSync(updatedPage);
    }
  }

  // ---------------- UNDO / REDO / BACKSPACE ----------------

  void _pushUndoSnapshot() {
    final snapshot = UndoSnapshot(
      strokes: state.currentPage.strokes,
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
      cursorX: state.cursorX,
      cursorLineIndex: state.cursorLineIndex,
    );
    final nextRedo = [...state.redoStack, currentSnapshot];

    state = state.copyWith(
      undoStack: nextUndo,
      redoStack: nextRedo,
      cursorX: previous.cursorX,
      cursorLineIndex: previous.cursorLineIndex,
    );
    final updatedPage = state.currentPage.copyWith(strokes: previous.strokes);
    await _updateCurrentPage(updatedPage);
  }

  Future<void> redo() async {
    if (!state.canRedo) return;
    final nextRedo = [...state.redoStack];
    final restored = nextRedo.removeLast();
    final currentSnapshot = UndoSnapshot(
      strokes: state.currentPage.strokes,
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
    final updatedPage = state.currentPage.copyWith(strokes: restored.strokes);
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
