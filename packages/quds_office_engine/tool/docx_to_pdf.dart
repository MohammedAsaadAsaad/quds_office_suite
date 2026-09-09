import 'dart:io';
import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

/// Usage: dart run tool/docx_to_pdf.dart <input.docx> <output.pdf>
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/docx_to_pdf.dart <in.docx> <out.pdf>');
    exitCode = 64;
    return;
  }
  final File input = File(args[0]);
  final File output = File(args[1]);
  if (!input.existsSync()) {
    stderr.writeln('Missing input: ${input.path}');
    exitCode = 66;
    return;
  }
  final Uint8List bytes = input.readAsBytesSync();
  final WmlDocument doc = WordDeserializer().readBytes(bytes);
  final SfntFont? font = _fontFor(doc);
  final Uint8List pdf = OfficePdfExport.word(
    doc,
    font: font,
    title: input.uri.pathSegments.isEmpty
        ? 'Export'
        : input.uri.pathSegments.last,
  );
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(pdf);

  stdout.writeln('paragraphs=${doc.paragraphs.length}');
  stdout.writeln('pdfBytes=${pdf.length}');
  stdout.writeln('font=${font == null ? 'Helvetica' : 'embedded'}');
  stdout.writeln('out=${output.path}');
  for (final WmlParagraph p in doc.paragraphs.take(16)) {
    final String t = p.text.trim();
    if (t.isEmpty) {
      continue;
    }
    stdout.writeln('> ${t.length > 110 ? '${t.substring(0, 110)}…' : t}');
  }
}

SfntFont? _fontFor(WmlDocument doc) {
  final String win = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final List<String> candidates = <String>[
    '$win\\Fonts\\calibri.ttf',
    '$win\\Fonts\\arial.ttf',
    '$win\\Fonts\\segoeui.ttf',
    '$win\\Fonts\\times.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ];
  final Set<int> needed = <int>{};
  for (final WmlParagraph p in doc.paragraphs) {
    for (final int cu in p.text.runes) {
      needed.add(cu);
    }
  }
  SfntFont? best;
  var bestHits = -1;
  for (final String path in candidates) {
    final File file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final SfntFont font = SfntFont.parse(file.readAsBytesSync());
    if (!font.hasTable('glyf')) {
      continue;
    }
    var hits = 0;
    for (final int cp in needed) {
      if (font.glyphIdFor(cp) != 0) {
        hits++;
      }
    }
    if (hits > bestHits) {
      bestHits = hits;
      best = font;
    }
  }
  return best;
}
