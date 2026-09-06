import 'dart:io';

import 'package:quds_office_engine/quds_office_engine.dart';

import 'gallery_io.dart';
import 'sheet_gallery.dart';
import 'slide_gallery.dart';
import 'word_gallery.dart';

/// Writes several Word / Excel / PowerPoint packages and a PDF twin for each.
void main(List<String> args) {
  final String scriptDir = File.fromUri(Platform.script).parent.path;
  final String outPath = args.isEmpty ? '$scriptDir/out' : args.first;
  final Directory root = Directory(outPath);
  if (root.existsSync()) {
    root.deleteSync(recursive: true);
  }
  root.createSync(recursive: true);

  final SfntFont? font = loadSystemUiFont();
  final GallerySink sink = GallerySink(root, font: font);

  final WmlDocument briefing = engineBriefing();
  sink.office(
    'word/01_engine_briefing.docx',
    WordSerializer().writeBytes(briefing),
    title: 'Engine briefing',
    pdfBytes: OfficePdfExport.word(briefing, font: font, title: 'Engine briefing'),
  );
  sink.office(
    'word/02_builder_report.docx',
    builderReport(),
    title: 'Builder report',
  );
  sink.office(
    'word/03_letter.docx',
    formalLetter(),
    title: 'Release notes',
  );

  final SmlWorkbook formulas = engineWorkbook();
  sink.office(
    'excel/01_formula_workbook.xlsx',
    SheetSerializer().writeBytes(formulas),
    title: 'Formula workbook',
    pdfBytes: OfficePdfExport.workbook(formulas, font: font, title: 'Formula workbook'),
  );
  sink.office(
    'excel/02_styled_workbook.xlsx',
    builderWorkbook(),
    title: 'Styled workbook',
  );
  final SmlWorkbook catalog = catalogWorkbook();
  sink.office(
    'excel/03_catalog.xlsx',
    SheetSerializer().writeBytes(catalog),
    title: 'Catalog',
    pdfBytes: OfficePdfExport.workbook(catalog, font: font, title: 'Catalog'),
  );

  final PmlPresentation deck = engineDeck();
  sink.office(
    'powerpoint/01_engine_deck.pptx',
    SlideSerializer().writeBytes(deck),
    title: 'Engine deck',
    notesPages: true,
    pdfBytes: OfficePdfExport.presentation(deck, font: font, title: 'Engine deck'),
  );
  sink.office(
    'powerpoint/02_builder_deck.pptx',
    builderDeck(),
    title: 'Builder deck',
  );
  sink.office(
    'powerpoint/03_rtl_deck.pptx',
    rtlDeck(),
    title: 'RTL deck',
  );

  sink.writeManifest();

  stdout.writeln('Wrote ${sink.written.length} files under ${root.path}');
  stdout.writeln(font == null
      ? 'No system UI font — PDF uses Helvetica for Latin only.'
      : 'PDF embeds a subset of the system UI font.');
  for (final String name in sink.written) {
    stdout.writeln('  $name');
  }
}
