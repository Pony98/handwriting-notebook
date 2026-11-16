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

class CanvasState {
  final NotebookModel notebook;
  final int currentPageIndex;
  final DrawingToolType activeTool;
  final Color penColor;
  final Color highlighterColor;
  final double penWidth;
  final double highlighterWidth;
  final double eraserRadius;

  /// Split-screen Zoom Window Mode
  final bool isZoomMode;
  final Rect zoomBoxRect;

  /// Palm rejection: when true, only Stylus input is accepted (or strict palm filter)
  final bool stylusOnlyPalmRejection;

  /// Active stroke currently being drawn (real-time preview in both panes)
  final StrokeModel? activeStroke;

  /// Whether the current stroke entered the right-side auto-advance zone
  final bool enteredAutoAdvanceZone;

  /// Undo / Redo stacks of stroke lists for the current page
  final List<List<StrokeModel>> undoStack;
  final List<List<StrokeModel>> redoStack;

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
    this.zoomBoxRect = const Rect.fromLTWH(
      CanvasConstants.pageHorizontalMargin,
      CanvasConstants.pageTopMargin,
      CanvasConstants.defaultZoomBoxWidth,
      CanvasConstants.defaultZoomBoxHeight,
    ),
    this.stylusOnlyPalmRejection = false,
    this.activeStroke,
    this.enteredAutoAdvanceZone = false,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  NotePageModel get currentPage => notebook.pages[currentPageIndex];

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

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
    Rect? zoomBoxRect,
    bool? stylusOnlyPalmRejection,
    StrokeModel? activeStroke,
    bool clearActiveStroke = false,
    bool? enteredAutoAdvanceZone,
    List<List<StrokeModel>>? undoStack,
    List<List<StrokeModel>>? redoStack,
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
      zoomBoxRect: zoomBoxRect ?? this.zoomBoxRect,
      stylusOnlyPalmRejection:
          stylusOnlyPalmRejection ?? this.stylusOnlyPalmRejection,
      activeStroke:
          clearActiveStroke ? null : (activeStroke ?? this.activeStroke),
      enteredAutoAdvanceZone:
          enteredAutoAdvanceZone ?? this.enteredAutoAdvanceZone,
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
    state = state.copyWith(isZoomMode: !state.isZoomMode);
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

  // ---------------- ZOOM BOX NAVIGATION ----------------

  void moveZoomBoxTo(Offset newTopLeft) {
    final maxX = CanvasConstants.pageWidth - state.zoomBoxRect.width;
    final maxY = CanvasConstants.pageHeight - state.zoomBoxRect.height;
    final clampedX = newTopLeft.dx.clamp(0.0, maxX);
    final clampedY = newTopLeft.dy.clamp(0.0, maxY);

    state = state.copyWith(
      zoomBoxRect: Rect.fromLTWH(
        clampedX,
        clampedY,
        state.zoomBoxRect.width,
        state.zoomBoxRect.height,
      ),
    );
  }

  void advanceZoomBox() {
    final currentRect = state.zoomBoxRect;
    final stepX =
        currentRect.width * CanvasConstants.autoAdvanceStepFraction;
    double nextX = currentRect.left + stepX;
    double nextY = currentRect.top;

    final maxX = CanvasConstants.pageWidth -
        currentRect.width -
        CanvasConstants.pageHorizontalMargin / 2;

    if (nextX > maxX) {
      // Wrap to next line on the left margin!
      nextX = CanvasConstants.pageHorizontalMargin;
      nextY = (currentRect.top + CanvasConstants.defaultLineSpacing * 2).clamp(
        CanvasConstants.pageTopMargin / 2,
        CanvasConstants.pageHeight - currentRect.height - 16,
      );
    }

    moveZoomBoxTo(Offset(nextX, nextY));
  }

