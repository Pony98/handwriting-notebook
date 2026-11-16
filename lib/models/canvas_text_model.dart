class CanvasTextModel {
  final String id;
  final String text;
  final double x;
  final double y;
  final double fontSize;
  final int colorValue;
  final int fontWeightIndex;

  const CanvasTextModel({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.fontSize,
    required this.colorValue,
    this.fontWeightIndex = 5, // FontWeight.w600
  });

  CanvasTextModel copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    double? fontSize,
    int? colorValue,
    int? fontWeightIndex,
  }) {
    return CanvasTextModel(
      id: id ?? this.id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      fontWeightIndex: fontWeightIndex ?? this.fontWeightIndex,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'fontSize': fontSize,
        'colorValue': colorValue,
        'fontWeightIndex': fontWeightIndex,
      };

  factory CanvasTextModel.fromMap(Map<dynamic, dynamic> map) {
    return CanvasTextModel(
      id: map['id'] as String,
      text: map['text'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 20.0,
      colorValue: map['colorValue'] as int? ?? 0xFF0F172A,
      fontWeightIndex: map['fontWeightIndex'] as int? ?? 5,
    );
  }
}
