import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/folder_model.dart';
import '../../../models/note_page_model.dart';

class CreateFolderDialog extends StatefulWidget {
  final Future<void> Function(String name, int colorValue) onCreate;

  const CreateFolderDialog({super.key, required this.onCreate});

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _controller = TextEditingController();
  int _selectedColor = AppColors.folderColors.first.toARGB32();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('បង្កើត Folder ថ្មី'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ឈ្មោះ Folder (ឧ. គណិតវិទ្យា, រូបវិទ្យា)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ជ្រើសរើសពណ៌សម្គាល់៖',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: AppColors.folderColors.map((color) {
              final value = color.toARGB32();
              final isSelected = value == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = value),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: color,
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('បោះបង់'),
        ),
        FilledButton(
          onPressed: () async {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            await widget.onCreate(name, _selectedColor);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('បង្កើត'),
        ),
      ],
    );
  }
}

class CreateNotebookDialog extends StatefulWidget {
  final List<FolderModel> folders;
  final String? initialFolderId;
  final Future<void> Function({
    required String title,
    String? folderId,
    required int coverColorValue,
    required PaperBackgroundStyle paperStyle,
  }) onCreate;

  const CreateNotebookDialog({
    super.key,
    required this.folders,
    this.initialFolderId,
    required this.onCreate,
  });

  @override
  State<CreateNotebookDialog> createState() => _CreateNotebookDialogState();
}

class _CreateNotebookDialogState extends State<CreateNotebookDialog> {
  final _titleController = TextEditingController();
  String? _selectedFolderId;
  int _selectedColor = AppColors.folderColors.first.toARGB32();
  PaperBackgroundStyle _selectedStyle = PaperBackgroundStyle.ruled;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('បង្កើតសៀវភៅកត់ត្រាថ្មី'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'ចំណងជើងមេរៀន / សៀវភៅ',
                hintText: 'ឧ. មេរៀនទី ២៖ ប្រព័ន្ធសមីការ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'ដាក់ក្នុង Folder',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedFolderId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('មិនដាក់ក្នុង Folder (ទូទៅ)'),
                    ),
                    ...widget.folders.map(
                      (f) => DropdownMenuItem<String?>(
                        value: f.id,
                        child: Text(f.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedFolderId = val),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'ប្រភេទក្រដាស (Paper Style)៖',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PaperBackgroundStyle>(
              segments: const [
                ButtonSegment(
                  value: PaperBackgroundStyle.ruled,
                  label: Text('បន្ទាត់'),
                  icon: Icon(Icons.format_align_justify),
                ),
                ButtonSegment(
                  value: PaperBackgroundStyle.grid,
                  label: Text('ក្រឡា'),
                  icon: Icon(Icons.grid_on),
                ),
                ButtonSegment(
                  value: PaperBackgroundStyle.blank,
                  label: Text('ទទេ'),
                  icon: Icon(Icons.crop_portrait),
                ),
              ],
              selected: {_selectedStyle},
              onSelectionChanged: (s) =>
                  setState(() => _selectedStyle = s.first),
            ),
            const SizedBox(height: 14),
            const Text(
              'ពណ៌គម្របសៀវភៅ៖',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: AppColors.folderColors.map((color) {
                final value = color.toARGB32();
                final isSelected = value == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = value),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: color,
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('បោះបង់'),
        ),
        FilledButton(
          onPressed: () async {
            final title = _titleController.text.trim().isEmpty
                ? 'សៀវភៅកត់ត្រាថ្មី'
                : _titleController.text.trim();
            await widget.onCreate(
              title: title,
              folderId: _selectedFolderId,
              coverColorValue: _selectedColor,
              paperStyle: _selectedStyle,
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('បង្កើត និងចូលសរសេរ'),
        ),
      ],
    );
  }
}
