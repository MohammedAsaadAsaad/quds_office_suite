/// Renders Office files saved by another suite next to that suite's own
/// output, for the README fidelity gallery.
///
/// Every input is exported twice: once by `OfficePdfExport.fromBytes`, and
/// once by LibreOffice (`soffice --convert-to pdf`). Page 1 of each is
/// rasterized with `pdftoppm` as `<name>_quds.png` and `<name>_office.png`.
///
/// Usage: `dart run tool/dump_office_shots.dart <out-dir> <file>... `
///
/// Fonts come from `../quds_office_editor/fonts` (Liberation + Noto Naskh
/// Arabic), the same faces LibreOffice substitutes for Calibri and Arial.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'usage: dart run tool/dump_office_shots.dart <out-dir> <file>...',
    );
    exitCode = 64;
    return;
  }
  final Directory out = Directory(args[0])..createSync(recursive: true);
  final Directory work = Directory.systemTemp.createTempSync('office_shots');
  SfntFont face(String file) => SfntFont.parse(
    File('../quds_office_editor/fonts/$file').readAsBytesSync(),
  );
  final OfficeFontSet fonts = OfficeFontSet(
    primary: face('LiberationSans-Regular.ttf'),
    fallbacks: <SfntFont>[face('NotoNaskhArabic-Regular.ttf')],
  );
  for (final String path in args.skip(1)) {
    final File input = File(path);
    final String name = input.uri.pathSegments.last.split('.').first;
    final Uint8List bytes = input.readAsBytesSync();
    final OpcPackage package = OfficeRepair.open(bytes);
    final File pdf = File('${work.path}/$name.pdf')
      ..writeAsBytesSync(
        package.kind == OpcPackageKind.sheet
            // The inputs print without gridlines or headings, like Excel.
            ? OfficePdfExport.workbook(
                SheetDeserializer().read(package),
                fonts: fonts,
                title: name,
                options: const PdfSheetPrintOptions(
                  showGridlines: false,
                  showHeadings: false,
                ),
              )
            : OfficePdfExport.fromBytes(bytes, fonts: fonts, title: name),
      );
    await _raster(pdf, '${out.path}/${name}_quds');
    final Directory lo = Directory('${work.path}/lo')..createSync();
    final ProcessResult r = await Process.run('soffice', <String>[
      '--headless',
      '--convert-to',
      'pdf',
      '--outdir',
      lo.path,
      input.absolute.path,
    ]);
    if (r.exitCode != 0) {
      throw StateError('soffice failed: ${r.stderr}');
    }
    await _raster(File('${lo.path}/$name.pdf'), '${out.path}/${name}_office');
    stdout.writeln('rendered $name');
  }
  work.deleteSync(recursive: true);
}

Future<void> _raster(File pdf, String prefix) async {
  final ProcessResult r = await Process.run('pdftoppm', <String>[
    '-png',
    '-r',
    '80',
    '-f',
    '1',
    '-l',
    '1',
    '-singlefile',
    pdf.path,
    prefix,
  ]);
  if (r.exitCode != 0) {
    throw StateError('pdftoppm failed: ${r.stderr}');
  }
}
