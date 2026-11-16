import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/note_page_model.dart';
import '../../../models/stroke_model.dart';
import '../../../providers/canvas_provider.dart';

class TopToolbar extends StatelessWidget {
  final CanvasState state;
  final CanvasNotifier notifier;
  final VoidCallback onInsertImage;
  final VoidCallback onExportPdf;
  final VoidCallback onExportPng;

  const TopToolbar({
    super.key,
    required this.state,
    required this.notifier,
    required this.onInsertImage,
    required this.onExportPdf,
    required this.onExportPng,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Undo / Redo
            IconButton(
              tooltip: 'Undo',
              onPressed: state.canUndo ? notifier.undo : null,
              icon: const Icon(Icons.undo_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: state.canRedo ? notifier.redo : null,
              icon: const Icon(Icons.redo_rounded, size: 20),
            ),
            const SizedBox(width: 4),
            _buildDivider(),

            // Pen Tool + Color/Size popover
            _ToolButton(
              icon: Icons.edit_rounded,
              label: 'ប៊ិច',
              colorIndicator: state.penColor,
              isSelected: state.activeTool == DrawingToolType.pen,
              onTap: () {
                if (state.activeTool == DrawingToolType.pen) {
                  _showPenSettingsSheet(context);
                } else {
                  notifier.selectTool(DrawingToolType.pen);
                }
              },
              onLongPress: () => _showPenSettingsSheet(context),
            ),
            const SizedBox(width: 6),

            // Highlighter Tool
            _ToolButton(
              icon: Icons.border_color_rounded,
              label: 'ហាយឡាយ',
              colorIndicator: state.highlighterColor,
              isSelected: state.activeTool == DrawingToolType.highlighter,
              onTap: () {
                if (state.activeTool == DrawingToolType.highlighter) {
                  _showHighlighterSettingsSheet(context);
                } else {
                  notifier.selectTool(DrawingToolType.highlighter);
                }
              },
              onLongPress: () => _showHighlighterSettingsSheet(context),
            ),
            const SizedBox(width: 6),

            // Eraser Tool
            _ToolButton(
              icon: Icons.cleaning_services_outlined,
              label: 'ជ័រលុប',
              isSelected: state.activeTool == DrawingToolType.eraser,
              onTap: () => notifier.selectTool(DrawingToolType.eraser),
            ),

            const SizedBox(width: 6),
            _buildDivider(),

            // Split-Screen Zoom Writing Pad Toggle
            FilterChip(
              selected: state.isZoomMode,
              onSelected: (_) => notifier.toggleZoomMode(),
              avatar: Icon(
                Icons.zoom_in_rounded,
                size: 16,
                color: state.isZoomMode
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              label: const Text(
                'Zoom សរសេរ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              selectedColor: AppColors.primaryLight,
              showCheckmark: false,
            ),
            const SizedBox(width: 6),

            // Palm Rejection (Stylus Only toggle)
            FilterChip(
              selected: state.stylusOnlyPalmRejection,
              onSelected: (_) => notifier.toggleStylusOnlyMode(),
              avatar: Icon(
                Icons.front_hand_outlined,
                size: 16,
                color: state.stylusOnlyPalmRejection
                    ? Colors.teal.shade700
                    : AppColors.textSecondary,
              ),
              label: Text(
                state.stylusOnlyPalmRejection
                    ? 'Stylus Only'
                    : 'Palm Guard',
                style: const TextStyle(fontSize: 12),
              ),
              selectedColor: Colors.teal.shade100,
              showCheckmark: false,
            ),
            const SizedBox(width: 6),
            _buildDivider(),

            // Paper Background Style Picker
            PopupMenuButton<PaperBackgroundStyle>(
              tooltip: 'ប្តូរប្រភេទក្រដាស',
              icon: const Icon(Icons.description_outlined, size: 20),
              onSelected: notifier.setPaperBackgroundStyle,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: PaperBackgroundStyle.ruled,
                  child: Text('ក្រដាសបន្ទាត់ (Ruled)'),
                ),
                const PopupMenuItem(
                  value: PaperBackgroundStyle.grid,
                  child: Text('ក្រដាសក្រឡា (Grid)'),
                ),
                const PopupMenuItem(
                  value: PaperBackgroundStyle.blank,
                  child: Text('ក្រដាសទទេ (Blank)'),
                ),
              ],
            ),

            // Insert Image
            IconButton(
              tooltip: 'បញ្ចូលរូបភាព (Insert Image)',
              onPressed: onInsertImage,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            ),

            // Export Menu (PDF / PNG)
            PopupMenuButton<String>(
              tooltip: 'Export ឯកសារ',
              icon: const Icon(Icons.download_rounded, size: 20),
              onSelected: (value) {
                if (value == 'pdf') onExportPdf();
                if (value == 'png') onExportPng();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Export ជា PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'png',
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Export ជារូបភាព (PNG)'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.border,
    );
  }

  void _showPenSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'កំណត់ពណ៌ និងទំហំប៊ិច (Pen Settings)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppColors.penColors.map((color) {
                  final selected =
                      color.toARGB32() == state.penColor.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      notifier.selectPenColor(color);
                      Navigator.pop(ctx);
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: color,
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text('ទំហំប៊ិច (Stroke Size)៖'),
              StatefulBuilder(
                builder: (context, setModalState) {
                  double currentWidth = state.penWidth;
                  return Slider(
                    value: currentWidth,
                    min: 1.5,
                    max: 10.0,
                    divisions: 17,
                    label: currentWidth.toStringAsFixed(1),
                    onChanged: (val) {
                      setModalState(() => currentWidth = val);
                      notifier.setPenWidth(val);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHighlighterSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ជ្រើសរើសពណ៌ហាយឡាយ (Highlighter Colors)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: AppColors.highlighterColors.map((color) {
                  final selected =
                      color.toARGB32() == state.highlighterColor.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      notifier.selectHighlighterColor(color);
                      Navigator.pop(ctx);
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: color,
                      child: selected
                          ? const Icon(Icons.check, color: Colors.black87)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? colorIndicator;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ToolButton({
    required this.icon,
    required this.label,
    this.colorIndicator,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            if (colorIndicator != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colorIndicator,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
