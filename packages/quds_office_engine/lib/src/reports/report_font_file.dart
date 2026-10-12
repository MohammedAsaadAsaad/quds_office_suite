/// TrueType files embedded in `.qrep` packages: inspection and face slots.
library;

import 'dart:typed_data';

import 'report_fonts.dart';

/// Regular and bold TrueType files of one embedded family. At least one is
/// set; a missing face falls back to the other.
class ReportFontFiles {
  /// ReportFontFiles API.
  ReportFontFiles({this.regular, this.bold})
    : assert(regular != null || bold != null, 'Need at least one face');

  /// Upright regular face (weight closest to 400).
  final Uint8List? regular;

  /// Upright bold face (weight 600 or more).
  final Uint8List? bold;

  /// Total size of the files in bytes.
  int get byteLength => (regular?.length ?? 0) + (bold?.length ?? 0);

  /// Copy with [face] set to [bytes] (bold when [bold] is true).
  ReportFontFiles withFace(Uint8List bytes, {required bool bold}) => bold
      ? ReportFontFiles(regular: regular, bold: bytes)
      : ReportFontFiles(regular: bytes, bold: this.bold);

  /// Registers this family in [registry] under [family].
  void registerIn(ReportFontRegistry registry, String family) {
    final Uint8List upright = regular ?? bold!;
    registry.registerBytes(
      family,
      upright,
      bold: regular == null ? null : bold,
    );
  }
}

/// What a TrueType file declares in its `name`, `OS/2` and `head` tables.
class ReportFontFileInfo {
  /// ReportFontFileInfo API.
  const ReportFontFileInfo({
    required this.family,
    required this.weight,
    required this.italic,
  });

  /// Typographic family (name ID 16, else 1), English when available.
  final String family;

  /// `usWeightClass` (400 regular, 700 bold).
  final int weight;

  /// Italic or oblique face.
  final bool italic;

  /// Whether the face fills the bold slot (weight 600 or more).
  bool get bold => weight >= 600;

  /// Human-readable face name, e.g. `Bold` or `SemiBold Italic`.
  String get style {
    final String w = switch (weight) {
      < 150 => 'Thin',
      < 250 => 'ExtraLight',
      < 350 => 'Light',
      < 450 => 'Regular',
      < 550 => 'Medium',
      < 650 => 'SemiBold',
      < 750 => 'Bold',
      < 850 => 'ExtraBold',
      _ => 'Black',
    };
    if (!italic) {
      return w;
    }
    return w == 'Regular' ? 'Italic' : '$w Italic';
  }
}

/// Reads TrueType headers without parsing glyphs, so a host can scan
/// installed fonts quickly and reports only embed files they can draw.
abstract final class ReportFontFile {
  /// Inspects in-memory font bytes; see [inspectWith].
  static ReportFontFileInfo inspect(Uint8List bytes) =>
      inspectWith((int offset, int length) {
        if (offset < 0 || offset + length > bytes.length) {
          throw const ReportFontException('Font file is truncated');
        }
        return Uint8List.sublistView(bytes, offset, offset + length);
      });

