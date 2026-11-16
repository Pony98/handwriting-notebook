import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../../models/stroke_model.dart';

enum RecognitionLanguage {
  chinese('zh-CN', 'ចិន (中文)'),
  khmer('km', 'ខ្មែរ (Khmer)'),
  english('en', 'អង់គ្លេស (EN)');

  final String code;
  final String label;
  const RecognitionLanguage(this.code, this.label);
}

enum StrokePrimitive {
  heng('横 (ដេក →)'),
  hengBackwards('ដេកបញ្ច្រាស (← ខុស)'),
  shu('竖 (ឈរ ↓)'),
  shuBackwards('ឈរបញ្ច្រាស (↑ ខុស)'),
  pie('撇 (ទាញឆ្វេង ↙)'),
  na('捺 (ទាញស្តាំ ↘)'),
  ti('提 (វាត់ឡើង ↗)'),
  dian('点 (ចំណុច)'),
  zhe('折/钩 (បត់/ទំពក់)'),
  scribble('គូសវាសមិនត្រឹមត្រូវ');

  final String label;
  const StrokePrimitive(this.label);
}

class ChineseStrokeRule {
  final int strokeCount;
  final String strokeOrderHint;
  final List<StrokePrimitive>? requiredPrefix;

  const ChineseStrokeRule({
    required this.strokeCount,
    required this.strokeOrderHint,
    this.requiredPrefix,
  });
}

class HandwritingValidationResult {
  final bool isValid;
  final String? recognizedText;
  final List<String> candidates;
  final String feedbackMessage;
  final List<StrokePrimitive> detectedPrimitives;

  const HandwritingValidationResult({
    required this.isValid,
    this.recognizedText,
    this.candidates = const [],
    required this.feedbackMessage,
    this.detectedPrimitives = const [],
  });
}

class HandwritingRecognizer {
  HandwritingRecognizer._();

