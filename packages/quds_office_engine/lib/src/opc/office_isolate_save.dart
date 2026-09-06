import 'dart:isolate';
import 'dart:typed_data';

import '../sheet/model/sml_workbook.dart';
import '../sheet/serial/sheet_serial.dart';
import '../slide/model/pml_presentation.dart';
import '../slide/serial/slide_serial.dart';
import '../visual/office_visual.dart';
import '../word/model/wml_document.dart';
import '../word/serial/word_serializer.dart';
import 'opc_archive.dart';

/// Cost heuristics so hosts can offload ZIP/XML encoding off the UI isolate.
abstract final class OfficeSaveCost {
  static const int isolateThresholdBytes = 128 * 1024;
  static const int isolateThresholdParagraphs = 50;
  static const int isolateThresholdCells = 400;
  static const int isolateThresholdSlides = 8;

  static bool isHeavyPackage(OpcPackage? package) =>
      package != null && package.sourceLength >= isolateThresholdBytes;

  static bool isHeavyWord(WmlDocument document) {
    if (isHeavyPackage(document.package)) {
      return true;
    }
    var count = 0;
    var images = 0;
    for (final WmlParagraph _ in document.paragraphs) {
      count++;
      if (count >= isolateThresholdParagraphs) {
        return true;
      }
    }
    for (final WmlVisual visual in document.visuals) {
      images += visual.visual.imageBytes?.length ?? 0;
      if (images >= isolateThresholdBytes) {
        return true;
      }
    }
    return false;
  }

  static bool isHeavyWorkbook(SmlWorkbook workbook) {
    if (isHeavyPackage(workbook.package)) {
      return true;
    }
    var cells = 0;
    var images = 0;
    for (final SmlWorksheet sheet in workbook.sheets) {
      for (final SmlRow row in sheet.rows.values) {
        cells += row.cells.length;
        if (cells >= isolateThresholdCells) {
          return true;
        }
      }
      for (final SmlDrawing drawing in sheet.drawings) {
        images += drawing.visual.imageBytes?.length ?? 0;
        if (images >= isolateThresholdBytes) {
          return true;
        }
      }
    }
    var shared = 0;
    for (final String value in workbook.sharedStrings) {
      shared += value.length;
      if (shared >= 20000) {
        return true;
      }
    }
    return false;
  }

  static bool isHeavyPresentation(PmlPresentation presentation) {
    if (isHeavyPackage(presentation.package)) {
      return true;
    }
    if (presentation.slides.length >= isolateThresholdSlides) {
      return true;
    }
    var shapes = 0;
    var images = 0;
    for (final PmlSlide slide in presentation.slides) {
      shapes += slide.shapes.length;
      if (shapes >= 40) {
        return true;
      }
      for (final PmlShape shape in slide.shapes) {
        images += shape.visual?.imageBytes?.length ?? 0;
        if (images >= isolateThresholdBytes) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Encodes Office packages on a worker isolate so the UI isolate stays live.
abstract final class OfficeIsolateSave {
  static Future<Uint8List> word(
    WmlDocument document, {
    String? password,
  }) {
    final _WordSaveJob job = _WordSaveJob(document, password);
    return _run(() => _encodeWord(job));
  }

  static Future<Uint8List> workbook(
    SmlWorkbook workbook, {
    String? password,
  }) {
    final _SheetSaveJob job = _SheetSaveJob(workbook, password);
    return _run(() => _encodeWorkbook(job));
  }

  static Future<Uint8List> presentation(
    PmlPresentation presentation, {
    String? password,
  }) {
    final _SlideSaveJob job = _SlideSaveJob(presentation, password);
    return _run(() => _encodePresentation(job));
  }

  static Future<Uint8List> _run(Uint8List Function() encode) async {
    try {
      return await Isolate.run(encode);
    } on IsolateSpawnException {
      return encode();
    } on UnsupportedError {
      return encode();
    } on ArgumentError catch (error) {
      final String text = error.toString();
      if (text.contains('isolate message') || text.contains('unsendable')) {
        return encode();
      }
      rethrow;
    }
  }
}

class _WordSaveJob {
  const _WordSaveJob(this.document, this.password);

  final WmlDocument document;
  final String? password;
}

class _SheetSaveJob {
  const _SheetSaveJob(this.workbook, this.password);

  final SmlWorkbook workbook;
  final String? password;
}

class _SlideSaveJob {
  const _SlideSaveJob(this.presentation, this.password);

  final PmlPresentation presentation;
  final String? password;
}

Uint8List _encodeWord(_WordSaveJob job) {
  return WordSerializer().writeBytes(job.document, password: job.password);
}

Uint8List _encodeWorkbook(_SheetSaveJob job) {
  return SheetSerializer().writeBytes(job.workbook, password: job.password);
}

Uint8List _encodePresentation(_SlideSaveJob job) {
  return SlideSerializer().writeBytes(
    job.presentation,
    password: job.password,
  );
}
