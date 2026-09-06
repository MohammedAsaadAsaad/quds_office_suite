import 'dart:math' as math;
import 'dart:typed_data';

import '../bidi/arabic_shaping.dart';
import '../bidi/line_breaker.dart';
import '../fonts/font_metrics.dart';
import '../fonts/font_subsetter.dart';
import '../fonts/sfnt_parser.dart';
import '../opc/opc_archive.dart';
import '../opc/repair/office_repair.dart';
import '../sheet/formula/formula_eval.dart';
import '../sheet/model/sml_workbook.dart';
import '../sheet/serial/sheet_serial.dart';
import '../slide/model/pml_presentation.dart';
import '../slide/serial/slide_serial.dart';
import '../visual/office_visual.dart';
import '../word/layout/word_layout.dart';
import '../word/math/omml_layout.dart';
import '../word/model/wml_document.dart';
import '../word/model/word_link.dart';
import '../word/model/word_toc.dart';
import '../word/properties/wml_properties.dart';
import '../word/serial/word_deserializer.dart';
import 'office_pdf_visuals.dart';
import 'pdf_canvas.dart';
import 'pdf_document.dart';

/// Print layout for worksheet PDF (Office Print defaults to A4 portrait).
class PdfSheetPrintOptions {
  const PdfSheetPrintOptions({
    this.pageWidth = 595.28,
    this.pageHeight = 841.89,
    this.margin = 36,
    this.showGridlines = true,
    this.showHeadings = true,
    this.fitToPage = false,
  });

  factory PdfSheetPrintOptions.a4Portrait() => const PdfSheetPrintOptions();

  factory PdfSheetPrintOptions.a4Landscape() => const PdfSheetPrintOptions(
        pageWidth: 841.89,
        pageHeight: 595.28,
      );

  factory PdfSheetPrintOptions.letter() => const PdfSheetPrintOptions(
        pageWidth: 612,
        pageHeight: 792,
      );

  final double pageWidth;
  final double pageHeight;
  final double margin;
  final bool showGridlines;
  final bool showHeadings;
  final bool fitToPage;
}

/// How a deck is paginated — matching PowerPoint's print what.
enum PdfSlideExportMode { slides, notesPages }

/// Office-faithful PDF 1.7 export for Word, Excel, and PowerPoint models.
///
/// Word uses the layout engine (pages, tables, headers/footers, visuals).
/// Excel prints each sheet as a paginated grid with evaluated values.
/// PowerPoint emits one landscape page per slide with fills, rotation, and media.
abstract final class OfficePdfExport {
  static Uint8List fromBytes(
    Uint8List bytes, {
    SfntFont? font,
    String title = 'Quds Office',
    String? password,
  }) {
    final OpcPackage package = OfficeRepair.open(bytes, password: password);
    switch (package.kind) {
      case OpcPackageKind.word:
        return word(
          WordDeserializer().read(package),
          font: font,
          title: title,
        );
      case OpcPackageKind.sheet:
        return workbook(
          SheetDeserializer().read(package),
          font: font,
          title: title,
        );
      case OpcPackageKind.slide:
        return presentation(
          SlideDeserializer().read(package),
          font: font,
          title: title,
        );
      case OpcPackageKind.unknown:
        throw FormatException('Unsupported Office package for PDF export');
    }
  }

  static Uint8List word(
    WmlDocument document, {
    SfntFont? font,
    String title = 'Quds Office',
    LaidOutDocument? laidOut,
  }) {
    final LaidOutDocument laid = _layoutWord(document, font, laidOut);
    final Set<int> cps = <int>{};
    _collectWordCodepoints(laid, cps);
    final _FontPack pack = _FontPack.build(font, cps);
    final PdfDocument pdf = PdfDocument(title: title);
    final _PdfImageBank images = _PdfImageBank();
    for (final LaidOutPage page in laid.pages) {
      final _PageSink sink = _PageSink(page.width, page.height, pack, images);
      sink.canvas.fillRect(0, 0, page.width, page.height, 'FFFFFF');
      for (final LaidOutBox frame in page.frames) {
        _paintFrame(sink, frame);
      }
      for (final LaidOutLine line in page.lines) {
        _paintWordLine(sink, line);
      }
      for (final LaidOutLine line in page.header) {
        _paintWordLine(sink, line);
      }
      for (final LaidOutLine line in page.footer) {
        _paintWordLine(sink, line);
      }
      _collectWordLinks(sink, page, laid, document);
      sink.finish(pdf);
    }
    if (pdf.pages.isEmpty) {
      pdf.addPage(
        PdfPage(
          width: 595.28,
          height: 841.89,
          content: PdfCanvas(595.28, 841.89).toStream(),
        ),
      );
    }
    return pdf.save(subset: pack.subset, font: font);
  }

