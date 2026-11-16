import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

  /// Exports captured page as PNG image
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

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: '$title (PNG)',
    );
  }

  /// Exports captured page as A4 PDF document
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

    final pdfBytes = await pdf.save();
    final tempDir = await getTemporaryDirectory();
    final safeName = title.replaceAll(RegExp(r'[^\w\s-]'), '_');
    final file = File('${tempDir.path}/${safeName}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: '$title (PDF)',
    );
  }
}
