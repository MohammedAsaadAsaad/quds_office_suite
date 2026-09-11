import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// Multi-page showcase used by the studio PDF workspace.
Uint8List studioSamplePdf() {
  final _Face? latin = _Face.load(
    resource: 'F1',
    paths: const <String>[
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ],
    extra: _latinCps(),
  );
  final _Face? arabic = _Face.load(
    resource: 'F3',
    paths: const <String>[
      '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
    ],
    extra: _arabicCps(),
  );
  final PdfDocument doc = PdfDocument(
    title: 'Quds PDF Gallery',
    author: 'Quds Office Studio',
  );
  _cover(doc, latin, arabic);
  _type(doc, latin, arabic);
  _arabicPage(doc, latin, arabic);
  _shapes(doc, latin);
  _table(doc, latin, arabic);
  _dashboard(doc, latin, arabic);
  _picture(doc, latin);
  _org(doc, latin, arabic);
  _timeline(doc, latin, arabic);
  _matrix(doc, latin, arabic);
  _links(doc, latin, arabic);
  _wide(doc, latin);
  const List<String> titles = <String>[
    'Cover',
    'Typography',
    'Arabic',
    'Graphics',
    'Table',
    'Dashboard',
    'Image',
    'Architecture',
    'Timeline',
    'Capabilities',
    'Links',
    'Landscape',
  ];
  for (int i = 0; i < titles.length; i++) {
    doc.addOutline(PdfOutlineItem(title: titles[i], pageIndex: i));
  }
  final List<PdfEmbeddedFace> faces = <PdfEmbeddedFace>[
    if (latin != null) latin.embedded,
    if (arabic != null) arabic.embedded,
  ];
  return doc.save(faces: faces, font: latin?.font, subset: latin?.subset);
}

List<int> _latinCps() {
  const String s =
      'Quds Office Suite PDF Gallery ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      'abcdefghijklmnopqrstuvwxyz 0123456789'
      'Typography Graphics Dashboard Image Links Landscape Architecture'
      'Revenue Pipeline North South East West Q1 Q2 Q3 Q4 Capabilities'
      'Helvetica Liberation Noto mixed scripts engine editor COS xref'
      'Flate Identity ToUnicode FontFile incremental annotate form'
      'Display list RenderBox Isolate OpenType glyf subset CIDFont'
      'Bytes Interpret Canvas Save Timeline Matrix Org Chart'
      'Live thumbs ISO 32000-1 parallel writer viewer'
      'Win 61% NPS 72 2.4M M1 M2 M3 M4 M5 M6'
      'The quick brown fox jumps over the lazy dog'
      'Regular Bold Italic 12 pt 18 28 42 48'
      'Click the blue row to jump URI Host callback'
      'Rounded rects ellipses Bezier dash device-independent'
      'A generated 240x120 gradient decoded and painted'
      'Incremental save appends AP Content-stream reflow is out of scope'
      'Embedded TrueType plus Helvetica fallback loads FontFile2'
      'Standard 14 mapping Liberation Sans Courier New Times'
      'Open interpret display list page tree filters security'
      'Find North from the View tab totals stay typed'
      'Region Q1 Q2 Q3 Q4 Cover Arabic Table Image'
      'COS xref ObjStm Flate ASCII85 DCT LZW'
      'Annotate Highlight Ink Note Redact Rotate Merge Extract'
      'GoTo URI Outline bookmarks XFDF AcroForm'
      'Page 1 2 3 4 5 6 7 8 9 10 11 12 of';
  return s.runes.toList();
}