  static Uint8List workbook(
    SmlWorkbook book, {
    SfntFont? font,
    String title = 'Quds Office',
    PdfSheetPrintOptions options = const PdfSheetPrintOptions(),
  }) {
    final Set<int> cps = <int>{};
    for (final SmlWorksheet sheet in book.sheets) {
      _collectShaped(sheet.name, cps);
      for (final SmlCell cell in sheet.allCells) {
        _collectShaped(_sheetDisplay(book, sheet, cell).text, cps);
      }
      for (final SmlDrawing drawing in sheet.drawings) {
        _collectShaped(drawing.visual.title, cps);
        for (final point in drawing.visual.points) {
          _collectShaped(point.label, cps);
        }
      }
    }
    for (int i = 0; i < 26; i++) {
      cps.add(65 + i);
    }
    for (int i = 0x30; i <= 0x39; i++) {
      cps.add(i);
    }
    for (final SmlWorksheet sheet in book.sheets) {
      var maxCol = 0;
      for (final SmlCell cell in sheet.allCells) {
        if (cell.ref.col > maxCol) {
          maxCol = cell.ref.col;
        }
      }
      for (int c = 0; c <= maxCol; c++) {
        cps.addAll(SmlCellRef(c, 0).a1.replaceAll(RegExp(r'\d+'), '').runes);
      }
    }
    final _FontPack pack = _FontPack.build(font, cps);
    final PdfDocument pdf = PdfDocument(title: title);
    final _PdfImageBank images = _PdfImageBank();
    var printed = 0;
    for (final SmlWorksheet sheet in book.sheets) {
      printed += _printSheet(pdf, book, sheet, pack, options, images);
    }
    if (printed == 0) {
      pdf.addPage(
        PdfPage(
          width: options.pageWidth,
          height: options.pageHeight,
          content: PdfCanvas(options.pageWidth, options.pageHeight).toStream(),
        ),
      );
    }
    return pdf.save(subset: pack.subset, font: font);
  }

  static Uint8List presentation(
    PmlPresentation deck, {
    SfntFont? font,
    String title = 'Quds Office',
    PdfSlideExportMode mode = PdfSlideExportMode.slides,
  }) {
    final double slideW = deck.slideWidth / 12700;
    final double slideH = deck.slideHeight / 12700;
    final bool notes = mode == PdfSlideExportMode.notesPages;
    final double pageW = notes ? 595.28 : slideW;
    final double pageH = notes ? 841.89 : slideH;
    final Set<int> cps = <int>{};
    for (final PmlSlide slide in deck.slides) {
      _collectShaped(slide.notes, cps);
      for (final PmlShape shape in slide.shapes) {
        _collectShaped(deck.resolveText(shape, slide), cps);
        if (shape.visual != null) {
          _collectShaped(shape.visual!.title, cps);
          for (final point in shape.visual!.points) {
            _collectShaped(point.label, cps);
          }
        }
      }
    }
    final _FontPack pack = _FontPack.build(font, cps);
    final PdfDocument pdf = PdfDocument(title: title);
    final _PdfImageBank images = _PdfImageBank();
    for (int i = 0; i < deck.slides.length; i++) {
      final PmlSlide slide = deck.slides[i];
      final _PageSink sink = _PageSink(pageW, pageH, pack, images);
      sink.canvas.fillRect(0, 0, pageW, pageH, 'FFFFFF');
      final double ox = notes ? 36 : 0;
      final double oy = notes ? 36 : 0;
      final double scale = notes ? math.min((pageW - 72) / slideW, 420 / slideH) : 1;
      sink.canvas.save();
      if (notes) {
        sink.canvas.clipRect(ox, oy, slideW * scale, slideH * scale);
        sink.canvas.translateScale(ox, oy, scale);
      }
      sink.canvas.fillRect(
        0,
        0,
        slideW,
        slideH,
        deck.master.background.isEmpty ? 'FFFFFF' : deck.master.background,
      );
      for (final PmlShape shape in slide.shapes) {
        _paintShape(sink, deck, slide, shape);
      }
      sink.canvas.restore();
      if (notes) {
        sink.drawText(
          '${i + 1} / ${deck.slides.length}',
          36,
          36 + slideH * scale + 18,
          9,
          '595959',
        );
        if (slide.notes.isNotEmpty) {
          _wrapShapeText(
            sink,
            slide.notes,
            36,
            36 + slideH * scale + 36,
            pageW - 72,
            11,
            '222222',
          );
        }
      }
      sink.finish(pdf);
    }
    if (pdf.pages.isEmpty) {
      pdf.addPage(
        PdfPage(
          width: pageW,
          height: pageH,
          content: PdfCanvas(pageW, pageH).toStream(),
        ),
      );
    }
    return pdf.save(subset: pack.subset, font: font);
  }

  static LaidOutDocument _layoutWord(
    WmlDocument document,
    SfntFont? font,
    LaidOutDocument? laidOut,
  ) {
    WordLink.ensureHeadingBookmarks(document);
    WordToc.refreshEmpty(document);
    WordToc.rebindHeadings(document);
    final WordLayoutEngine engine = WordLayoutEngine(font: font);
    LaidOutDocument laid = laidOut ?? engine.layout(document);
    if (WordToc.syncPageNumbers(document, laid)) {
      laid = engine.layout(document);
    }
    return laid;
  }

  static ({int page, double y})? _pageOfParagraph(
    LaidOutDocument laid,
    int paragraphIndex,
  ) {
    for (final LaidOutPage page in laid.pages) {
      for (final LaidOutLine line in page.lines) {
        if (line.paragraphIndex == paragraphIndex) {
          return (page: page.index, y: line.y);
        }
      }
    }
    return null;
  }