  void newlineZoomBox() {
    final currentRect = state.zoomBoxRect;
    final nextY = (currentRect.top + CanvasConstants.defaultLineSpacing * 2)
        .clamp(
      CanvasConstants.pageTopMargin / 2,
      CanvasConstants.pageHeight - currentRect.height - 16,
    );
    moveZoomBoxTo(Offset(CanvasConstants.pageHorizontalMargin, nextY));
  }

  // ---------------- DRAWING & ERASING ----------------

  void startStroke(
    Offset pagePoint, {
    double pressure = 0.5,
    bool inAutoAdvanceZone = false,
  }) {
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

    state = state.copyWith(
      activeStroke: stroke,
      enteredAutoAdvanceZone: inAutoAdvanceZone,
    );
  }

  void appendStrokePoint(
    Offset pagePoint, {
    double pressure = 0.5,
    bool inAutoAdvanceZone = false,
  }) {
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
      enteredAutoAdvanceZone:
          state.enteredAutoAdvanceZone || inAutoAdvanceZone,
    );
  }

  Future<void> endStroke() async {
    if (state.activeTool == DrawingToolType.eraser) {
      await _persistNotebook();
      return;
    }

    final finishedStroke = state.activeStroke;
    if (finishedStroke == null || finishedStroke.points.isEmpty) {
      state = state.copyWith(
        clearActiveStroke: true,
        enteredAutoAdvanceZone: false,
      );
      return;
    }

    final shouldAutoAdvance = state.enteredAutoAdvanceZone;
    _pushUndoSnapshot();

    final updatedStrokes = [...state.currentPage.strokes, finishedStroke];
    final updatedPage = state.currentPage.copyWith(strokes: updatedStrokes);

    state = state.copyWith(
      clearActiveStroke: true,
      enteredAutoAdvanceZone: false,
    );

    await _updateCurrentPage(updatedPage);

    if (shouldAutoAdvance) {
      advanceZoomBox();
    }
  }

  void _eraseAt(Offset pagePoint) {
    final radiusSq = state.eraserRadius * state.eraserRadius;
    final remaining = state.currentPage.strokes.where((stroke) {
      for (final p in stroke.points) {
        final dx = p.x - pagePoint.dx;
        final dy = p.y - pagePoint.dy;
        if (dx * dx + dy * dy <= radiusSq) {
          return false; // Hit by eraser
        }
      }
      return true;
    }).toList();

    if (remaining.length != state.currentPage.strokes.length) {
      final updatedPage = state.currentPage.copyWith(strokes: remaining);
      _updateCurrentPageSync(updatedPage);
    }
  }

  // ---------------- UNDO / REDO ----------------

  void _pushUndoSnapshot() {
    final nextUndo = [...state.undoStack, state.currentPage.strokes];
    if (nextUndo.length > 40) {
      nextUndo.removeAt(0);
    }
    state = state.copyWith(undoStack: nextUndo, redoStack: []);
  }

  Future<void> undo() async {
    if (!state.canUndo) return;
    final nextUndo = [...state.undoStack];
    final previousStrokes = nextUndo.removeLast();
    final nextRedo = [...state.redoStack, state.currentPage.strokes];

    state = state.copyWith(undoStack: nextUndo, redoStack: nextRedo);
    final updatedPage = state.currentPage.copyWith(strokes: previousStrokes);
    await _updateCurrentPage(updatedPage);
  }

  Future<void> redo() async {
    if (!state.canRedo) return;
    final nextRedo = [...state.redoStack];
    final restoredStrokes = nextRedo.removeLast();
    final nextUndo = [...state.undoStack, state.currentPage.strokes];

    state = state.copyWith(undoStack: nextUndo, redoStack: nextRedo);
    final updatedPage = state.currentPage.copyWith(strokes: restoredStrokes);
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
      undoStack: [],
      redoStack: [],
    );
    await _persistNotebook();
  }

  void switchPage(int index) {
    if (index < 0 || index >= state.notebook.pages.length) return;
    state = state.copyWith(
      currentPageIndex: index,
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
