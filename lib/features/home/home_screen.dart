import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notebook_model.dart';
import '../../providers/folder_provider.dart';
import '../../providers/notebook_provider.dart';
import '../workspace/workspace_screen.dart';
import 'widgets/create_dialog.dart';
import 'widgets/folder_card.dart';
import 'widgets/notebook_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderListProvider);
    final allNotebooks = ref.watch(notebookListProvider);
    final filteredNotebooks = ref.watch(filteredNotebooksProvider);
    final selectedFolderId = ref.watch(selectedFolderIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.draw_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text(
              'សៀវភៅកត់ត្រាដៃ (Smart Notes)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showCreateFolderDialog(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: const Text('បង្កើត Folder'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Folders Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ថតឯកសារមេរៀន (Folders)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (selectedFolderId != null)
                    TextButton(
                      onPressed: () => ref
                          .read(selectedFolderIdProvider.notifier)
                          .state = null,
                      child: const Text('បង្ហាញសៀវភៅទាំងអស់'),
                    ),
                ],
              ),
            ),
          ),

          // 2. Horizontal Folders List
          SliverToBoxAdapter(
            child: SizedBox(
              height: 112,
              child: folders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: () => _showCreateFolderDialog(context, ref),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              '+ ចុចទីនេះដើម្បីបង្កើត Folder សម្រាប់រៀបចំមេរៀន',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: folders.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final count = allNotebooks
                            .where((n) => n.folderId == folder.id)
                            .length;
                        final isSelected = selectedFolderId == folder.id;

                        return FolderCard(
                          folder: folder,
                          isSelected: isSelected,
                          notebookCount: count,
                          onTap: () {
                            ref.read(selectedFolderIdProvider.notifier).state =
                                isSelected ? null : folder.id;
                          },
                          onDelete: () => ref
                              .read(folderListProvider.notifier)
                              .deleteFolder(folder.id),
                        );
                      },
                    ),
            ),
          ),

          // 3. Notebooks Grid Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
              child: Row(
                children: [
                  Text(
                    selectedFolderId == null
                        ? 'សៀវភៅកត់ត្រាទាំងអស់ (${filteredNotebooks.length})'
                        : 'សៀវភៅក្នុង Folder (${filteredNotebooks.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Notebooks GridView
          if (filteredNotebooks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 52,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'មិនទាន់មានសៀវភៅកត់ត្រាទេ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ចុចប៊ូតុង "សន្លឹកកិច្ចការថ្មី" នៅខាងក្រោមដើម្បីចាប់ផ្តើមសរសេរដៃ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final notebook = filteredNotebooks[index];
                    final folder = folders
                        .where((f) => f.id == notebook.folderId)
                        .firstOrNull;

                    return NotebookCard(
                      notebook: notebook,
                      folderName: folder?.name,
                      onTap: () => _openNotebook(context, notebook),
                      onDelete: () => ref
                          .read(notebookListProvider.notifier)
                          .deleteNotebook(notebook.id),
                    );
                  },
                  childCount: filteredNotebooks.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateNotebookDialog(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'សន្លឹកកិច្ចការថ្មី',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => CreateFolderDialog(
        onCreate: (name, colorValue) => ref
            .read(folderListProvider.notifier)
            .createFolder(name: name, colorValue: colorValue),
      ),
    );
  }

  void _showCreateNotebookDialog(BuildContext context, WidgetRef ref) {
    final folders = ref.read(folderListProvider);
    final selectedFolderId = ref.read(selectedFolderIdProvider);

    showDialog(
      context: context,
      builder: (_) => CreateNotebookDialog(
        folders: folders,
        initialFolderId: selectedFolderId,
        onCreate: ({
          required title,
          folderId,
          required coverColorValue,
          required paperStyle,
        }) async {
          final created =
              await ref.read(notebookListProvider.notifier).createNotebook(
                    title: title,
                    folderId: folderId,
                    coverColorValue: coverColorValue,
                    initialPaperStyle: paperStyle,
                  );
          if (context.mounted) {
            _openNotebook(context, created);
          }
        },
      ),
    );
  }

  void _openNotebook(BuildContext context, NotebookModel notebook) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkspaceScreen(initialNotebook: notebook),
      ),
    );
  }
}