List<int> _arabicCps() {
  const String s =
      'محرر ملفات قوة المحرك والعارض صفحات معاينة حيّة '
      'القدس مكتب مجموعة خطوط مختلطة عربي إنجليزي '
      'لوحة معلومات إيرادات مشاريع خطوط عربية أصيلة '
      'النص العربي يُرسم بالخط المضمّن بعد التشكيل السياقي '
      'أرقام حية من المحرك ليست لقطة شاشة '
      'المخطط الجانبي يقفز بين الصفحات '
      'عارض ومحرر أصلي بلا تحويل سحابي '
      'تفسير مجرى المحتوى قائمة العرض صندوق الرسم '
      'هندسة معمارية مسار زمني قدرات روابط '
      'جدول ربع سنوي شمال جنوب شرق غرب '
      'هذا المحرّر يفتح الملف نفسه الذي يكتبه المحرّك '
      'لا وسيط سحابي ولا تحويل إلى صورة '
      'الخط في المعاينة هو خط الملف المضمّن '
      'قدرات المحرك مكتوبة بصدق بلا مبالغة';
  final Set<int> cps = <int>{};
  for (final ShapedChar ch in ArabicShaper.shape(s)) {
    cps.add(ch.codePoint);
  }
  cps.addAll(s.runes);
  return cps.toList();
}

void _banner(
  PdfCanvas c,
  _Face? latin,
  String hex,
  String title,
  String page,
) {
  c.fillRect(0, 0, 595.28, 64, hex);
  c.fillRect(0, 64, 595.28, 3, 'C9A227');
  _run(c, latin, 36, 40, 18, title, 'FFFFFF', bold: true);
  _run(c, latin, 500, 40, 11, page, 'D6DEE8');
}

void _footer(PdfCanvas c, _Face? latin, String text) {
  c.fillRect(0, 800, 595.28, 42, 'F4F6F9');
  _run(c, latin, 36, 826, 9, text, '5A6573');
  c.endText();
}

