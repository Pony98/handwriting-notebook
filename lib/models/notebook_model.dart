import 'note_page_model.dart';

class NotebookModel {
  final String id;
  final String? folderId;
  final String title;
  final int coverColorValue;
  final String? thumbnailPath;
  final List<NotePageModel> pages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotebookModel({
    required this.id,
    this.folderId,
    required this.title,
    required this.coverColorValue,
    this.thumbnailPath,
    required this.pages,
    required this.createdAt,
    required this.updatedAt,
  });

  NotebookModel copyWith({
    String? id,
    String? folderId,
    bool clearFolderId = false,
    String? title,
    int? coverColorValue,
    String? thumbnailPath,
    List<NotePageModel>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotebookModel(
      id: id ?? this.id,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      title: title ?? this.title,
      coverColorValue: coverColorValue ?? this.coverColorValue,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      pages: pages ?? this.pages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'folderId': folderId,
        'title': title,
        'coverColorValue': coverColorValue,
        'thumbnailPath': thumbnailPath,
        'pages': pages.map((p) => p.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NotebookModel.fromMap(Map<dynamic, dynamic> map) {
    final rawPages = (map['pages'] as List<dynamic>? ?? []);
    return NotebookModel(
      id: map['id'] as String,
      folderId: map['folderId'] as String?,
      title: map['title'] as String,
      coverColorValue: map['coverColorValue'] as int? ?? 0xFF2563EB,
      thumbnailPath: map['thumbnailPath'] as String?,
      pages: rawPages
          .map((p) =>
              NotePageModel.fromMap(Map<dynamic, dynamic>.from(p as Map)))
          .toList(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
