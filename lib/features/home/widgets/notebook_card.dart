import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/canvas_constants.dart';
import '../../../models/notebook_model.dart';
import '../../workspace/widgets/page_background_painter.dart';
import '../../workspace/widgets/stroke_painter.dart';

class NotebookCard extends StatelessWidget {
  final NotebookModel notebook;
  final String? folderName;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NotebookCard({
    super.key,
    required this.notebook,
    this.folderName,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final coverColor = Color(notebook.coverColorValue);
    final firstPage = notebook.pages.isNotEmpty ? notebook.pages.first : null;
    final dateStr = DateFormat('dd MMM yyyy • HH:mm').format(notebook.updatedAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail Preview Area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Left book spine accent
                  Container(
                    color: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(10),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            CanvasConstants.pageWidth / CanvasConstants.pageHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildThumbnailContent(firstPage),
                        ),
                      ),
                    ),
                  ),
                  // Colored Spine strip on left
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: Container(color: coverColor),
                  ),
                  // Page Count badge
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${notebook.pages.length} ទំព័រ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Metadata Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notebook.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (folderName != null)
                          Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                size: 12,
                                color: coverColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  folderName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: coverColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            dateStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('លុបសៀវភៅ', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailContent(dynamic firstPage) {
    if (notebook.thumbnailPath != null &&
        File(notebook.thumbnailPath!).existsSync()) {
      return Image.file(
        File(notebook.thumbnailPath!),
        fit: BoxFit.cover,
      );
    }

    if (firstPage == null) {
      return const SizedBox.shrink();
    }

    // Live vector miniature preview of the first page!
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: CanvasConstants.pageWidth,
        height: CanvasConstants.pageHeight,
        child: CustomPaint(
          painter: PageBackgroundPainter(style: firstPage.backgroundStyle),
          foregroundPainter: StrokePainter(
            strokes: firstPage.strokes,
            texts: firstPage.texts,
          ),
        ),
      ),
    );
  }
}