void _cover(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  c.fillRect(0, 0, 595.28, 841.89, '0B1F3A');
  c.fillRect(0, 0, 18, 841.89, 'C9A227');
  c.fillRect(40, 96, 515, 4, 'C9A227');
  _run(c, latin, 48, 168, 14, 'QUDS OFFICE SUITE', 'C9A227', bold: true);
  _run(c, latin, 48, 230, 46, 'PDF Gallery', 'FFFFFF', bold: true);
  _run(c, latin, 48, 278, 16, 'Native engine  ·  RenderBox editor  ·  12 pages', 'D6DEE8');
  _shaped(c, arabic, 48, 330, 20, 'عارض ومحرر PDF أصلي — بلا تحويل سحابي', 'F4E4A6');
  const List<({String hex, String k, String v})> tiles =
      <({String hex, String k, String v})>[
    (hex: '2B579A', k: '12 pages', v: 'Live thumbs'),
    (hex: '217346', k: 'Glyf embed', v: 'ToUnicode'),
    (hex: 'B7472A', k: 'Annotate', v: 'Incremental'),
    (hex: 'C9A227', k: 'Find / print', v: 'Isolate open'),
  ];
  for (int i = 0; i < tiles.length; i++) {
    final double x = 48 + (i % 2) * 250;
    final double y = 400 + (i ~/ 2) * 110;
    c
      ..setFillColor(tiles[i].hex)
      ..roundedRect(x, y, 230, 96, 12)
      ..fill();
    _run(c, latin, x + 18, y + 40, 16, tiles[i].k, 'FFFFFF', bold: true);
    _run(c, latin, x + 18, y + 68, 12, tiles[i].v, 'F4F6F9');
  }
  _run(c, latin, 48, 780, 11, 'ISO 32000-1  ·  Parallel to the PdfDocument writer', '8A93A3');
  c.endText();
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _type(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '0B1F3A', 'Typography  ·  خطوط', '02 / 12');
  _run(c, latin, 36, 110, 28, 'A face that matches the file', '0B1F3A', bold: true);
  _run(
    c,
    latin,
    36,
    148,
    12,
    'Embedded TrueType (glyf) plus Helvetica fallback. The viewer loads /FontFile2.',
    '3D4654',
  );
  _run(c, latin, 36, 200, 42, 'Aa Bb 123', '2B579A', bold: true);
  _run(c, latin, 36, 250, 18, 'Regular 18 pt  ·  The quick brown fox jumps.', '1A1A1A');
  _run(c, latin, 36, 280, 18, 'Bold 18 pt  ·  The quick brown fox jumps.', '1A1A1A', bold: true);
  _run(c, latin, 36, 310, 18, 'Italic 18 pt  ·  The quick brown fox jumps.', '1A1A1A', italic: true);
  _run(c, latin, 36, 350, 12, 'Regular 12 pt  ·  Liberation Sans metrics, not the theme Naskh.', '5A6573');
  _mixed(
    c,
    latin,
    arabic,
    36,
    400,
    16,
    'Mixed: Quds مكتب  ·  12.5%  ·  RTL + LTR on one line.',
    '2B579A',
  );
  c
    ..setStrokeColor('C9A227')
    ..setLineWidth(1.2)
    ..moveTo(36, 440)
    ..lineTo(559, 440)
    ..stroke();
  _run(c, latin, 36, 470, 13, 'Standard 14 mapping: Helvetica → Liberation Sans', '5A6573');
  _run(c, latin, 36, 500, 13, 'CIDFontType2 + Identity-H + ToUnicode for subset faces.', '5A6573');
  _run(c, latin, 36, 560, 72, 'Quds', '0B1F3A', bold: true);
  _footer(c, latin, 'Open the saved file in any viewer — the same glyf is on the page.');
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _arabicPage(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '1B4332', 'Arabic  ·  تشكيل سياقي', '03 / 12');
  _shaped(c, arabic, 36, 130, 26, 'الخط في المعاينة هو خط الملف المضمّن', '0B1F3A');
  _shaped(
    c,
    arabic,
    36,
    180,
    16,
    'هذا المحرّر يفتح الملف نفسه الذي يكتبه المحرّك.',
    '3D4654',
  );
  _shaped(c, arabic, 36, 230, 16, 'لا وسيط سحابي ولا تحويل إلى صورة.', '3D4654');
  const List<String> lines = <String>[
    'تفسير مجرى المحتوى → قائمة العرض → صندوق الرسم',
    'قوة المحرك والعارض في صفحات ومعاينة حيّة',
    'خطوط مختلطة عربي إنجليزي على سطر واحد',
  ];
  for (int i = 0; i < lines.length; i++) {
    final double y = 300 + i * 70;
    c.fillRect(36, y, 523, 56, i.isEven ? 'F3F6FB' : 'FFF8E7');
    _shaped(c, arabic, 52, y + 36, 16, lines[i], '0B1F3A');
  }
  _mixed(c, latin, arabic, 36, 560, 14, 'Quds مكتب  ·  COS / xref  ·  مجموعة القدس', '2B579A');
  _footer(c, latin, 'Arabic is shaped before CID emission; the viewer does not reshape.');
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _shapes(PdfDocument doc, _Face? latin) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '217346', 'Graphics  ·  paths, curves, dashes', '04 / 12');
  c
    ..setFillColor('2B579A')
    ..roundedRect(40, 100, 160, 100, 16)
    ..fill()
    ..setFillColor('C9A227')
    ..ellipse(230, 100, 140, 100)
    ..fill()
    ..setStrokeColor('B7472A')
    ..setLineWidth(3)
    ..setDash(<double>[8, 5])
    ..rect(400, 100, 150, 100)
    ..stroke()
    ..resetDash();
  c
    ..setFillColor('0B1F3A')
    ..moveTo(80, 280)
    ..curveTo(180, 200, 260, 360, 360, 260)
    ..curveTo(430, 200, 500, 320, 540, 240)
    ..setStrokeColor('2B579A')
    ..setLineWidth(2.5)
    ..stroke();
  for (int i = 0; i < 6; i++) {
    c
      ..setFillColor(i.isEven ? '2B579A' : 'C9A227')
      ..ellipse(50.0 + i * 85, 400, 54, 54)
      ..fill();
  }
  _run(
    c,
    latin,
    40,
    500,
    13,
    'Rounded rects, ellipses, Bezier, dash — device-independent list.',
    '3D4654',
  );
  for (int i = 0; i < 8; i++) {
    c.fillRect(40.0 + i * 64, 540, 52, 18.0 + i * 14, i.isEven ? '0B1F3A' : '2B579A');
  }
  _footer(c, latin, 'Every verb is a typed PdfPaintOp. No screenshot, no HTML canvas.');
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _table(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '2B579A', 'Table  ·  quarterly pipeline', '05 / 12');
  const List<List<String>> rows = <List<String>>[
    <String>['Region', 'Q1', 'Q2', 'Q3', 'Q4'],
    <String>['North', '120', '134', '141', '158'],
    <String>['South', '88', '91', '104', '119'],
    <String>['East', '76', '82', '79', '95'],
    <String>['West', '101', '110', '126', '140'],
  ];
  const List<double> cols = <double>[160, 80, 80, 80, 80];
  var y = 100.0;
  for (int r = 0; r < rows.length; r++) {
    var x = 40.0;
    c.fillRect(40, y, 480, 36, r == 0 ? '0B1F3A' : (r.isOdd ? 'F3F6FB' : 'FFFFFF'));
    for (int i = 0; i < rows[r].length; i++) {
      _run(
        c,
        latin,
        x + 10,
        y + 24,
        12,
        rows[r][i],
        r == 0 ? 'FFFFFF' : '1A1A1A',
        bold: r == 0,
      );
      x += cols[i];
    }
    y += 36;
  }
  c
    ..setStrokeColor('C5CDD8')
    ..setLineWidth(0.6)
    ..rect(40, 100, 480, 180)
    ..stroke();
  _run(c, latin, 40, 320, 12, 'Totals stay typed in the model. Find “North” from the View tab.', '5A6573');
  _shaped(c, arabic, 40, 360, 14, 'جدول ربع سنوي — شمال جنوب شرق غرب', '0B1F3A');
  const List<int> spark = <int>[120, 134, 141, 158, 88, 91, 104, 119];
  for (int i = 0; i < spark.length; i++) {
    final double h = spark[i] * 1.4;
    c.fillRect(40.0 + i * 64, 700 - h, 48, h, i < 4 ? '2B579A' : 'C9A227');
  }
  _footer(c, latin, 'Typed COS numbers — extract and find share the same runs.');
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _dashboard(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, 'B7472A', 'Dashboard  ·  لوحة', '06 / 12');
  final List<({String k, String v, String hex})> cards =
      <({String k, String v, String hex})>[
    (k: 'Revenue', v: '2.4M', hex: '2B579A'),
    (k: 'Win 61%', v: '61%', hex: '217346'),
    (k: 'NPS 72', v: '72', hex: 'C9A227'),
  ];
  for (int i = 0; i < cards.length; i++) {
    final double x = 36.0 + i * 180;
    c
      ..setFillColor(cards[i].hex)
      ..roundedRect(x, 100, 164, 88, 12)
      ..fill();
    _run(c, latin, x + 16, 134, 12, cards[i].k, 'FFFFFF');
    _run(c, latin, x + 16, 168, 22, cards[i].v, 'FFFFFF', bold: true);
  }
  const List<int> bars = <int>[40, 70, 55, 90, 64, 80];
  for (int i = 0; i < bars.length; i++) {
    final double h = bars[i] * 2.2;
    c.fillRect(60.0 + i * 80, 360 - h, 48, h, i.isEven ? '2B579A' : '0B1F3A');
    _run(c, latin, 68.0 + i * 80, 380, 10, 'M${i + 1}', '5A6573');
  }
  _shaped(c, arabic, 36, 430, 16, 'أرقام حية من المحرك — ليست لقطة شاشة.', '0B1F3A');
  _footer(c, latin, 'KPI tiles and bars are path fills — zoom never pixelates.');
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _picture(PdfDocument doc, _Face? latin) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '0B1F3A', 'Image XObject  ·  Flate RGB', '07 / 12');
  _run(
    c,
    latin,
    36,
    100,
    13,
    'A generated 240x120 gradient, decoded and painted by the viewer.',
    '3D4654',
  );
  c.drawImage('Im1', 36, 140, 523, 240);
  _run(c, latin, 36, 410, 12, 'JPEG/Flate images use the same display-list blit as Office export.', '5A6573');
  c.drawImage('Im2', 36, 450, 250, 160);
  c.drawImage('Im3', 309, 450, 250, 160);
  _footer(c, latin, 'XObject /Do — DCT and Flate, not a Flutter AssetImage.');
  doc.addPage(
    PdfPage(
      width: 595.28,
      height: 841.89,
      content: c.toStream(),
      images: <PdfEmbeddedImage>[
        PdfEmbeddedImage(name: 'Im1', width: 240, height: 120, bytes: _gradient(240, 120, 0)),
        PdfEmbeddedImage(name: 'Im2', width: 160, height: 100, bytes: _gradient(160, 100, 1)),
        PdfEmbeddedImage(name: 'Im3', width: 160, height: 100, bytes: _gradient(160, 100, 2)),
      ],
    ),
  );
}

