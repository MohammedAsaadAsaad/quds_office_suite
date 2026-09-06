import 'dart:math' as math;
import 'dart:typed_data';

import '../fonts/font_subsetter.dart';
import '../fonts/sfnt_parser.dart';

/// Type 0 / CIDFontType2 + Identity-H + ToUnicode CMap for a subset TTF.
class PdfCidFont {
  PdfCidFont({
    required this.fontFile,
    required this.toUnicodeCmap,
    required this.baseName,
    required this.ascent,
    required this.descent,
    required this.capHeight,
    required this.flags,
    required this.bbox,
    required this.italicAngle,
    required this.stemV,
    required this.widths,
    required this.dw,
  });

  final Uint8List fontFile;
  final String toUnicodeCmap;
  final String baseName;
  final int ascent;
  final int descent;
  final int capHeight;
  final int flags;
  final List<int> bbox;
  final int italicAngle;
  final int stemV;
  final List<int> widths;
  final int dw;

  factory PdfCidFont.build(FontSubset subset, SfntFont source) {
    final SfntFont parsed = SfntFont.parse(subset.bytes);
    final List<int> widths = <int>[
      for (int i = 0; i < parsed.numGlyphs; i++)
        _toPdfWidth(parsed.advanceWidth(i), parsed.unitsPerEm),
    ];
    return PdfCidFont(
      fontFile: subset.bytes,
      toUnicodeCmap: _toUnicode(subset.unicodeToNewGlyph),
      baseName: _sanitize(parsed.familyName.isEmpty ? 'QudsSubset' : parsed.familyName),
      ascent: _toPdfWidth(parsed.ascender, parsed.unitsPerEm),
      descent: _toPdfWidth(parsed.descender, parsed.unitsPerEm),
      capHeight: _toPdfWidth(parsed.capHeight, parsed.unitsPerEm),
      flags: 4, // symbolic
      bbox: <int>[
        _toPdfWidth(parsed.xMin, parsed.unitsPerEm),
        _toPdfWidth(parsed.yMin, parsed.unitsPerEm),
        _toPdfWidth(parsed.xMax, parsed.unitsPerEm),
        _toPdfWidth(parsed.yMax, parsed.unitsPerEm),
      ],
      italicAngle: 0,
      stemV: 80,
      widths: widths,
      dw: 500,
    );
  }

  String type0Dict(int cidId, int toUnicodeId) =>
      '<</Type /Font/Subtype /Type0/BaseFont /$baseName/Encoding /Identity-H'
      '/DescendantFonts [$cidId 0 R]/ToUnicode $toUnicodeId 0 R>>';

  String cidFontDict(int descId) {
    final String w = _widthsArray();
    return '<</Type /Font/Subtype /CIDFontType2/BaseFont /$baseName'
        '/CIDSystemInfo <</Registry (Adobe)/Ordering (Identity)/Supplement 0>>'
        '/FontDescriptor $descId 0 R/DW $dw/W $w/CIDToGIDMap /Identity>>';
  }

  String descriptorDict(int fileId) =>
      '<</Type /FontDescriptor/FontName /$baseName/Flags $flags'
      '/FontBBox [${bbox.join(' ')}]/ItalicAngle $italicAngle'
      '/Ascent $ascent/Descent $descent/CapHeight $capHeight/StemV $stemV'
      '/FontFile2 $fileId 0 R>>';

  String _widthsArray() {
    if (widths.isEmpty) {
      return '[]';
    }
    final StringBuffer buffer = StringBuffer('[ 0 [');
    buffer.write(widths.join(' '));
    buffer.write('] ]');
    return buffer.toString();
  }

  static int _toPdfWidth(int units, int upem) {
    if (upem == 0) {
      return 0;
    }
    return (units * 1000 / upem).round();
  }

  static String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  static String _toUnicode(Map<int, int> unicodeToGid) {
    final List<MapEntry<int, int>> entries = unicodeToGid.entries.toList()
      ..sort((a, b) => a.value - b.value);
    final StringBuffer bf = StringBuffer();
    const int chunk = 100;
    for (int i = 0; i < entries.length; i += chunk) {
      final int end = math.min(i + chunk, entries.length);
      bf.writeln('${end - i} beginbfchar');
      for (int j = i; j < end; j++) {
        final MapEntry<int, int> e = entries[j];
        bf.write('<${e.value.toRadixString(16).padLeft(4, '0')}>');
        bf.writeln('<${e.key.toRadixString(16).padLeft(4, '0')}>');
      }
      bf.writeln('endbfchar');
    }
    return '''
/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
/CMapName /Adobe-Identity-UCS def
/CMapType 2 def
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
$bf
endcmap
CMapName currentdict /CMap defineresource pop
end
end
''';
  }
}