  /// Built-in Standard Chinese Stroke Count & Stroke Order Rules
  static const Map<String, ChineseStrokeRule> _chineseRules = {
    '一': ChineseStrokeRule(
      strokeCount: 1,
      strokeOrderHint: '横 (គូសដេកពីឆ្វេងទៅស្តាំ →)',
      requiredPrefix: [StrokePrimitive.heng],
    ),
    '二': ChineseStrokeRule(
      strokeCount: 2,
      strokeOrderHint: '横 ➔ 横 (គូសបន្ទាត់ដេកខាងលើមុន រួចបន្ទាត់ដេកខាងក្រោម)',
      requiredPrefix: [StrokePrimitive.heng, StrokePrimitive.heng],
    ),
    '三': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '横 ➔ 横 ➔ 横 (គូសដេកពីលើចុះក្រោម ៣ បន្ទាត់)',
      requiredPrefix: [
        StrokePrimitive.heng,
        StrokePrimitive.heng,
        StrokePrimitive.heng,
      ],
    ),
    '十': ChineseStrokeRule(
      strokeCount: 2,
      strokeOrderHint: '横 ➔ 竖 (គូសបន្ទាត់ដេក → មុន រួចគូសបន្ទាត់ឈរ ↓)',
      requiredPrefix: [StrokePrimitive.heng, StrokePrimitive.shu],
    ),
    '人': ChineseStrokeRule(
      strokeCount: 2,
      strokeOrderHint: '撇 ➔ 捺 (គូសទាញមកឆ្វេង ↙ មុន រួចទាញទៅស្តាំ ↘)',
      requiredPrefix: [StrokePrimitive.pie, StrokePrimitive.na],
    ),
    '八': ChineseStrokeRule(
      strokeCount: 2,
      strokeOrderHint: '撇 ➔ 捺 (គូសឆ្វេង ↙ មុន រួចស្តាំ ↘)',
    ),
    '入': ChineseStrokeRule(
      strokeCount: 2,
      strokeOrderHint: '撇 ➔ 捺 (២ Strokes)',
    ),
    '大': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '横 ➔ 撇 ➔ 捺 (ដេក ➔ ទាញឆ្វេង ➔ ទាញស្តាំ)',
      requiredPrefix: [StrokePrimitive.heng, StrokePrimitive.pie],
    ),
    '天': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '横 ➔ 横 ➔ 撇 ➔ 捺 (៤ Strokes)',
      requiredPrefix: [StrokePrimitive.heng, StrokePrimitive.heng],
    ),
    '口': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '竖 ➔ 横折 ➔ 横 (ឈរឆ្វេង ➔ ដេកបត់ចុះស្តាំ ➔ បិទបាតក្រោម)',
      requiredPrefix: [StrokePrimitive.shu, StrokePrimitive.zhe],
    ),
    '日': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '竖 ➔ 横折 ➔ 横 ➔ 横 (៤ Strokes)',
      requiredPrefix: [StrokePrimitive.shu, StrokePrimitive.zhe],
    ),
    '月': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '撇 ➔ 横折钩 ➔ 横 ➔ 横 (៤ Strokes)',
    ),
    '田': ChineseStrokeRule(
      strokeCount: 5,
      strokeOrderHint: '竖 ➔ 横折 ➔ 横 ➔ 竖 ➔ 横 (៥ Strokes)',
    ),
    '目': ChineseStrokeRule(
      strokeCount: 5,
      strokeOrderHint: '竖 ➔ 横折 ➔ 横 ➔ 横 ➔ 横 (៥ Strokes)',
    ),
    '山': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '竖 ➔ 竖折 ➔ 竖 (៣ Strokes)',
    ),
    '中': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '竖 ➔ 横折 ➔ 横 ➔ 竖 (៤ Strokes)',
      requiredPrefix: [StrokePrimitive.shu, StrokePrimitive.zhe],
    ),
    '土': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '横 ➔ 竖 ➔ 横 (ដេក ➔ ឈរ ➔ ដេកបាតក្រោម)',
      requiredPrefix: [StrokePrimitive.heng, StrokePrimitive.shu],
    ),
    '王': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '横 ➔ 横 ➔ 竖 ➔ 横 (៤ Strokes)',
    ),
    '木': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '横 ➔ 竖 ➔ 撇 ➔ 捺 (៤ Strokes)',
      requiredPrefix: [StrokePrimitive.heng, StrokePrimitive.shu],
    ),
    '水': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '竖钩 ➔ 横撇 ➔ 撇 ➔ 捺 (៤ Strokes)',
    ),
    '火': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '点 ➔ 撇 ➔ 撇 ➔ 捺 (៤ Strokes)',
    ),
    '小': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '竖钩 ➔ 撇 ➔ 点 (៣ Strokes)',
    ),
    '上': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '竖 ➔ 横 ➔ 横 (៣ Strokes)',
    ),
    '下': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '横 ➔ 竖 ➔ 点 (៣ Strokes)',
      requiredPrefix: [StrokePrimitive.heng, StrokePrimitive.shu],
    ),
    '女': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '撇点 ➔ 撇 ➔ 横 (៣ Strokes)',
    ),
    '子': ChineseStrokeRule(
      strokeCount: 3,
      strokeOrderHint: '横撇 ➔ 弯钩 ➔ 横 (៣ Strokes)',
    ),
    '好': ChineseStrokeRule(
      strokeCount: 6,
      strokeOrderHint: '女 (៣ Strokes) + 子 (៣ Strokes) = ៦ Strokes',
    ),
    '不': ChineseStrokeRule(
      strokeCount: 4,
      strokeOrderHint: '横 ➔ 撇 ➔ 竖 ➔ 点 (៤ Strokes)',
    ),
    '我': ChineseStrokeRule(
      strokeCount: 7,
      strokeOrderHint: '撇 ➔ 横 ➔ 竖钩 ➔ 提 ➔ 斜钩 ➔ 撇 ➔ 点 (៧ Strokes)',
    ),
    '你': ChineseStrokeRule(
      strokeCount: 7,
      strokeOrderHint: '撇 ➔ 竖 ➔ 撇 ➔ 横钩 ➔ 竖钩 ➔ 撇 ➔ 点 (៧ Strokes)',
    ),
    '学': ChineseStrokeRule(
      strokeCount: 8,
      strokeOrderHint: '点 ➔ 点 ➔ 撇 ➔ 点 ➔ 横钩 ➔ 横撇 ➔ 弯钩 ➔ 横 (៨ Strokes)',
    ),
    '生': ChineseStrokeRule(
      strokeCount: 5,
      strokeOrderHint: '撇 ➔ 横 ➔ 横 ➔ 竖 ➔ 横 (៥ Strokes)',
    ),
    '国': ChineseStrokeRule(
      strokeCount: 8,
      strokeOrderHint: '竖 ➔ 横折 ➔ 王 (៤ Strokes) ➔ 点 ➔ 横 (៨ Strokes)',
    ),
  };

  /// Analyzes a single stroke's geometry to determine its stroke primitive and check for backwards strokes
  static StrokePrimitive classifyStroke(StrokeModel stroke) {
    final pts = stroke.points;
    if (pts.length < 2) return StrokePrimitive.dian;

    final start = pts.first;
    final end = pts.last;
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final netDist = math.sqrt(dx * dx + dy * dy);

    double pathLength = 0.0;
    double minX = start.x, maxX = start.x;
    double minY = start.y, maxY = start.y;

    for (int i = 1; i < pts.length; i++) {
      final segDx = pts[i].x - pts[i - 1].x;
      final segDy = pts[i].y - pts[i - 1].y;
      pathLength += math.sqrt(segDx * segDx + segDy * segDy);
      minX = math.min(minX, pts[i].x);
      maxX = math.max(maxX, pts[i].x);
      minY = math.min(minY, pts[i].y);
      maxY = math.max(maxY, pts[i].y);
    }

    final bboxDiag =
        math.sqrt(math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2));

    // 1. Check for chaotic scribble (excessive winding compared to bounding box)
    if (bboxDiag > 25 && pathLength > bboxDiag * 4.8) {
      return StrokePrimitive.scribble;
    }

    // 2. Short stroke = Dot (点)
    if (pathLength < 28 && bboxDiag < 24) {
      return StrokePrimitive.dian;
    }

    // 3. Compound turning stroke (折/钩): pathLength is significantly longer than straight-line distance
    if (netDist < pathLength * 0.76 && bboxDiag > 26) {
      return StrokePrimitive.zhe;
    }

    // 4. Straight stroke angle in degrees (-180 to +180, where 0 is Right, 90 is Down)
    final angleDeg = math.atan2(dy, dx) * 180.0 / math.pi;

    // Horizontal Left -> Right (-26° to +26°)
    if (angleDeg >= -26 && angleDeg <= 26) {
      return StrokePrimitive.heng;
    }
    // Backwards Horizontal Right -> Left (> 154° or < -154°)
    if (angleDeg >= 154 || angleDeg <= -154) {
      return StrokePrimitive.hengBackwards;
    }
    // Vertical Top -> Bottom (64° to 116°)
    if (angleDeg >= 64 && angleDeg <= 116) {
      return StrokePrimitive.shu;
    }
    // Backwards Vertical Bottom -> Top (-116° to -64°)
    if (angleDeg >= -116 && angleDeg <= -64) {
      return StrokePrimitive.shuBackwards;
    }
    // Slanted Top-Right -> Bottom-Left (116° to 154°) = 撇 (Piě)
    if (angleDeg > 116 && angleDeg < 154) {
      return StrokePrimitive.pie;
    }
    // Slanted Top-Left -> Bottom-Right (26° to 64°) = 捺 (Nà)
    if (angleDeg > 26 && angleDeg < 64) {
      return StrokePrimitive.na;
    }
    // Rising Bottom-Left -> Top-Right (-64° to -26°) = 提 (Tí)
    if (angleDeg > -64 && angleDeg < -26) {
      return StrokePrimitive.ti;
    }

    return StrokePrimitive.zhe;
  }

  /// Validates strokes and recognizes the printed character(s)
  static Future<HandwritingValidationResult> validateAndRecognize({
    required List<StrokeModel> strokes,
    required RecognitionLanguage language,
    required bool strictStrokeValidation,
  }) async {
    if (strokes.isEmpty) {
      return const HandwritingValidationResult(
        isValid: false,
        feedbackMessage: 'សូមសរសេរអក្សរជាមុនសិន',
      );
    }

    final primitives = strokes.map(classifyStroke).toList();

    // 1. Always reject chaotic scribbles
    if (primitives.contains(StrokePrimitive.scribble)) {
      return HandwritingValidationResult(
        isValid: false,
        detectedPrimitives: primitives,
        feedbackMessage:
            '❌ គូសវាសមិនត្រឹមត្រូវតាមទម្រង់អក្សរ! សូមសរសេរតាម Stroke ឲ្យច្បាស់លាស់។',
      );
    }

    // 2. Strict Stroke Direction & Order validation (especially for Chinese / Structured Stroke mode)
    if (strictStrokeValidation) {
      for (int i = 0; i < primitives.length; i++) {
        final p = primitives[i];
        if (p == StrokePrimitive.hengBackwards) {
          return HandwritingValidationResult(
            isValid: false,
            detectedPrimitives: primitives,
            feedbackMessage:
                '❌ ខុសទិសដៅ Stroke ទី ${i + 1}៖ បន្ទាត់ដេក (横) ត្រូវគូសពីឆ្វេងទៅស្តាំ (→) មិនមែនពីស្តាំមកឆ្វេងទេ!',
          );
        }
        if (p == StrokePrimitive.shuBackwards) {
          return HandwritingValidationResult(
            isValid: false,
            detectedPrimitives: primitives,
            feedbackMessage:
                '❌ ខុសទិសដៅ Stroke ទី ${i + 1}៖ បន្ទាត់ឈរ (竖) ត្រូវគូសពីលើចុះក្រោម (↓) មិនមែនពីក្រោមឡើងលើទេ!',
          );
        }
      }

      // Check top-to-bottom ordering for parallel horizontal strokes (e.g. 二, 三)
      if (primitives.length >= 2 &&
          primitives.every((p) => p == StrokePrimitive.heng)) {
        for (int i = 1; i < strokes.length; i++) {
          final prevY = strokes[i - 1].points.first.y;
          final currY = strokes[i].points.first.y;
          if (currY < prevY - 12.0) {
            return HandwritingValidationResult(
              isValid: false,
              detectedPrimitives: primitives,
              feedbackMessage:
                  '❌ ខុសលំដាប់ Stroke៖ ត្រូវសរសេរបន្ទាត់ខាងលើមុន រួចទើបសរសេរបន្ទាត់ខាងក្រោម (ពីលើចុះក្រោម ↓)!',
            );
          }
        }
      }
    }

    // 3. Query Google InputTools Handwriting API + Offline geometric fallback
    List<String> candidates = await _recognizeViaGoogleApi(strokes, language);
    if (candidates.isEmpty) {
      final offlineGuess = _offlineGeometricRecognize(strokes, primitives);
      if (offlineGuess != null) {
        candidates = [offlineGuess];
      }
    }

    if (candidates.isEmpty) {
      return HandwritingValidationResult(
        isValid: false,
        detectedPrimitives: primitives,
        feedbackMessage:
            '❌ មិនអាចសម្គាល់ទម្រង់អក្សរបានទេ! សូមសរសេរឲ្យត្រូវតាមទម្រង់អក្សរ។',
      );
    }

    final bestChar = candidates.first.trim();

    // 4. If strict validation is enabled and the character is in our Chinese Stroke Dictionary,
    // verify stroke count and stroke order prefix!
    if (strictStrokeValidation && _chineseRules.containsKey(bestChar)) {
      final rule = _chineseRules[bestChar]!;
      if (strokes.length != rule.strokeCount) {
        return HandwritingValidationResult(
          isValid: false,
          candidates: candidates,
          detectedPrimitives: primitives,
          feedbackMessage:
              '❌ អក្សរ «$bestChar» តម្រូវឲ្យសរសេរ ${rule.strokeCount} Strokes (${rule.strokeOrderHint}) តែអ្នកបានសរសេរ ${strokes.length} Stroke!',
        );
      }

      if (rule.requiredPrefix != null) {
        for (int i = 0;
            i < rule.requiredPrefix!.length && i < primitives.length;
            i++) {
          final expected = rule.requiredPrefix![i];
          final actual = primitives[i];
          if (actual != expected) {
            return HandwritingValidationResult(
              isValid: false,
              candidates: candidates,
              detectedPrimitives: primitives,
              feedbackMessage:
                  '❌ ខុសលំដាប់ Stroke អក្សរ «$bestChar»! លំដាប់ត្រឹមត្រូវគឺ៖ ${rule.strokeOrderHint}',
            );
          }
        }
      }
    }

    final primitiveSummary = primitives.map((p) => p.label.split(' ').first).join(' ➔ ');
    return HandwritingValidationResult(
      isValid: true,
      recognizedText: bestChar,
      candidates: candidates,
      detectedPrimitives: primitives,
      feedbackMessage:
          '✅ ត្រឹមត្រូវ៖ «$bestChar» (${strokes.length} Strokes: $primitiveSummary)',
    );
  }

  /// Calls Google InputTools Handwriting Recognition API
  static Future<List<String>> _recognizeViaGoogleApi(
    List<StrokeModel> strokes,
    RecognitionLanguage language,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final List<List<dynamic>> ink = [];
      int runningTimeMs = 0;

      for (final stroke in strokes) {
        final List<int> xs = [];
        final List<int> ys = [];
        final List<int> ts = [];
        for (final pt in stroke.points) {
          xs.add(pt.x.round());
          ys.add(pt.y.round());
          ts.add(runningTimeMs);
          runningTimeMs += 18;
        }
        runningTimeMs += 120;
        ink.add([xs, ys, ts]);
      }

      final payload = jsonEncode({
        'options': 'enable_pre_space',
        'requests': [
          {
            'writing_guide': {
              'writing_area_width': 600,
              'writing_area_height': 320,
            },
            'ink': ink,
            'language': language.code,
          }
        ]
      });

      final uri = Uri.parse(
        'https://inputtools.google.com/request?ime=handwriting&app=mobilesearch&cs=1&oe=UTF-8',
      );
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(payload));

      final resp = await req.close().timeout(const Duration(seconds: 4));
      if (resp.statusCode != 200) return const [];

      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is List &&
          decoded.length > 1 &&
          decoded[0] == 'SUCCESS' &&
          decoded[1] is List &&
          (decoded[1] as List).isNotEmpty) {
        final firstResult = decoded[1][0];
        if (firstResult is List &&
            firstResult.length > 1 &&
            firstResult[1] is List) {
          return (firstResult[1] as List)
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .take(6)
              .toList();
        }
      }
    } catch (_) {
      // Fallback to offline geometric matcher if network is unavailable
    } finally {
      client.close();
    }
    return const [];
  }

  /// Offline geometric recognizer for fundamental Chinese characters & symbols
  static String? _offlineGeometricRecognize(
    List<StrokeModel> strokes,
    List<StrokePrimitive> primitives,
  ) {
    if (primitives.length == 1) {
      if (primitives[0] == StrokePrimitive.heng) return '一';
      if (primitives[0] == StrokePrimitive.shu) return '1';
    } else if (primitives.length == 2) {
      if (primitives[0] == StrokePrimitive.heng &&
          primitives[1] == StrokePrimitive.heng) {
        return '二';
      }
      if (primitives[0] == StrokePrimitive.heng &&
          primitives[1] == StrokePrimitive.shu) {
        return '十';
      }
      if (primitives[0] == StrokePrimitive.pie &&
          primitives[1] == StrokePrimitive.na) {
        return '人';
      }
    } else if (primitives.length == 3) {
      if (primitives.every((p) => p == StrokePrimitive.heng)) {
        return '三';
      }
      if (primitives[0] == StrokePrimitive.heng &&
          primitives[1] == StrokePrimitive.pie &&
          primitives[2] == StrokePrimitive.na) {
        return '大';
      }
      if (primitives[0] == StrokePrimitive.shu &&
          primitives[1] == StrokePrimitive.zhe &&
          primitives[2] == StrokePrimitive.heng) {
        return '口';
      }
      if (primitives[0] == StrokePrimitive.heng &&
          primitives[1] == StrokePrimitive.shu &&
          primitives[2] == StrokePrimitive.heng) {
        return '土';
      }
    } else if (primitives.length == 4) {
      if (primitives[0] == StrokePrimitive.shu &&
          primitives[1] == StrokePrimitive.zhe &&
          primitives[2] == StrokePrimitive.heng &&
          primitives[3] == StrokePrimitive.shu) {
        return '中';
      }
      if (primitives[0] == StrokePrimitive.heng &&
          primitives[1] == StrokePrimitive.heng &&
          primitives[2] == StrokePrimitive.pie &&
          primitives[3] == StrokePrimitive.na) {
        return '天';
      }
      if (primitives[0] == StrokePrimitive.heng &&
          primitives[1] == StrokePrimitive.shu &&
          primitives[2] == StrokePrimitive.pie &&
          primitives[3] == StrokePrimitive.na) {
        return '木';
      }
    }
    return null;
  }
}