void _org(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '2B579A', 'Architecture  ·  هندسة', '08 / 12');
  const List<({double x, double y, String t, String hex})> boxes =
      <({double x, double y, String t, String hex})>[
    (x: 190, y: 110, t: 'PdfFile.open', hex: '0B1F3A'),
    (x: 40, y: 240, t: 'COS / xref', hex: '2B579A'),
    (x: 220, y: 240, t: 'Filters', hex: '217346'),
    (x: 400, y: 240, t: 'Security', hex: 'B7472A'),
    (x: 130, y: 390, t: 'Interpreter', hex: '2B579A'),
    (x: 330, y: 390, t: 'Display list', hex: 'C9A227'),
    (x: 190, y: 540, t: 'RenderBox', hex: '0B1F3A'),
  ];
  for (final ({double x, double y, String t, String hex}) b in boxes) {
    c
      ..setFillColor(b.hex)
      ..roundedRect(b.x, b.y, 170, 56, 10)
      ..fill();
    _run(c, latin, b.x + 16, b.y + 36, 13, b.t, b.hex == 'C9A227' ? '0B1F3A' : 'FFFFFF', bold: true);
  }
  c
    ..setStrokeColor('C5CDD8')
    ..setLineWidth(1.4)
    ..moveTo(275, 166)
    ..lineTo(125, 240)
    ..moveTo(275, 166)
    ..lineTo(305, 240)
    ..moveTo(275, 166)
    ..lineTo(485, 240)
    ..moveTo(125, 296)
    ..lineTo(215, 390)
    ..moveTo(305, 296)
    ..lineTo(415, 390)
    ..moveTo(215, 446)
    ..lineTo(275, 540)
    ..moveTo(415, 446)
    ..lineTo(275, 540)
    ..stroke();
  _shaped(c, arabic, 36, 640, 14, 'تفسير مجرى المحتوى قائمة العرض صندوق الرسم', '0B1F3A');
  _footer(c, latin, 'Engine stays pure Dart. The editor never imports the COS tree.');
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _timeline(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '0B1F3A', 'Timeline  ·  مسار', '09 / 12');
  c
    ..setStrokeColor('C9A227')
    ..setLineWidth(3)
    ..moveTo(80, 200)
    ..lineTo(80, 680)
    ..stroke();
  const List<({String t, String d})> steps = <({String t, String d})>[
    (t: 'Bytes', d: 'Open payload on an isolate'),
    (t: 'COS', d: 'xref table, ObjStm, repair'),
    (t: 'Interpret', d: 'Content stream → typed ops'),
    (t: 'Canvas', d: 'PaintPdfDisplayList on a RenderBox'),
    (t: 'Save', d: 'Incremental append of /AP'),
  ];
  for (int i = 0; i < steps.length; i++) {
    final double y = 190 + i * 100;
    c
      ..setFillColor(i == 4 ? 'C9A227' : '2B579A')
      ..ellipse(62, y, 36, 36)
      ..fill();
    _run(c, latin, 74, y + 24, 12, '${i + 1}', 'FFFFFF', bold: true);
    _run(c, latin, 120, y + 16, 16, steps[i].t, '0B1F3A', bold: true);
    _run(c, latin, 120, y + 38, 12, steps[i].d, '5A6573');
  }
  _shaped(c, arabic, 120, 720, 14, 'مسار زمني من البايت إلى الحفظ التزايدي', '0B1F3A');
  _footer(c, latin, 'Phase 6 file stack — not a rewrite of the PdfDocument writer.');
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _matrix(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '217346', 'Capabilities  ·  قدرات', '10 / 12');
  const List<({String k, bool ok})> rows = <({String k, bool ok})>[
    (k: 'COS + xref + ObjStm + incremental', ok: true),
    (k: 'Flate / ASCII85 / LZW / DCT', ok: true),
    (k: 'Standard security Rev 2-4', ok: true),
    (k: 'Embedded glyf + ToUnicode', ok: true),
    (k: 'Annotate / XFDF / page ops', ok: true),
    (k: 'CFF / FontFile3', ok: false),
    (k: 'JBIG2 / JPX / CCITT', ok: false),
    (k: 'Content-stream reflow', ok: false),
  ];
  for (int i = 0; i < rows.length; i++) {
    final double y = 100 + i * 72;
    c.fillRect(36, y, 523, 60, i.isOdd ? 'F3F6FB' : 'FFFFFF');
    c
      ..setFillColor(rows[i].ok ? '217346' : 'B7472A')
      ..ellipse(52, y + 16, 28, 28)
      ..fill();
    _run(c, latin, 56, y + 36, 12, rows[i].ok ? 'OK' : 'NO', 'FFFFFF', bold: true);
    _run(c, latin, 100, y + 36, 14, rows[i].k, '1A1A1A');
  }
  _shaped(c, arabic, 36, 690, 13, 'قدرات المحرك مكتوبة بصدق — بلا مبالغة.', '0B1F3A');
  _footer(c, latin, 'Honesty over marketing — STANDARDS lists the remaining limits.');
  doc.addPage(PdfPage(width: 595.28, height: 841.89, content: c.toStream()));
}

