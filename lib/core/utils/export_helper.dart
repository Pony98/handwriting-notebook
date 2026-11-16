import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ExportHelper {
  ExportHelper._();

  /// Captures a RepaintBoundary (the virtual page canvas) as PNG bytes
  static Future<Uint8List?> capturePagePng(GlobalKey boundaryKey) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Exports captured page as PNG to Gallery or Share sheet
  static Future<void> exportAsImage({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required String title,
  }) async {
    final pngBytes = await capturePagePng(boundaryKey);
    if (pngBytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final safeName = title.replaceAll(RegExp(r'[^\w\s-]'), '_');
    final file = File('${tempDir.path}/${safeName}_page.png');
    await file.writeAsBytes(pngBytes);

    try {
      await Gal.putImage(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('បានរក្សាទុករូបភាពចូលក្នុងទូរស័ព្ទរួចរាល់!'),
          ),
        );
      }
    } catch (_) {
      // Fallback to share sheet if gallery permission isn't available on desktop/emulator
      await Share.shareXFiles([XFile(file.path)], text: title);
    }
  }

  /// Exports captured page as PDF document via Printing/Share preview
  static Future<void> exportAsPdf({
    required GlobalKey boundaryKey,
    required String title,
  }) async {
    final pngBytes = await capturePagePng(boundaryKey);
    if (pngBytes == null) return;

    final pdf = pw.Document();
    final pdfImage = pw.MemoryImage(pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context ctx) {
          return pw.Center(
            child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: '$title.pdf',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