  static void _collectWordLinks(
    _PageSink sink,
    LaidOutPage page,
    LaidOutDocument laid,
    WmlDocument document,
  ) {
    for (final LaidOutBox box in page.frames) {
      if (box.kind != LaidOutBoxKind.tocEntry || box.paragraphIndex == null) {
        continue;
      }
      final ({int page, double y})? dest =
          _pageOfParagraph(laid, box.paragraphIndex!);
      if (dest == null) {
        continue;
      }
      sink.links.add(
        PdfLinkAnnot(
          x: box.x,
          y: box.y,
          width: box.width,
          height: math.max(10, box.height),
          destPage: dest.page,
          destY: dest.y,
        ),
      );
    }
    void walk(LaidOutLine line) {
      if (line.tocTargetParagraph != null) {
        return;
      }
      _addGlyphLinks(sink, line, laid, document);
    }

    for (final LaidOutLine line in page.lines) {
      walk(line);
    }
    for (final LaidOutLine line in page.header) {
      walk(line);
    }
    for (final LaidOutLine line in page.footer) {
      walk(line);
    }
  }

  static void _addGlyphLinks(
    _PageSink sink,
    LaidOutLine line,
    LaidOutDocument laid,
    WmlDocument document,
  ) {
    WmlHyperlink? current;
    var x0 = 0.0;
    var y0 = 0.0;
    var x1 = 0.0;
    var y1 = 0.0;
    void flush() {
      if (current == null) {
        return;
      }
      sink.addResolvedLink(
        x0,
        y0,
        math.max(8, x1 - x0),
        math.max(8, y1 - y0),
        current!,
        laid,
        document,
      );
      current = null;
    }

    for (final LaidOutGlyph glyph in line.glyphs) {
      final WmlHyperlink? link = glyph.hyperlink;
      if (link == null || link.displayTarget.isEmpty) {
        flush();
        continue;
      }
      final double top = glyph.y - glyph.fontSize;
      final double bottom = glyph.y + glyph.fontSize * 0.3;
      if (current != null && current!.displayTarget == link.displayTarget) {
        x1 = math.max(x1, glyph.x + glyph.advance);
        y0 = math.min(y0, top);
        y1 = math.max(y1, bottom);
        continue;
      }
      flush();
      current = link;
      x0 = glyph.x;
      x1 = glyph.x + glyph.advance;
      y0 = top;
      y1 = bottom;
    }
    flush();
  }

  static void _collectWordCodepoints(LaidOutDocument laid, Set<int> cps) {
    void line(LaidOutLine item) {
      if (item.overlayText != null) {
        _collectShaped(item.overlayText!, cps);
      }
      if (item.listLabel != null) {
        _collectShaped(item.listLabel!, cps);
      }
      for (final LaidOutGlyph g in item.glyphs) {
        cps.add(g.glyph.codePoint);
      }
    }

    for (final LaidOutPage page in laid.pages) {
      for (final LaidOutLine item in page.lines) {
        line(item);
      }
      for (final LaidOutLine item in page.header) {
        line(item);
      }
      for (final LaidOutLine item in page.footer) {
        line(item);
      }
      for (final LaidOutBox frame in page.frames) {
        final OfficeVisual? visual = frame.visual;
        if (visual != null) {
          _collectShaped(visual.title, cps);
          for (final point in visual.points) {
            _collectShaped(point.label, cps);
          }
        }
        final LaidOutOmml? omml = frame.omml;
        if (omml != null) {
          for (final LaidOutOmmlItem item in omml.items) {
            if (item is LaidOutOmmlText) {
              _collectShaped(item.text, cps);
            }
          }
        }
      }
    }
  }

  static void _paintFrame(_PageSink sink, LaidOutBox frame) {
    if (frame.kind == LaidOutBoxKind.tocEntry) {
      return;
    }
    if (frame.fillColor != null && frame.fillColor!.isNotEmpty) {
      sink.canvas.fillRect(
        frame.x,
        frame.y,
        frame.width,
        frame.height,
        frame.fillColor!,
      );
    }
    if (frame.strokeColor.isNotEmpty && frame.strokeColor != '00000000') {
      sink.canvas.strokeRect(
        frame.x,
        frame.y,
        frame.width,
        frame.height,
        frame.strokeColor,
      );
    }
    final LaidOutOmml? omml = frame.omml;
    if (omml != null) {
      _paintOmml(sink, frame.x, frame.y, omml);
      return;
    }
    final OfficeVisual? visual = frame.visual;
    if (visual == null) {
      return;
    }
    OfficePdfVisuals.paint(
      sink.canvas,
      frame.x,
      frame.y,
      frame.width,
      frame.height,
      visual,
      sink.images,
      drawText: sink.drawText,
      nextImageName: sink.nextImageName,
    );
  }

