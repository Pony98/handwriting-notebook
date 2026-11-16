import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/services/local_storage_service.dart';
import '../models/folder_model.dart';

/// Selected folder filter on Home Screen (`null` means show all / root view)
final selectedFolderIdProvider = StateProvider<String?>((ref) => null);

class FolderListNotifier extends Notifier<List<FolderModel>> {
  static const _uuid = Uuid();

  @override
  List<FolderModel> build() {
    return LocalStorageService.getAllFolders();
  }

  Future<void> createFolder({
    required String name,
    required int colorValue,
  }) async {
    final folder = FolderModel(
      id: _uuid.v4(),
      name: name.trim(),
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );
    await LocalStorageService.saveFolder(folder);
    state = LocalStorageService.getAllFolders();
  }

  Future<void> renameFolder(String id, String newName) async {
    final index = state.indexWhere((f) => f.id == id);
    if (index == -1) return;
    final updated = state[index].copyWith(name: newName.trim());
    await LocalStorageService.saveFolder(updated);
    state = LocalStorageService.getAllFolders();
  }

  Future<void> deleteFolder(String id) async {
    await LocalStorageService.deleteFolder(id);
    if (ref.read(selectedFolderIdProvider) == id) {
      ref.read(selectedFolderIdProvider.notifier).state = null;
    }
    state = LocalStorageService.getAllFolders();
  }
}

final folderListProvider =
    NotifierProvider<FolderListNotifier, List<FolderModel>>(
  FolderListNotifier.new,
);
