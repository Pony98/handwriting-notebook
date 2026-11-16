enum DrawingToolType {
  pen,
  highlighter,
  eraser,
}

class StrokePoint {
  final double x;
  final double y;
  final double pressure;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
  });

  Map<String, dynamic> toMap() => {
        'x': x,
        'y': y,
        'p': pressure,
      };

  factory StrokePoint.fromMap(Map<dynamic, dynamic> map) {
    return StrokePoint(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      pressure: (map['p'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class StrokeModel {
  final List<StrokePoint> points;
  final int colorValue;
  final double strokeWidth;
  final DrawingToolType toolType;

  const StrokeModel({
    required this.points,
    required this.colorValue,
    required this.strokeWidth,
    required this.toolType,
  });

  StrokeModel copyWith({
    List<StrokePoint>? points,
    int? colorValue,
    double? strokeWidth,
    DrawingToolType? toolType,
  }) {
    return StrokeModel(
      points: points ?? this.points,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      toolType: toolType ?? this.toolType,
    );
  }

  Map<String, dynamic> toMap() => {
        'points': points.map((p) => p.toMap()).toList(),
        'colorValue': colorValue,
        'strokeWidth': strokeWidth,
        'toolType': toolType.name,
      };

  factory StrokeModel.fromMap(Map<dynamic, dynamic> map) {
    final rawPoints = (map['points'] as List<dynamic>? ?? []);
    return StrokeModel(
      points: rawPoints
          .map((p) => StrokePoint.fromMap(Map<dynamic, dynamic>.from(p as Map)))
          .toList(),
      colorValue: map['colorValue'] as int,
      strokeWidth: (map['strokeWidth'] as num).toDouble(),
      toolType: DrawingToolType.values.firstWhere(
        (e) => e.name == map['toolType'],
        orElse: () => DrawingToolType.pen,
      ),
    );
  }
}