  static void _paintOmml(
    _PageSink sink,
    double originX,
    double originY,
    LaidOutOmml omml,
  ) {
    for (final LaidOutOmmlItem item in omml.items) {
      final double x = originX + item.x;
      final double y = originY + item.y;
      switch (item) {
        case LaidOutOmmlText():
          sink.drawText(item.text, x, y + item.fontSize * 0.85, item.fontSize, '1F4E79');
        case LaidOutOmmlRule():
          sink.canvas.setStrokeColor('1F4E79');
          sink.canvas.setLineWidth(item.height);
          sink.canvas.moveTo(x, y);
          sink.canvas.lineTo(x + item.width, y);
          sink.canvas.stroke();
        case LaidOutOmmlStroke():
          _paintOmmlStroke(sink.canvas, x, y, item);
        case LaidOutOmmlSlot():
          if (item.empty) {
            sink.canvas.setStrokeColor('B4C7E7');
            sink.canvas.setDash(<double>[2, 2]);
            sink.canvas.strokeRect(x, y, item.width, item.height, 'B4C7E7');
            sink.canvas.resetDash();
          }
      }
    }
  }

  static void _paintOmmlStroke(
    PdfCanvas canvas,
    double x,
    double y,
    LaidOutOmmlStroke item,
  ) {
    canvas.setStrokeColor('1F4E79');
    canvas.setLineWidth(1.1);
    switch (item.kind) {
      case OmmlStrokeKind.radical:
        canvas.moveTo(x, y + item.height * 0.55);
        canvas.lineTo(x + item.width * 0.12, y + item.height);
        canvas.lineTo(x + item.width * 0.22, y);
        canvas.lineTo(x + item.width, y);
        canvas.stroke();
      case OmmlStrokeKind.parenLeft:
      case OmmlStrokeKind.braceLeft:
        canvas.moveTo(x + item.width, y);
        canvas.curveTo(
          x,
          y + item.height * 0.2,
          x,
          y + item.height * 0.8,
          x + item.width,
          y + item.height,
        );
        canvas.stroke();
      case OmmlStrokeKind.parenRight:
      case OmmlStrokeKind.braceRight:
        canvas.moveTo(x, y);
        canvas.curveTo(
          x + item.width,
          y + item.height * 0.2,
          x + item.width,
          y + item.height * 0.8,
          x,
          y + item.height,
        );
        canvas.stroke();
    }
  }

  static void _paintWordLine(_PageSink sink, LaidOutLine line) {
    if (line.listLabel != null && line.isParagraphStart) {
      sink.drawText(line.listLabel!, line.x - 14, line.y + 11, 11, '333333');
    }
    if (line.overlayText != null &&
        line.overlayText!.isNotEmpty &&
        line.glyphs.isEmpty) {
      sink.drawText(line.overlayText!, line.x, line.y + 11, 10, '333333');
      return;
    }
    for (final LaidOutGlyph g in line.glyphs) {
      if (g.highlight != null && g.highlight!.isNotEmpty) {
        sink.canvas.fillRect(g.x, g.y - g.fontSize, g.advance, g.fontSize * 1.2, g.highlight!);
      }
    }
    for (final LaidOutGlyph g in line.glyphs) {
      sink.drawGlyph(g);
      _paintGlyphChrome(sink, g);
    }
    if (line.overlayText != null &&
        line.overlayText!.isNotEmpty &&
        line.glyphs.isNotEmpty) {
      final double x = line.tocLeader
          ? sink.width - 72 - line.overlayText!.length * 6
          : line.x + line.width + 8;
      sink.drawText(line.overlayText!, x, line.y + 11, 10, '333333');
    }
  }

  static void _paintGlyphChrome(_PageSink sink, LaidOutGlyph g) {
    if (g.strike) {
      sink.canvas.setStrokeColor(g.color);
      sink.canvas.setLineWidth(0.7);
      final double mid = g.y - g.fontSize * 0.35;
      sink.canvas.moveTo(g.x, mid);
      sink.canvas.lineTo(g.x + g.advance, mid);
      sink.canvas.stroke();
    }
    if (g.underline == WmlUnderline.none) {
      return;
    }
    sink.canvas.setStrokeColor(g.color);
    sink.canvas.setLineWidth(g.underline == WmlUnderline.double ? 1.1 : 0.7);
    switch (g.underline) {
      case WmlUnderline.dotted:
        sink.canvas.setDash(<double>[1.1, 1.1]);
        sink.canvas.moveTo(g.x, g.y + 1.2);
        sink.canvas.lineTo(g.x + g.advance, g.y + 1.2);
        sink.canvas.stroke();
        sink.canvas.resetDash();
      case WmlUnderline.wavy:
        var wx = g.x;
        final double base = g.y + 1.4;
        sink.canvas.moveTo(wx, base);
        while (wx < g.x + g.advance) {
          final double nx = math.min(wx + 2.4, g.x + g.advance);
          sink.canvas.curveTo(
            wx + 0.8,
            base - 1.1,
            wx + 1.6,
            base + 1.1,
            nx,
            base,
          );
          wx = nx;
        }
        sink.canvas.stroke();
      case WmlUnderline.double:
        sink.canvas.setLineWidth(0.7);
        sink.canvas.moveTo(g.x, g.y + 1.1);
        sink.canvas.lineTo(g.x + g.advance, g.y + 1.1);
        sink.canvas.stroke();
        sink.canvas.moveTo(g.x, g.y + 3.4);
        sink.canvas.lineTo(g.x + g.advance, g.y + 3.4);
        sink.canvas.stroke();
      case WmlUnderline.single:
        sink.canvas.moveTo(g.x, g.y + 1.2);
        sink.canvas.lineTo(g.x + g.advance, g.y + 1.2);
        sink.canvas.stroke();
      case WmlUnderline.none:
        break;
    }
  }

