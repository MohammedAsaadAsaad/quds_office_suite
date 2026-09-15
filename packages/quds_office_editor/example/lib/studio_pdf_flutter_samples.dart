import 'dart:math' as math;
import 'dart:typed_data';

import 'package:quds_office_engine/pdf_widgets.dart' as pw;

import 'studio_pdf_faces.dart';

/// Layout twins: transform, clip, slots, and direction-aware pins.
Uint8List studioFlutterTwinsPdf() {
  final pw.Document doc = pw.Document(
    title: 'Flutter twins',
    author: 'Quds Studio',
    font: StudioPdfFaces.tajawal(),
    fontBold: StudioPdfFaces.tajawalBold(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
      build: (pw.Context context) => <pw.Widget>[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const pw.BoxDecoration(color: '0F766E'),
          child: pw.Text(
            'FLUTTER TWINS',
            style: const pw.TextStyle(
              fontSize: 11,
              color: 'CCFBF1',
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'General widgets',
          style: const pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: '134E4A',
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Transform, clip, and slot widgets. No document template.',
          style: const pw.TextStyle(fontSize: 10, color: '57534E'),
        ),
        pw.SizedBox(height: 14),
        _label('Transform  ·  RotatedBox'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: <pw.Widget>[
            pw.Container(
              width: 88,
              height: 48,
              alignment: pw.Alignment.center,
              decoration: const pw.BoxDecoration(color: 'CCFBF1'),
              child: pw.Transform.rotate(
                angle: -math.pi / 10,
                child: pw.Text(
                  'مسودة',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: '0F766E',
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Container(
              width: 48,
              height: 72,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: '99F6E4'),
              ),
              child: pw.RotatedBox(
                quarterTurns: 1,
                child: pw.Text(
                  'SIDE',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: '134E4A',
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Transform.scale(
              scale: 1.15,
              child: pw.Text(
                '1.15×',
                style: const pw.TextStyle(fontSize: 12, color: '0F766E'),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Transform.translate(
              offset: const pw.PwOffset(0, 6),
              child: pw.Text(
                'shifted',
                style: const pw.TextStyle(fontSize: 11, color: '78716C'),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        _label('ClipRect  ·  ClipRRect  ·  ClipOval  ·  ClipPath'),
        pw.SizedBox(height: 6),
        pw.Row(
          children: <pw.Widget>[
            _clipCard(pw.ClipRect(child: _swatch('134E4A')), 'rect'),
            pw.SizedBox(width: 8),
            _clipCard(
              pw.ClipRRect(borderRadius: 10, child: _swatch('0F766E')),
              'round',
            ),
            pw.SizedBox(width: 8),
            _clipCard(pw.ClipOval(child: _swatch('14B8A6')), 'oval'),
            pw.SizedBox(width: 8),
            _clipCard(
              pw.ClipPath(
                clipper: (path, size) {
                  path.moveTo(size.width / 2, 0);
                  path.lineTo(size.width, size.height);
                  path.lineTo(0, size.height);
                  path.close();
                },
                child: _swatch('115E59'),
              ),
              'path',
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        _label('FractionallySizedBox  ·  LimitedBox'),
        pw.SizedBox(height: 6),
        pw.FractionallySizedBox(
          widthFactor: 0.55,
          alignment: pw.AlignmentDirectional.centerStart,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const pw.BoxDecoration(color: 'CCFBF1'),
            child: pw.Text(
              '55% of the line',
              style: const pw.TextStyle(fontSize: 10, color: '134E4A'),
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.LimitedBox(
          maxHeight: 22,
          child: pw.Container(
            height: 80,
            decoration: const pw.BoxDecoration(color: '99F6E4'),
            alignment: pw.AlignmentDirectional.centerStart,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Text(
              'LimitedBox caps an 80-pt child at 22',
              style: const pw.TextStyle(fontSize: 9, color: '134E4A'),
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        _label('Baseline  ·  IntrinsicHeight'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            pw.Baseline(
              baseline: 16,
              child: pw.Text(
                'Ag',
                style: const pw.TextStyle(fontSize: 16, color: '134E4A'),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Baseline(
              baseline: 16,
              child: pw.Container(
                width: 18,
                height: 8,
                decoration: const pw.BoxDecoration(color: '0F766E'),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Baseline(
              baseline: 16,
              child: pw.Text(
                'share one line',
                style: const pw.TextStyle(fontSize: 9, color: '57534E'),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.IntrinsicHeight(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              pw.Expanded(child: _stretchCard('Short', '0F766E')),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _stretchCard('Taller card\nsecond line', '134E4A'),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        _label('OverflowBox inside ClipRect'),
        pw.SizedBox(height: 6),
        pw.ClipRect(
          child: pw.Container(
            width: 160,
            height: 28,
            color: 'F0FDFA',
            child: pw.OverflowBox(
              maxWidth: 220,
              alignment: pw.Alignment.center,
              child: pw.Container(
                width: 220,
                height: 18,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(color: '5EEAD4'),
                child: pw.Text(
                  'overflows the slot and is clipped',
                  style: const pw.TextStyle(fontSize: 8, color: '134E4A'),
                ),
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        _label('CustomPaint  ·  CustomMultiChildLayout'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.CustomPaint(
              size: const pw.PwSize(56, 56),
              painter: (canvas, size) {
                canvas.setFillColor('0F766E');
                canvas.moveTo(size.width / 2, 4);
                canvas.lineTo(size.width - 4, size.height / 2);
                canvas.lineTo(size.width / 2, size.height - 4);
                canvas.lineTo(4, size.height / 2);
                canvas.closePath();
                canvas.fill();
              },
            ),
            pw.SizedBox(width: 12),
            pw.CustomMultiChildLayout(
              size: (constraints) => const pw.PwSize(220, 56),
              performLayout: (host) {
                host.layoutChild(
                  'card',
                  pw.BoxConstraints.tightFor(width: 220, height: 56),
                );
                host.positionChild('card', pw.PwOffset.zero);
                final pw.PwSize seal = host.layoutChild(
                  'seal',
                  pw.BoxConstraints.tightFor(width: 28, height: 28),
                );
                host.positionChild(
                  'seal',
                  pw.PwOffset(220 - seal.width - 8, (56 - seal.height) / 2),
                );
              },
              children: <pw.LayoutId>[
                pw.LayoutId(
                  id: 'card',
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: 'F0FDFA',
                      border: pw.Border.all(color: '99F6E4'),
                      borderRadius: 4,
                    ),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Placed by a function',
                      style: const pw.TextStyle(fontSize: 10, color: '134E4A'),
                    ),
                  ),
                ),
                pw.LayoutId(
                  id: 'seal',
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                      color: '0F766E',
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        _label('Radio  ·  Switch  ·  VerticalDivider  ·  Icon'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: <pw.Widget>[
            const pw.Radio(value: true),
            pw.SizedBox(width: 4),
            pw.Text('On', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 10),
            const pw.Radio(),
            pw.SizedBox(width: 4),
            pw.Text('Off', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 12),
            const pw.Switch(value: true),
            pw.SizedBox(width: 8),
            const pw.Switch(),
            pw.SizedBox(width: 8),
            const pw.VerticalDivider(width: 12, indent: 2, endIndent: 2),
            const pw.Icon(0x51, color: '0F766E'),
            pw.SizedBox(width: 4),
            pw.Text(
              'glyph Q',
              style: const pw.TextStyle(fontSize: 10, color: '57534E'),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        _label('TextOverflow.ellipsis'),
        pw.SizedBox(height: 6),
        pw.SizedBox(
          width: 220,
          child: pw.Text(
            'This line is longer than the slot and must end with an ellipsis.',
            maxLines: 1,
            overflow: pw.TextOverflow.ellipsis,
            style: const pw.TextStyle(fontSize: 10, color: '292524'),
          ),
        ),
        pw.SizedBox(height: 14),
        _label('ListTile'),
        pw.ListTile(
          leading: const pw.Icon(0x51, size: 18, color: '0F766E'),
          title: pw.Text(
            'Harbour close',
            style: const pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: '134E4A',
            ),
          ),
          subtitle: pw.Text(
            'Leading, title, subtitle, trailing',
            style: const pw.TextStyle(fontSize: 9, color: '78716C'),
          ),
          trailing: pw.Text(
            '12',
            style: const pw.TextStyle(fontSize: 12, color: '0F766E'),
          ),
        ),
        const pw.NewPage(),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const pw.BoxDecoration(color: '134E4A'),
                child: pw.Text(
                  'اتجاه',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: 'CCFBF1',
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'الحافة تبدأ من اليمين',
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: '134E4A',
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Padding(
                padding: const pw.EdgeInsetsDirectional.only(start: 28),
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(color: 'CCFBF1'),
                  child: pw.Text(
                    'هامش البداية ٢٨ نقطة',
                    style: const pw.TextStyle(fontSize: 11, color: '134E4A'),
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 48,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: '99F6E4'),
                ),
                child: pw.Stack(
                  children: <pw.Widget>[
                    pw.Positioned.directional(
                      start: 8,
                      top: 12,
                      child: pw.Text(
                        'مثبت عند البداية',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: '0F766E',
                        ),
                      ),
                    ),
                    pw.Positioned.directional(
                      end: 8,
                      top: 12,
                      child: pw.Text(
                        'النهاية',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: '78716C',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 36,
                color: 'F0FDFA',
                child: pw.Align(
                  alignment: pw.AlignmentDirectional.centerStart,
                  child: pw.Padding(
                    padding: const pw.EdgeInsetsDirectional.only(start: 8),
                    child: pw.Text(
                      'محاذاة البداية',
                      style: const pw.TextStyle(fontSize: 11, color: '134E4A'),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.ListTile(
                leading: const pw.Icon(0x0642, size: 18, color: '0F766E'),
                title: pw.Text(
                  'قائمة عربية',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: '134E4A',
                  ),
                ),
                subtitle: pw.Text(
                  'العنوان واللاحقة ينقلبان مع الاتجاه',
                  style: const pw.TextStyle(fontSize: 9, color: '78716C'),
                ),
                trailing: const pw.Switch(value: true, activeColor: '0F766E'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _label(String text) {
  return pw.Text(
    text,
    style: const pw.TextStyle(
      fontSize: 8,
      color: '0F766E',
      fontWeight: pw.FontWeight.bold,
    ),
  );
}

pw.Widget _swatch(String color) {
  return pw.Container(
    width: 48,
    height: 40,
    color: color,
  );
}

pw.Widget _clipCard(pw.Widget clip, String name) {
  return pw.Column(
    children: <pw.Widget>[
      clip,
      pw.SizedBox(height: 3),
      pw.Text(name, style: const pw.TextStyle(fontSize: 8, color: '78716C')),
    ],
  );
}

pw.Widget _stretchCard(String text, String color) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(color: color),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 9, color: 'F0FDFA'),
    ),
  );
}
