import 'package:flutter_test/flutter_test.dart';
import 'package:handwriting_notebook/models/note_page_model.dart';
import 'package:handwriting_notebook/models/notebook_model.dart';

void main() {
  test('NotebookModel serialization round-trip test', () {
    final now = DateTime(2026, 11, 16);
    final notebook = NotebookModel(
      id: 'nb-1',
      title: 'Test Notebook',
      coverColorValue: 0xFF2563EB,
      pages: const [
        NotePageModel(id: 'p-1', backgroundStyle: PaperBackgroundStyle.ruled),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final map = notebook.toMap();
    final restored = NotebookModel.fromMap(map);

    expect(restored.id, 'nb-1');
    expect(restored.title, 'Test Notebook');
    expect(restored.pages.length, 1);
  });
}