  static int _printSheet(
    PdfDocument pdf,
    SmlWorkbook book,
    SmlWorksheet sheet,
    _FontPack pack,
    PdfSheetPrintOptions options,
    _PdfImageBank images,
  ) {
    final double pageW = options.pageWidth;
    final double pageH = options.pageHeight;
    final double margin = options.margin;
    var colW = 56.0;
    var rowH = 16.0;
    final double gutter = options.showHeadings ? 28 : 0;
    final double band = 18;
    var maxCol = 0;
    var maxRow = 0;
    var any = false;
    for (final SmlCell cell in sheet.allCells) {
      if ((cell.value == null || cell.asString.isEmpty) &&
          (cell.formula == null || cell.formula!.isEmpty)) {
        continue;
      }
      any = true;
      if (cell.ref.col > maxCol) {
        maxCol = cell.ref.col;
      }
      if (cell.ref.row > maxRow) {
        maxRow = cell.ref.row;
      }
    }
    for (final SmlDrawing drawing in sheet.drawings) {
      any = true;
      if (drawing.col > maxCol) {
        maxCol = drawing.col + 4;
      }
      if (drawing.row > maxRow) {
        maxRow = drawing.row + 8;
      }
    }
    if (!any) {
      maxCol = 4;
      maxRow = 12;
    }
    final double usableW = pageW - margin * 2 - gutter;
    final double usableH = pageH - margin * 2 - band - 16;
    if (options.fitToPage) {
      final double needW = (maxCol + 1) * colW;
      final double needH = (maxRow + 1) * rowH;
      final double scale = math.min(
        1,
        math.min(usableW / needW, usableH / needH),
      );
      colW *= scale;
      rowH *= scale;
    }
    final int colsPerPage = (usableW / colW).floor().clamp(1, 64);
    final int rowsPerPage = (usableH / rowH).floor().clamp(1, 80);
    var pages = 0;
    var pageNo = 1;
    final int totalGuess =
        (((maxCol + 1) / colsPerPage).ceil()) * (((maxRow + 1) / rowsPerPage).ceil());
    for (var r0 = 0; r0 <= maxRow; r0 += rowsPerPage) {
      for (var c0 = 0; c0 <= maxCol; c0 += colsPerPage) {
        final int c1 = (c0 + colsPerPage - 1).clamp(0, maxCol);
        final int r1 = (r0 + rowsPerPage - 1).clamp(0, maxRow);
        final _PageSink sink = _PageSink(pageW, pageH, pack, images);
        sink.canvas.fillRect(0, 0, pageW, pageH, 'FFFFFF');
        sink.drawText(
          '${sheet.name}  -  $pageNo / $totalGuess',
          margin,
          margin + 10,
          9,
          '595959',
        );
        final bool rtl = sheet.rightToLeft;
        final double rowGutterX = rtl ? pageW - margin - gutter : margin;
        final double gridLeft = rtl ? margin : margin + gutter;
        final double gridRight = rtl ? pageW - margin - gutter : pageW - margin;
        double colX(int c) {
          if (!rtl) {
            return gridLeft + (c - c0) * colW;
          }
          return gridRight - (c - c0 + 1) * colW;
        }
        final double gridY = margin + band;
        final double headingH = options.showHeadings ? rowH : 0;
        if (options.showHeadings) {
          if (gutter > 0) {
            sink.canvas.fillRect(rowGutterX, gridY, gutter, headingH, 'F2F2F2');
          }
          for (int c = c0; c <= c1; c++) {
            final double x = colX(c);
            sink.canvas.fillRect(x, gridY, colW, headingH, 'F2F2F2');
            if (options.showGridlines) {
              sink.canvas.strokeRect(x, gridY, colW, headingH, 'D0D0D0');
            }
            sink.drawText(
              SmlCellRef(c, 0).a1.replaceAll(RegExp(r'\d+'), ''),
              x + 4,
              gridY + headingH * 0.75,
              8,
              '595959',
            );
          }
        }
        for (int r = r0; r <= r1; r++) {
          final double y = gridY + headingH + (r - r0) * rowH;
          if (options.showHeadings) {
            sink.canvas.fillRect(rowGutterX, y, gutter, rowH, 'F2F2F2');
            if (options.showGridlines) {
              sink.canvas.strokeRect(rowGutterX, y, gutter, rowH, 'D0D0D0');
            }
            sink.drawText('${r + 1}', rowGutterX + 4, y + rowH * 0.75, 8, '595959');
          }
          for (int c = c0; c <= c1; c++) {
            final double x = colX(c);
            if (options.showGridlines) {
              sink.canvas.strokeRect(x, y, colW, rowH, 'D0D0D0');
            }
            final SmlCell? stored = sheet.rows[r]?.cells[c];
            if (stored == null) {
              continue;
            }
            final ({String text, String color}) shown =
                _sheetDisplay(book, sheet, stored);
            if (shown.text.isEmpty) {
              continue;
            }
            sink.canvas.save();
            sink.canvas.clipRect(x + 1, y + 1, colW - 2, rowH - 2);
            sink.drawText(
              shown.text,
              x + 3,
              y + rowH * 0.75,
              8,
              shown.color,
              maxWidth: colW - 6,
            );
            sink.canvas.restore();
          }
        }
        for (final SmlDrawing drawing in sheet.drawings) {
          if (drawing.col < c0 || drawing.col > c1 || drawing.row < r0 || drawing.row > r1) {
            continue;
          }
          final double x = colX(drawing.col);
          final double y = gridY + headingH + (drawing.row - r0) * rowH;
          final double remainW = math.max(36, pageW - margin - x - 4);
          final double remainH = math.max(36, pageH - margin - y - 4);
          OfficePdfVisuals.paint(
            sink.canvas,
            x,
            y,
            drawing.visual.width.clamp(40, remainW),
            drawing.visual.height.clamp(40, remainH),
            drawing.visual,
            sink.images,
            drawText: sink.drawText,
            nextImageName: sink.nextImageName,
          );
        }
        sink.finish(pdf);
        pages++;
        pageNo++;
      }
    }
    return pages;
  }

