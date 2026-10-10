/// Exports every bundled `.qrep` template with its sample data, then
/// rasterizes page 1 with `pdftoppm` (XLSX / DOCX go through LibreOffice
/// first) for the README gallery.
///
/// Usage: `dart run tool/dump_report_shots.dart <out-dir> [font-dir]`
///
/// `font-dir` defaults to `../quds_office_editor/fonts` (Liberation +
/// Noto Naskh Arabic).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_reports.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/dump_report_shots.dart <out-dir> [font-dir]',
    );
    exitCode = 64;
    return;
  }
  final Directory out = Directory(args[0])..createSync(recursive: true);
  final String fontDir = args.length > 1
      ? args[1]
      : '../quds_office_editor/fonts';
  final ReportFontRegistry fonts = _fonts(fontDir);
  final Directory work = Directory.systemTemp.createTempSync('qrep_shots');
  DateTime clock() => DateTime(2026, 10, 10, 9, 30);

  for (final ReportTemplateInfo info in ReportTemplates.all) {
    final QudsReportEngine engine = QudsReportEngine.fromXml(
      info.xml,
      fonts: fonts,
      userName: 'Quds Office',
      clock: clock,
    );
    final Map<String, Object?> data = info.sampleData();
    final File pdf = File('${work.path}/${info.id}.pdf')
      ..writeAsBytesSync(await engine.exportToPdf(data));
    await _raster(pdf, '${out.path}/report_${info.id}');
    if (info.id == 'sales_performance') {
      await _viaOffice(
        await engine.exportToExcel(data),
        '${work.path}/${info.id}.xlsx',
        '${out.path}/report_${info.id}_xlsx',
      );
      await _viaOffice(
        await engine.exportToWord(data),
        '${work.path}/${info.id}.docx',
        '${out.path}/report_${info.id}_docx',
      );
    }
    stdout.writeln('rendered ${info.id}');
  }
  work.deleteSync(recursive: true);
}

ReportFontRegistry _fonts(String dir) {
  Uint8List read(String file) => File('$dir/$file').readAsBytesSync();
  final ReportFontRegistry fonts = ReportFontRegistry()
    ..registerBytes(
      'Liberation Sans',
      read('LiberationSans-Regular.ttf'),
      bold: read('LiberationSans-Bold.ttf'),
    )
    ..registerBytes(
      'Noto Naskh Arabic',
      read('NotoNaskhArabic-Regular.ttf'),
      bold: read('NotoNaskhArabic-Bold.ttf'),
    )
    ..registerBytes(
      'Liberation Serif',
      read('LiberationSerif-Regular.ttf'),
      bold: read('LiberationSerif-Bold.ttf'),
    )
    ..registerBytes(
      'Liberation Mono',
      read('LiberationMono-Regular.ttf'),
      bold: read('LiberationMono-Bold.ttf'),
    );
  fonts.defaultFamily = 'Liberation Sans';
  return fonts;
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

Future<void> _viaOffice(Uint8List bytes, String path, String prefix) async {
  final File file = File(path)..writeAsBytesSync(bytes);
  final ProcessResult r = await Process.run('soffice', <String>[
    '--headless',
    '--convert-to',
    'pdf',
    '--outdir',
    file.parent.path,
    file.path,
  ]);
  if (r.exitCode != 0) {
    throw StateError('soffice failed: ${r.stderr}');
  }
  final String pdf = '${path.substring(0, path.lastIndexOf('.'))}.pdf';
  await _raster(File(pdf), prefix);
}
