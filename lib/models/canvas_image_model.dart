class CanvasImageModel {
  final String id;
  final String imagePath;
  final double x;
  final double y;
  final double width;
  final double height;

  const CanvasImageModel({
    required this.id,
    required this.imagePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  CanvasImageModel copyWith({
    String? id,
    String? imagePath,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return CanvasImageModel(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'imagePath': imagePath,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory CanvasImageModel.fromMap(Map<dynamic, dynamic> map) {
    return CanvasImageModel(
      id: map['id'] as String,
      imagePath: map['imagePath'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
    );
  }
}