void _links(PdfDocument doc, _Face? latin, _Face? arabic) {
  final PdfCanvas c = PdfCanvas(595.28, 841.89);
  _banner(c, latin, '2B579A', 'Links & outlines', '11 / 12');
  _run(c, latin, 36, 110, 14, 'Click the blue row to jump to the cover (GoTo).', '1A1A1A');
  c.fillRect(36, 140, 360, 28, 'E8F0FA');
  _run(c, latin, 48, 160, 13, 'Back to cover', '2B579A', bold: true);
  _run(c, latin, 36, 210, 14, 'URI actions call the host callback — never /Launch.', '1A1A1A');
  c.fillRect(36, 240, 360, 28, 'FFF4D6');
  _run(c, latin, 48, 260, 13, 'https://pub.dev/packages/quds_office_engine', 'B7472A');
  _shaped(c, arabic, 36, 320, 16, 'المخطط الجانبي يقفز بين الصفحات.', '0B1F3A');
  c.fillRect(36, 380, 360, 28, 'F3F6FB');
  _run(c, latin, 48, 400, 13, 'Jump to the dashboard', '217346', bold: true);
  _footer(c, latin, 'Hotspots are PdfLinkAction values on the display list.');
  doc.addPage(
    PdfPage(
      width: 595.28,
      height: 841.89,
      content: c.toStream(),
      links: const <PdfLinkAnnot>[
        PdfLinkAnnot(x: 36, y: 140, width: 360, height: 28, destPage: 0, destY: 0),
        PdfLinkAnnot(
          x: 36,
          y: 240,
          width: 360,
          height: 28,
          uri: 'https://pub.dev/packages/quds_office_engine',
        ),
        PdfLinkAnnot(x: 36, y: 380, width: 360, height: 28, destPage: 5, destY: 0),
      ],
    ),
  );
}