  static ({String text, String color}) _sheetDisplay(
    SmlWorkbook book,
    SmlWorksheet sheet,
    SmlCell cell,
  ) {
    final Object? value = cell.formula != null && cell.formula!.isNotEmpty
        ? FormulaEvaluator.evaluateCell(book, sheet, cell)
        : cell.value;
    if (value == null) {
      return (text: '', color: '222222');
    }
    if (book.styles != null) {
      final String formatted = book.styles!.format(value, cell.styleIndex);
      if (formatted.startsWith('RED:')) {
        return (text: formatted.substring(4), color: 'C00000');
      }
      return (text: formatted, color: '222222');
    }
    if (value is num) {
      if (value == value.roundToDouble()) {
        return (text: '${value.round()}', color: '222222');
      }
      return (text: value.toStringAsFixed(2), color: '222222');
    }
    return (text: value.toString(), color: '222222');
  }

  static void _paintShape(
    _PageSink sink,
    PmlPresentation deck,
    PmlSlide slide,
    PmlShape shape,
  ) {
    final double x = shape.transform.xPoints;
    final double y = shape.transform.yPoints;
    final double w = shape.transform.widthPoints;
    final double h = shape.transform.heightPoints;
    sink.canvas.save();
    if (shape.transform.rotationDegrees.abs() > 0.05) {
      sink.canvas.rotateAround(
        x + w / 2,
        y + h / 2,
        shape.transform.rotationDegrees,
      );
    }
    if (shape.table != null) {
      _paintSlideTable(sink, shape.table!, x, y, w, h);
    } else if (shape.visual != null) {
      OfficePdfVisuals.paint(
        sink.canvas,
        x,
        y,
        w,
        h,
        shape.visual!,
        sink.images,
        drawText: sink.drawText,
        nextImageName: sink.nextImageName,
      );
    } else {
      _fillPreset(sink.canvas, shape.preset, x, y, w, h, shape.fillColor, shape.path);
      final String text = deck.resolveText(shape, slide);
      if (text.isNotEmpty) {
        final String ink = shape.textColor.isNotEmpty
            ? shape.textColor
            : (shape.fillColor.isEmpty ? '1A1A1A' : _contrast(shape.fillColor));
        final double rawSize = shape.fontSizePt > 0
            ? shape.fontSizePt.clamp(8, 48)
            : (h * 0.22).clamp(10, 28);
        final double size = math.min(rawSize, math.max(8, h * 0.55));
        final bool singleLine = !text.contains('\n');
        final double top = singleLine && h < size * 2.8
            ? y + math.max(2, (h - size) / 2)
            : y + math.max(4, size * 0.1);
        _wrapShapeText(sink, text, x + 10, top, w - 20, size, ink);
      }
    }
    sink.canvas.restore();
  }

  static void _paintSlideTable(
    _PageSink sink,
    PmlTable table,
    double x,
    double y,
    double w,
    double h,
  ) {
    sink.canvas.setStrokeColor('1F1F1F');
    sink.canvas.setLineWidth(0.8);
    sink.canvas.rect(x, y, w, h);
    sink.canvas.stroke();
    for (int row = 0; row < table.rowCount; row++) {
      for (int col = 0; col < table.colCount; col++) {
        final PmlTableCell cell = table.cellAt(row, col);
        final ({double x, double y, double width, double height}) box =
            table.cellBounds(
          x: x,
          y: y,
          width: w,
          height: h,
          row: row,
          col: col,
        );
        if (cell.fillColor.isNotEmpty) {
          sink.canvas.setFillColor(cell.fillColor);
          sink.canvas.rect(box.x, box.y, box.width, box.height);
          sink.canvas.fill();
        }
        sink.canvas.setStrokeColor('6B6B6B');
        sink.canvas.setLineWidth(0.5);
        sink.canvas.rect(box.x, box.y, box.width, box.height);
        sink.canvas.stroke();
        if (cell.text.isNotEmpty) {
          final String ink = cell.textColor.isNotEmpty ? cell.textColor : '1A1A1A';
          final double size = (box.height * 0.28).clamp(8, 14);
          _wrapShapeText(
            sink,
            cell.text,
            box.x + 4,
            box.y + 3,
            box.width - 8,
            size,
            ink,
          );
        }
      }
    }
  }

