import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/services/local_storage_service.dart';
import '../models/note_page_model.dart';
import '../models/notebook_model.dart';
import 'folder_provider.dart';

class NotebookListNotifier extends Notifier<List<NotebookModel>> {
  static const _uuid = Uuid();

  @override
  List<NotebookModel> build() {
    return LocalStorageService.getAllNotebooks();
  }

  Future<NotebookModel> createNotebook({
    required String title,
    String? folderId,
    required int coverColorValue,
    PaperBackgroundStyle initialPaperStyle = PaperBackgroundStyle.ruled,
  }) async {
    final now = DateTime.now();
    final notebook = NotebookModel(
      id: _uuid.v4(),
      folderId: folderId,
      title: title.trim(),
      coverColorValue: coverColorValue,
      pages: [
        NotePageModel(
          id: _uuid.v4(),
          backgroundStyle: initialPaperStyle,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await LocalStorageService.saveNotebook(notebook);
    state = LocalStorageService.getAllNotebooks();
    return notebook;
  }

  Future<void> updateNotebook(NotebookModel updated) async {
    final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
    await LocalStorageService.saveNotebook(withTimestamp);
    state = LocalStorageService.getAllNotebooks();
  }

  Future<void> deleteNotebook(String id) async {
    await LocalStorageService.deleteNotebook(id);
    state = LocalStorageService.getAllNotebooks();
  }

  void refresh() {
    state = LocalStorageService.getAllNotebooks();
  }
}

final notebookListProvider =
    NotifierProvider<NotebookListNotifier, List<NotebookModel>>(
  NotebookListNotifier.new,
);

/// Filtered notebooks according to selected folder
final filteredNotebooksProvider = Provider<List<NotebookModel>>((ref) {
  final allNotebooks = ref.watch(notebookListProvider);
  final selectedFolderId = ref.watch(selectedFolderIdProvider);
  if (selectedFolderId == null) {
    return allNotebooks;
  }
  return allNotebooks.where((n) => n.folderId == selectedFolderId).toList();
});