void _wide(PdfDocument doc, _Face? latin) {
  const double w = 841.89;
  const double h = 595.28;
  final PdfCanvas c = PdfCanvas(w, h);
  c.fillRect(0, 0, w, 56, '0B1F3A');
  c.fillRect(0, 56, w, 3, 'C9A227');
  _run(c, latin, 36, 36, 18, 'Landscape  ·  open → interpret → display list → RenderBox', 'FFFFFF', bold: true);
  _run(c, latin, 720, 36, 11, '12 / 12', 'D6DEE8');
  const List<String> steps = <String>['Bytes', 'COS', 'Display', 'Canvas', 'Save'];
  for (int i = 0; i < steps.length; i++) {
    final double x = 40.0 + i * 155;
    c
      ..setFillColor(i == 4 ? 'C9A227' : '2B579A')
      ..roundedRect(x, 160, 130, 80, 10)
      ..fill();
    _run(
      c,
      latin,
      x + 18,
      208,
      14,
      steps[i],
      i == 4 ? '0B1F3A' : 'FFFFFF',
      bold: true,
    );
    if (i < steps.length - 1) {
      c
        ..setFillColor('C9A227')
        ..moveTo(x + 134, 196)
        ..lineTo(x + 150, 200)
        ..lineTo(x + 134, 204)
        ..closePath()
        ..fill();
    }
  }
  _run(
    c,
    latin,
    40,
    320,
    13,
    'Incremental save appends /AP. Content-stream reflow is out of scope.',
    '3D4654',
  );
  c.endText();
  doc.addPage(PdfPage(width: w, height: h, content: c.toStream()));
}

