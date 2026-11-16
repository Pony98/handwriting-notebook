import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/canvas_constants.dart';
import '../../core/utils/export_helper.dart';
import '../../models/notebook_model.dart';
import '../../providers/canvas_provider.dart';
import 'widgets/page_background_painter.dart';
import 'widgets/stroke_painter.dart';
import 'widgets/top_toolbar.dart';
import 'widgets/zoom_target_box.dart';
import 'widgets/zoom_writing_pad.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  final NotebookModel initialNotebook;

  const WorkspaceScreen({
    super.key,
    required this.initialNotebook,
  });

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final GlobalKey _pageExportBoundaryKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();
  int? _activeTopPointerId;

  Future<void> _pickAndInsertImage(CanvasNotifier notifier) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await notifier.addImageToPage(picked.path);
    }
  }

  bool _shouldRejectPalm(PointerEvent event, bool stylusOnly) {
    if (stylusOnly &&
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
    final state = ref.watch(canvasProvider(widget.initialNotebook));
    final notifier = ref.read(canvasProvider(widget.initialNotebook).notifier);
    final currentPage = state.currentPage;

    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.notebook.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'ទំព័រទី ${state.currentPageIndex + 1} / ${state.notebook.pages.length} • រក្សាទុកស្វ័យប្រវត្តិ (Auto-saved)',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // Previous Page
          IconButton(
            tooltip: 'ទំព័រមុន',
            onPressed: state.currentPageIndex > 0
                ? () => notifier.switchPage(state.currentPageIndex - 1)
                : null,
            icon: const Icon(LucideIcons.chevronLeft, size: 20),
          ),
          // Next Page
          IconButton(
            tooltip: 'ទំព័របន្ទាប់',
            onPressed: state.currentPageIndex < state.notebook.pages.length - 1
                ? () => notifier.switchPage(state.currentPageIndex + 1)
                : null,
            icon: const Icon(LucideIcons.chevronRight, size: 20),
          ),
          // Add New Page
          IconButton(
            tooltip: 'បន្ថែមទំព័រថ្មី',
            onPressed: notifier.addNewPage,
            icon: const Icon(LucideIcons.filePlus2, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Drawing & Action Toolbar
          TopToolbar(
            state: state,
            notifier: notifier,
            onInsertImage: () => _pickAndInsertImage(notifier),
            onExportPdf: () => ExportHelper.exportAsPdf(
              boundaryKey: _pageExportBoundaryKey,
              title: state.notebook.title,
            ),
            onExportPng: () => ExportHelper.exportAsImage(
              context: context,
              boundaryKey: _pageExportBoundaryKey,
              title: state.notebook.title,
            ),
          ),

          // 2. Top Preview / Full Worksheet Area
          Expanded(
            flex: state.isZoomMode ? 55 : 100,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: AspectRatio(
                  aspectRatio:
                      CanvasConstants.pageWidth / CanvasConstants.pageHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: CanvasConstants.pageWidth,
                        height: CanvasConstants.pageHeight,
                        child: Stack(
                          children: [
                            // Exportable Page Canvas (Background + Images + Strokes)
                            RepaintBoundary(
                              key: _pageExportBoundaryKey,
                              child: SizedBox(
                                width: CanvasConstants.pageWidth,
                                height: CanvasConstants.pageHeight,
                                child: Stack(
                                  children: [
                                    // Paper Background
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: PageBackgroundPainter(
                                          style: currentPage.backgroundStyle,
                                        ),
                                      ),
                                    ),

                                    // Inserted Images (Draggable & Deletable)
                                    for (final img in currentPage.images)
                                      if (File(img.imagePath).existsSync())
                                        Positioned(
                                          left: img.x,
                                          top: img.y,
                                          width: img.width,
                                          height: img.height,
                                          child: GestureDetector(
                                            onPanUpdate: (details) {
                                              notifier.updateImagePosition(
                                                img.id,
                                                details.delta,
                                              );
                                            },
                                            onLongPress: () {
                                              notifier.removeImage(img.id);
                                            },
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: Image.file(
                                                    File(img.imagePath),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                Positioned(
                                                  right: 4,
                                                  top: 4,
                                                  child: GestureDetector(
                                                    onTap: () => notifier
                                                        .removeImage(img.id),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                        4,
                                                      ),
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors.black54,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        size: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                    // Direct Drawing Listener on Full Page (or Tap to move Zoom Box)
                                    Positioned.fill(
                                      child: Listener(
                                        behavior: HitTestBehavior.translucent,
                                        onPointerDown: (event) {
                                          if (state.isZoomMode) {
                                            // In Split-Screen Zoom mode, tapping on the preview page jumps the Zoom Target Box there!
                                            final targetTopLeft =
                                                event.localPosition -
                                                    Offset(
                                                      state.zoomBoxRect.width /
                                                          2,
                                                      state.zoomBoxRect.height /
                                                          2,
                                                    );
                                            notifier
                                                .moveZoomBoxTo(targetTopLeft);
                                            return;
                                          }

                                          if (_shouldRejectPalm(
                                            event,
                                            state.stylusOnlyPalmRejection,
                                          )) {
                                            return;
                                          }
                                          _activeTopPointerId = event.pointer;
                                          notifier.startStroke(
                                            event.localPosition,
                                            pressure: event.pressure > 0
                                                ? event.pressure
                                                : 0.5,
                                          );
                                        },
                                        onPointerMove: (event) {
                                          if (state.isZoomMode) return;
                                          if (event.pointer !=
                                              _activeTopPointerId) {
                                            return;
                                          }
                                          notifier.appendStrokePoint(
                                            event.localPosition,
                                            pressure: event.pressure > 0
                                                ? event.pressure
                                                : 0.5,
                                          );
                                        },
                                        onPointerUp: (event) {
                                          if (state.isZoomMode) return;
                                          if (event.pointer !=
                                              _activeTopPointerId) {
                                            return;
                                          }
                                          _activeTopPointerId = null;
                                          notifier.endStroke();
                                        },
                                        child: CustomPaint(
                                          painter: StrokePainter(
                                            strokes: currentPage.strokes,
                                            activeStroke: state.activeStroke,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Zoom Target Box Overlay (Only shown on Preview Page, not exported in PDF/PNG)
                            if (state.isZoomMode)
                              ZoomTargetBox(
                                zoomRect: state.zoomBoxRect,
                                onMove: notifier.moveZoomBoxTo,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Split-Screen Zoom Writing Pad (Real-time sync + Auto-advance + Palm Rejection)
          if (state.isZoomMode)
            Expanded(
              flex: 45,
              child: ZoomWritingPad(
                state: state,
                notifier: notifier,
              ),
            ),
        ],
      ),
    );
  }
}
