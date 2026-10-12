import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf show PdfPageFormat;
import 'package:printing/printing.dart' show Printing;

/// Shows the operating system's print dialog for a PDF whose pages are
/// [width] × [height] points. Completes with false when the user cancels.
typedef StudioPrinter =
    Future<bool> Function(
      Uint8List document, {
      required String name,
      required double width,
      required double height,
    });

/// Printing through the platform's native dialog (GTK on Linux, the Windows
/// print dialog, and the macOS print panel), where the user picks the
/// printer, copies, and page range.
abstract final class StudioPrinting {
  /// The default [StudioPrinter].
  static Future<bool> system(
    Uint8List document, {
    required String name,
    required double width,
    required double height,
  }) => Printing.layoutPdf(
    onLayout: (_) => document,
    name: name,
    format: pdf.PdfPageFormat(width, height),
    dynamicLayout: false,
  );
}
