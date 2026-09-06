import '../../xml/xml_reader.dart';

/// Parsed `styles.xml` subset: numFmts + cellXfs.
class SmlStyleSheet {
  /// SmlStyleSheet API.
  SmlStyleSheet({Map<int, String>? numFmts, List<int>? cellXfsNumFmt})
    : numFmts = numFmts ?? Map<int, String>.from(_builtIn),
      cellXfsNumFmt = cellXfsNumFmt ?? <int>[0];

  /// numFmts API.
  final Map<int, String> numFmts;

  /// cellXfsNumFmt API.
  final List<int> cellXfsNumFmt;

  /// parse API.
  factory SmlStyleSheet.parse(String xml) {
    final SmlStyleSheet sheet = SmlStyleSheet();
    final XmlPullReader reader = XmlPullReader(xml);
    while (reader.next()) {
      if (reader.eventType != XmlEventType.startElement) {
        continue;
      }
      if (reader.localName == 'numFmt') {
        final int id = int.parse(reader.getAttribute('numFmtId') ?? '0');
        sheet.numFmts[id] = reader.getAttribute('formatCode') ?? 'General';
      } else if (reader.localName == 'xf') {
        sheet.cellXfsNumFmt.add(
          int.parse(reader.getAttribute('numFmtId') ?? '0'),
        );
      }
    }
    return sheet;
  }

  /// format API.
  String format(Object? value, int styleIndex) {
    final int numFmtId = styleIndex >= 0 && styleIndex < cellXfsNumFmt.length
        ? cellXfsNumFmt[styleIndex]
        : 0;
    final String code = numFmts[numFmtId] ?? 'General';
    return applyNumberFormat(value, code);
  }
}

/// ECMA-376 §18.8.30 number formats (common subset).
String applyNumberFormat(Object? value, String code) {
  if (value == null) {
    return '';
  }
  if (code == 'General' || code == '@') {
    return value.toString();
  }

  /// n API.
  final double? n = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
  if (n == null) {
    return value.toString();
  }

  /// negativeRed API.
  final bool negativeRed = code.contains('[Red]');

  /// clean API.
  final String clean = code.replaceAll('[Red]', '').split(';').first;

  /// out API.
  String out;
  if (clean.contains('%')) {
    out = '${(n * 100).toStringAsFixed(2)}%';
  } else if (clean.contains('\$') ||
      clean.contains('¥') ||
      clean.contains('€')) {
    out = n.toStringAsFixed(2);
    if (clean.contains('\$')) {
      out = '\$$out';
    }
  } else if (RegExp(r'0\.0+').hasMatch(clean)) {
    final int digits =
        RegExp(r'0\.(0+)').firstMatch(clean)?.group(1)?.length ?? 2;
    out = n.toStringAsFixed(digits);
  } else if (clean.contains('yyyy') ||
      clean.contains('mm') ||
      clean.contains('dd')) {
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
      (n * 86400000).round(),
      isUtc: true,
    );
    out =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  } else {
    out = n == n.roundToDouble() ? '${n.round()}' : n.toString();
  }
  if (negativeRed && n < 0) {
    return 'RED:$out';
  }
  return out;
}

const Map<int, String> _builtIn = <int, String>{
  0: 'General',
  1: '0',
  2: '0.00',
  3: '#,##0',
  4: '#,##0.00',
  9: '0%',
  10: '0.00%',
  14: 'mm-dd-yy',
  164: '"\$"#,##0.00',
};
