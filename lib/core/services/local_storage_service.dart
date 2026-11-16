import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../models/folder_model.dart';
import '../../models/note_page_model.dart';
import '../../models/notebook_model.dart';
import '../constants/app_colors.dart';

class LocalStorageService {
  static const String _foldersBoxName = 'folders_box';
  static const String _notebooksBoxName = 'notebooks_box';

  static late Box<Map<dynamic, dynamic>> _foldersBox;
  static late Box<Map<dynamic, dynamic>> _notebooksBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _foldersBox = await Hive.openBox<Map<dynamic, dynamic>>(_foldersBoxName);
    _notebooksBox = await Hive.openBox<Map<dynamic, dynamic>>(_notebooksBoxName);

    // Seed sample data on first launch if completely empty
    if (_foldersBox.isEmpty && _notebooksBox.isEmpty) {
      await _seedInitialData();
    }
  }

  static Future<void> _seedInitialData() async {
    final now = DateTime.now();
    final sampleFolder = FolderModel(
      id: 'folder-default-1',
      name: 'មេរៀន Flutter & Dart',
      colorValue: AppColors.folderColors[0].toARGB32(),
      createdAt: now,
    );
    await saveFolder(sampleFolder);

    final sampleNotebook = NotebookModel(
      id: 'notebook-default-1',
      folderId: sampleFolder.id,
      title: 'កំណត់ត្រាមេរៀនទី ១',
      coverColorValue: AppColors.folderColors[0].toARGB32(),
      pages: const [
        NotePageModel(
          id: 'page-1',
          backgroundStyle: PaperBackgroundStyle.ruled,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await saveNotebook(sampleNotebook);
  }

  // ---------------- FOLDERS ----------------

  static List<FolderModel> getAllFolders() {
    final folders = _foldersBox.values
        .map((map) => FolderModel.fromMap(map))
        .toList();
    folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return folders;
  }

  static Future<void> saveFolder(FolderModel folder) async {
    await _foldersBox.put(folder.id, folder.toMap());
  }

  static Future<void> deleteFolder(String folderId) async {
    await _foldersBox.delete(folderId);
    // Unassign notebooks inside this folder so they aren't lost
    final notebooks = getAllNotebooks();
    for (final nb in notebooks) {
      if (nb.folderId == folderId) {
        await saveNotebook(nb.copyWith(clearFolderId: true));
      }
    }
  }

  // ---------------- NOTEBOOKS ----------------

  static List<NotebookModel> getAllNotebooks() {
    final notebooks = _notebooksBox.values
        .map((map) => NotebookModel.fromMap(map))
        .toList();
    notebooks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notebooks;
  }

  static Future<void> saveNotebook(NotebookModel notebook) async {
    await _notebooksBox.put(notebook.id, notebook.toMap());
  }

  static Future<void> deleteNotebook(String notebookId) async {
    await _notebooksBox.delete(notebookId);
  }
}