  /// Inspects a font through [read] (`offset`, `length` → bytes), which lets
  /// a host read only the table directory, `name`, `OS/2` and `head` of a
  /// file on disk.
  ///
  /// Throws [ReportFontException] for collections (`.ttc`), CFF outlines
  /// (`.otf`), files without a family name, and fonts whose license
  /// (`OS/2 fsType`) forbids embedding.
  static ReportFontFileInfo inspectWith(
    Uint8List Function(int offset, int length) read,
  ) {
    final ByteData header = ByteData.sublistView(read(0, 12));
    final int version = header.getUint32(0);
    if (version == 0x74746366) {
      throw const ReportFontException(
        'Font collections (.ttc) are not supported; use a single .ttf',
      );
    }
    if (version == 0x4F54544F) {
      throw const ReportFontException(
        'CFF/OpenType outlines (.otf) cannot be embedded; use a TrueType .ttf',
      );
    }
    if (version != 0x00010000 && version != 0x74727565) {
      throw const ReportFontException('Not a TrueType font');
    }
    final int count = header.getUint16(4);
    if (count == 0 || count > 200) {
      throw const ReportFontException('Damaged font table directory');
    }
    final ByteData dir = ByteData.sublistView(read(12, count * 16));
    final Map<String, (int, int)> tables = <String, (int, int)>{};
    for (int i = 0; i < count; i++) {
      final int at = i * 16;
      final String tag = String.fromCharCodes(<int>[
        dir.getUint8(at),
        dir.getUint8(at + 1),
        dir.getUint8(at + 2),
        dir.getUint8(at + 3),
      ]);
      tables[tag] = (dir.getUint32(at + 8), dir.getUint32(at + 12));
    }
    for (final String tag in const <String>[
      'glyf',
      'loca',
      'cmap',
      'head',
      'hhea',
      'hmtx',
      'maxp',
    ]) {
      if (!tables.containsKey(tag)) {
        throw ReportFontException(
          tag == 'glyf'
              ? 'Font has no TrueType outlines (glyf); use a TrueType .ttf'
              : 'Font is missing its $tag table',
        );
      }
    }
    ByteData table(String tag) {
      final (int offset, int length) = tables[tag]!;
      return ByteData.sublistView(read(offset, length));
    }

    var weight = 400;
    var italic = false;
    if (tables.containsKey('OS/2')) {
      final ByteData os2 = table('OS/2');
      if (os2.lengthInBytes >= 64) {
        weight = os2.getUint16(4);
        final int fsType = os2.getUint16(8);
        if (fsType & 0x000F == 0x0002) {
          throw const ReportFontException(
            'The font license forbids embedding (restricted fsType)',
          );
        }
        final int fsSelection = os2.getUint16(62);
        italic = fsSelection & 0x0001 != 0 || fsSelection & 0x0200 != 0;
        if (fsSelection & 0x0020 != 0 && weight < 600) {
          weight = 700;
        }
      }
    } else {
      final ByteData head = table('head');
      final int macStyle = head.getUint16(44);
      weight = macStyle & 0x0001 != 0 ? 700 : 400;
      italic = macStyle & 0x0002 != 0;
    }
    if (weight < 1 || weight > 1000) {
      weight = 400;
    }
    if (!tables.containsKey('name')) {
      throw const ReportFontException('Font has no name table');
    }
    final String family = _family(table('name')).trim();
    if (family.isEmpty) {
      throw const ReportFontException('Font has no family name');
    }
    return ReportFontFileInfo(family: family, weight: weight, italic: italic);
  }

  static String _family(ByteData name) {
    if (name.lengthInBytes < 6) {
      return '';
    }
    final int count = name.getUint16(2);
    final int strings = name.getUint16(4);
    var best = '';
    var bestScore = -1;
    for (int i = 0; i < count; i++) {
      final int at = 6 + i * 12;
      if (at + 12 > name.lengthInBytes) {
        break;
      }
      final int platform = name.getUint16(at);
      final int encoding = name.getUint16(at + 2);
      final int language = name.getUint16(at + 4);
      final int id = name.getUint16(at + 6);
      final int length = name.getUint16(at + 8);
      final int offset = strings + name.getUint16(at + 10);
      if ((id != 1 && id != 16) || offset + length > name.lengthInBytes) {
        continue;
      }
      final bool windows = platform == 3 && (encoding == 1 || encoding == 10);
      final bool mac = platform == 1 && encoding == 0;
      if (!windows && !mac) {
        continue;
      }
      final int score =
          (id == 16 ? 4 : 0) +
          (windows ? 2 : 0) +
          (language == 0x409 || (mac && language == 0) ? 1 : 0);
      if (score <= bestScore) {
        continue;
      }
      final StringBuffer s = StringBuffer();
      if (windows) {
        for (int j = 0; j + 1 < length; j += 2) {
          s.writeCharCode(name.getUint16(offset + j));
        }
      } else {
        for (int j = 0; j < length; j++) {
          s.writeCharCode(name.getUint8(offset + j));
        }
      }
      best = s.toString();
      bestScore = score;
    }
    return best;
  }
}
