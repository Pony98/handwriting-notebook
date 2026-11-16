import 'canvas_image_model.dart';
import 'canvas_text_model.dart';
import 'stroke_model.dart';

enum PaperBackgroundStyle {
  blank,
  ruled,
  grid,
}

class NotePageModel {
  final String id;
  final PaperBackgroundStyle backgroundStyle;
  final List<StrokeModel> strokes;
  final List<CanvasTextModel> texts;
  final List<CanvasImageModel> images;

  const NotePageModel({
    required this.id,
    this.backgroundStyle = PaperBackgroundStyle.ruled,
    this.strokes = const [],
    this.texts = const [],
    this.images = const [],
  });

  NotePageModel copyWith({
    String? id,
    PaperBackgroundStyle? backgroundStyle,
    List<StrokeModel>? strokes,
    List<CanvasTextModel>? texts,
    List<CanvasImageModel>? images,
  }) {
    return NotePageModel(
      id: id ?? this.id,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      strokes: strokes ?? this.strokes,
      texts: texts ?? this.texts,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'backgroundStyle': backgroundStyle.name,
        'strokes': strokes.map((s) => s.toMap()).toList(),
        'texts': texts.map((t) => t.toMap()).toList(),
        'images': images.map((img) => img.toMap()).toList(),
      };

  factory NotePageModel.fromMap(Map<dynamic, dynamic> map) {
    final rawStrokes = (map['strokes'] as List<dynamic>? ?? []);
    final rawTexts = (map['texts'] as List<dynamic>? ?? []);
    final rawImages = (map['images'] as List<dynamic>? ?? []);
    return NotePageModel(
      id: map['id'] as String,
      backgroundStyle: PaperBackgroundStyle.values.firstWhere(
        (e) => e.name == map['backgroundStyle'],
        orElse: () => PaperBackgroundStyle.ruled,
      ),
      strokes: rawStrokes
          .map((s) => StrokeModel.fromMap(Map<dynamic, dynamic>.from(s as Map)))
          .toList(),
      texts: rawTexts
          .map((t) =>
              CanvasTextModel.fromMap(Map<dynamic, dynamic>.from(t as Map)))
          .toList(),
      images: rawImages
          .map((i) =>
              CanvasImageModel.fromMap(Map<dynamic, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}
