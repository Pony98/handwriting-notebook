class FolderModel {
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;

  const FolderModel({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  FolderModel copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FolderModel.fromMap(Map<dynamic, dynamic> map) {
    return FolderModel(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['colorValue'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