void _run(
  PdfCanvas canvas,
  _Face? face,
  double x,
  double y,
  double size,
  String text,
  String color, {
  bool bold = false,
  bool italic = false,
}) {
  if (face == null) {
    canvas.showLatin(x: x, y: y, fontSize: size, text: text, color: color);
    return;
  }
  var cx = x;
  for (final int cp in text.runes) {
    final int old = face.font.glyphIdFor(cp);
    final int gid = face.subset.unicodeToNewGlyph[cp] ?? face.subset.oldToNewGlyph[old] ?? 0;
    if (gid != 0) {
      canvas.showGlyph(
        x: cx,
        y: y,
        fontSize: size,
        glyphId: gid,
        color: color,
        bold: bold,
        italic: italic,
        fontName: face.resource,
      );
    } else if (cp >= 32 && cp < 127) {
      canvas.showLatin(
        x: cx,
        y: y,
        fontSize: size,
        text: String.fromCharCode(cp),
        color: color,
      );
    }
    cx += face.font.advanceWidth(old) / face.font.unitsPerEm * size;
  }
}

void _shaped(
  PdfCanvas canvas,
  _Face? face,
  double x,
  double y,
  double size,
  String text,
  String color,
) {
  if (face == null) {
    canvas.showLatin(x: x, y: y, fontSize: size, text: text, color: color);
    return;
  }
  final List<ShapedChar> shaped = ArabicShaper.shape(text);
  var width = 0.0;
  for (final ShapedChar ch in shaped) {
    if (ch.advanceFactor == 0) {
      continue;
    }
    final int old = face.font.glyphIdFor(ch.codePoint);
    width += face.font.advanceWidth(old) / face.font.unitsPerEm * size;
  }
  var cx = x + width;
  for (final ShapedChar ch in shaped) {
    final int old = face.font.glyphIdFor(ch.codePoint);
    final int gid =
        face.subset.unicodeToNewGlyph[ch.codePoint] ??
        face.subset.oldToNewGlyph[old] ??
        0;
    final double adv = face.font.advanceWidth(old) / face.font.unitsPerEm * size;
    if (ch.advanceFactor != 0) {
      cx -= adv;
    }
    if (gid != 0) {
      canvas.showGlyph(
        x: cx,
        y: y,
        fontSize: size,
        glyphId: gid,
        color: color,
        fontName: face.resource,
      );
    }
  }
}