  static void _fillPreset(
    PdfCanvas canvas,
    PmlShapePreset preset,
    double x,
    double y,
    double w,
    double h,
    String fill,
    List<PmlPathPoint> path,
  ) {
    if (fill.isEmpty) {
      return;
    }
    canvas.setFillColor(fill);
    switch (preset) {
      case PmlShapePreset.roundRect:
        canvas.roundedRect(x, y, w, h, 8);
        canvas.fill();
      case PmlShapePreset.ellipse:
        canvas.ellipse(x, y, w, h);
        canvas.fill();
      case PmlShapePreset.triangle:
        canvas.moveTo(x + w / 2, y);
        canvas.lineTo(x + w, y + h);
        canvas.lineTo(x, y + h);
        canvas.closePath();
        canvas.fill();
      case PmlShapePreset.connector:
        canvas.setStrokeColor(fill);
        canvas.setLineWidth(1.6);
        canvas.moveTo(x, y + h / 2);
        canvas.lineTo(x + w, y + h / 2);
        canvas.stroke();
      case PmlShapePreset.freeform:
        if (path.length >= 2) {
          canvas.moveTo(x + path.first.x / 12700, y + path.first.y / 12700);
          for (int i = 1; i < path.length; i++) {
            canvas.lineTo(x + path[i].x / 12700, y + path[i].y / 12700);
          }
          canvas.closePath();
          canvas.fill();
        } else {
          canvas.rect(x, y, w, h);
          canvas.fill();
        }
      case PmlShapePreset.rect:
        canvas.rect(x, y, w, h);
        canvas.fill();
    }
  }

  static void _wrapShapeText(
    _PageSink sink,
    String text,
    double x,
    double y,
    double maxWidth,
    double size,
    String color,
  ) {
    if (sink.pack.font != null) {
      final FontMetrics metrics =
          FontMetrics(font: sink.pack.font!, fontSizePoints: size);
      var cy = y;
      for (final String para in text.split('\n')) {
        if (para.isEmpty) {
          cy += size * 1.25;
          continue;
        }
        final List<BrokenLine> lines = LineBreaker.breakLines(
          text: para,
          maxWidth: maxWidth,
          widthOf: metrics.characterWidth,
          glyphIdOf: sink.pack.font!.glyphIdFor,
        );
        for (final BrokenLine line in lines) {
          if (line.glyphs.isEmpty) {
            cy += size * 1.25;
            continue;
          }
          final bool rtl =
              line.glyphs.any((ShapedGlyph g) => g.level.isOdd);
          var cx = rtl ? x + maxWidth - line.width : x;
          // Tm d=-1 grows glyphs up the flipped page; y is the baseline.
          final double baseline = cy + size;
          for (final ShapedGlyph g in line.glyphs) {
            if (g.codePoint < 32) {
              continue;
            }
            sink.drawGlyph(
              LaidOutGlyph(
                glyph: g,
                x: cx,
                y: baseline,
                color: color,
                fontSize: size,
                bold: false,
                underline: WmlUnderline.none,
              ),
            );
            cx += g.advance;
          }
          cy += size * 1.35;
        }
      }
      return;
    }
    final List<String> words = text.split(RegExp(r'\s+'));
    var line = '';
    var cy = y;
    for (final String word in words) {
      final String next = line.isEmpty ? word : '$line $word';
      if (sink.measure(next, size) > maxWidth && line.isNotEmpty) {
        sink.drawText(line, x, cy + size, size, color);
        line = word;
        cy += size * 1.25;
      } else {
        line = next;
      }
    }
    if (line.isNotEmpty) {
      sink.drawText(line, x, cy + size, size, color);
    }
  }

  static void _collectShaped(String text, Set<int> cps) {
    if (text.isEmpty) {
      return;
    }
    cps.addAll(text.runes);
    for (final ShapedChar shaped in ArabicShaper.shape(text)) {
      cps.add(shaped.codePoint);
    }
  }

  static String _contrast(String hex) {
    final int rgb = int.tryParse(hex.replaceAll('#', ''), radix: 16) ?? 0x4472C4;
    final int r = (rgb >> 16) & 0xFF;
    final int g = (rgb >> 8) & 0xFF;
    final int b = rgb & 0xFF;
    return (0.299 * r + 0.587 * g + 0.114 * b) < 140 ? 'FFFFFF' : '1A1A1A';
  }
}

class _FontPack {
  _FontPack(this.font, this.subset, this.metrics);

  final SfntFont? font;
  final FontSubset? subset;
  final FontMetrics? metrics;

  static _FontPack build(SfntFont? font, Set<int> cps) {
    if (font == null || cps.isEmpty || !font.hasTable('glyf')) {
      return _FontPack(
        font,
        null,
        font == null ? null : FontMetrics(font: font, fontSizePoints: 11),
      );
    }
    return _FontPack(
      font,
      FontSubsetter(font).subset(cps),
      FontMetrics(font: font, fontSizePoints: 11),
    );
  }
}

class _PdfImageBank {
  var _n = 0;

  String next() => 'Im${++_n}';
}

class _PageSink {
  _PageSink(this.width, this.height, this.pack, this._images)
      : canvas = PdfCanvas(width, height);

  final double width;
  final double height;
  final _FontPack pack;
  final _PdfImageBank _images;
  final PdfCanvas canvas;
  final List<PdfEmbeddedImage> images = <PdfEmbeddedImage>[];
  final List<PdfLinkAnnot> links = <PdfLinkAnnot>[];

  String nextImageName() => _images.next();

  void addResolvedLink(
    double x,
    double y,
    double width,
    double height,
    WmlHyperlink link,
    LaidOutDocument laid,
    WmlDocument document,
  ) {
    if (link.isWeb) {
      links.add(
        PdfLinkAnnot(x: x, y: y, width: width, height: height, uri: link.url),
      );
      return;
    }
    if (link.isFile) {
      links.add(
        PdfLinkAnnot(x: x, y: y, width: width, height: height, file: link.file),
      );
      return;
    }
    if (!link.isInternal) {
      return;
    }
    final int? para = WordLink.paragraphIndexForAnchor(document, link.anchor!);
    if (para == null) {
      return;
    }
    final ({int page, double y})? dest = OfficePdfExport._pageOfParagraph(
      laid,
      para,
    );
    if (dest == null) {
      return;
    }
    links.add(
      PdfLinkAnnot(
        x: x,
        y: y,
        width: width,
        height: height,
        destPage: dest.page,
        destY: dest.y,
      ),
    );
  }

  void drawGlyph(LaidOutGlyph g) {
    _emit(
      oldGid: g.glyph.glyphId,
      codePoint: g.glyph.codePoint,
      x: g.x,
      y: g.y,
      size: g.fontSize,
      color: g.color,
      italic: g.italic,
      bold: g.bold,
    );
  }

  void drawText(
    String text,
    double x,
    double y,
    double size,
    String color, {
    double? maxWidth,
  }) {
    if (text.isEmpty) {
      return;
    }
    if (pack.font != null && pack.subset != null) {
      final FontMetrics metrics =
          FontMetrics(font: pack.font!, fontSizePoints: size);
      final List<BrokenLine> lines = LineBreaker.breakLines(
        text: text,
        maxWidth: maxWidth ?? 1e9,
        widthOf: metrics.characterWidth,
        glyphIdOf: pack.font!.glyphIdFor,
      );
      var cy = y;
      for (int i = 0; i < lines.length; i++) {
        final BrokenLine line = lines[i];
        if (line.glyphs.isEmpty) {
          cy += size * 1.25;
          continue;
        }
        final bool rtl = line.glyphs.any((ShapedGlyph g) => g.level.isOdd);
        var cx = x;
        if (rtl && maxWidth != null) {
          cx = x + maxWidth - line.width;
        }
        for (final ShapedGlyph g in line.glyphs) {
          if (g.codePoint < 32) {
            continue;
          }
          _emit(
            oldGid: g.glyphId,
            codePoint: g.codePoint,
            x: cx,
            y: cy,
            size: size,
            color: color,
          );
          cx += g.advance;
        }
        cy += size * 1.25;
      }
      return;
    }
    if (_winAnsiOnly(text)) {
      canvas.showLatin(x: x, y: y, fontSize: size, text: text, color: color);
      return;
    }
    var cx = x;
    for (final int cp in text.runes) {
      if (_isWinAnsi(cp)) {
        canvas.showLatin(
          x: cx,
          y: y,
          fontSize: size,
          text: String.fromCharCode(cp),
          color: color,
        );
        cx += size * 0.5;
      }
    }
  }

  void _emit({
    required int oldGid,
    required int codePoint,
    required double x,
    required double y,
    required double size,
    required String color,
    bool italic = false,
    bool bold = false,
  }) {
    if (pack.font != null && pack.subset != null) {
      final int gid = pack.subset!.unicodeToNewGlyph[codePoint] ??
          pack.subset!.oldToNewGlyph[oldGid] ??
          0;
      if (gid != 0) {
        canvas.showGlyph(
          x: x,
          y: y,
          fontSize: size,
          glyphId: gid,
          color: color,
          italic: italic,
          bold: bold,
        );
        return;
      }
    }
    if (_isWinAnsi(codePoint)) {
      canvas.showLatin(
        x: x,
        y: y,
        fontSize: size,
        text: String.fromCharCode(codePoint),
        color: color,
      );
    }
  }

  static bool _isWinAnsi(int cp) => cp >= 0x20 && cp <= 0x7E;

  static bool _winAnsiOnly(String text) {
    for (final int cp in text.runes) {
      if (cp == 0x0A || cp == 0x0D) {
        continue;
      }
      if (!_isWinAnsi(cp)) {
        return false;
      }
    }
    return true;
  }

  double measure(String text, double size) {
    if (pack.font != null) {
      return FontMetrics(font: pack.font!, fontSizePoints: size).measureText(text);
    }
    return text.length * size * 0.5;
  }

  void finish(PdfDocument pdf) {
    canvas.endText();
    pdf.addPage(
      PdfPage(
        width: width,
        height: height,
        content: canvas.toStream(),
        images: List<PdfEmbeddedImage>.from(images),
        links: List<PdfLinkAnnot>.from(links),
      ),
    );
  }
}