void _mixed(
  PdfCanvas canvas,
  _Face? latin,
  _Face? arabic,
  double x,
  double y,
  double size,
  String text,
  String color,
) {
  var cx = x;
  final StringBuffer latinRun = StringBuffer();
  void flushLatin() {
    if (latinRun.isEmpty) {
      return;
    }
    final String part = latinRun.toString();
    latinRun.clear();
    _run(canvas, latin, cx, y, size, part, color);
    if (latin != null) {
      for (final int cp in part.runes) {
        cx += latin.font.advanceWidth(latin.font.glyphIdFor(cp)) /
            latin.font.unitsPerEm *
            size;
      }
    } else {
      cx += part.length * size * 0.5;
    }
  }

  final List<int> cps = text.runes.toList();
  var i = 0;
  while (i < cps.length) {
    if (OfficeTypeface.isRtlCodePoint(cps[i])) {
      flushLatin();
      final int start = i;
      while (i < cps.length && OfficeTypeface.isRtlCodePoint(cps[i])) {
        i++;
      }
      final String ar = String.fromCharCodes(cps.sublist(start, i));
      var w = 0.0;
      if (arabic != null) {
        for (final ShapedChar ch in ArabicShaper.shape(ar)) {
          if (ch.advanceFactor == 0) {
            continue;
          }
          w += arabic.font.advanceWidth(arabic.font.glyphIdFor(ch.codePoint)) /
              arabic.font.unitsPerEm *
              size;
        }
      } else {
        w = ar.length * size * 0.5;
      }
      _shaped(canvas, arabic, cx, y, size, ar, color);
      cx += w;
      continue;
    }
    latinRun.writeCharCode(cps[i]);
    i++;
  }
  flushLatin();
}

Uint8List _gradient(int w, int h, int variant) {
  final Uint8List out = Uint8List(w * h * 3);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int i = (y * w + x) * 3;
      if (variant == 1) {
        out[i] = (40 + y * 180 / h).round();
        out[i + 1] = (80 + x * 140 / w).round();
        out[i + 2] = (200 - y * 80 / h).round();
      } else if (variant == 2) {
        out[i] = (200 - x * 120 / w).round();
        out[i + 1] = (60 + y * 100 / h).round();
        out[i + 2] = (40 + x * 80 / w).round();
      } else {
        out[i] = (20 + x * 200 / w).round();
        out[i + 1] = (40 + y * 120 / h).round();
        out[i + 2] = (160 - x * 80 / w).round();
      }
    }
  }
  return out;
}

class _Face {
  _Face(this.font, this.subset, this.resource);

  final SfntFont font;
  final FontSubset subset;
  final String resource;

  PdfEmbeddedFace get embedded =>
      PdfEmbeddedFace(subset: subset, source: font, resourceName: resource);

  static _Face? load({
    required String resource,
    required List<String> paths,
    required List<int> extra,
  }) {
    if (kIsWeb) {
      return null;
    }
    for (final String path in paths) {
      final File file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final SfntFont font = SfntFont.parse(file.readAsBytesSync());
      final Set<int> cps = <int>{
        ...extra,
        32,
        46,
        45,
        47,
        0x2013,
        0x2014,
        0x201C,
        0x201D,
        0x2192,
      };
      return _Face(font, FontSubsetter(font).subset(cps), resource);
    }
    return null;
  }
}
