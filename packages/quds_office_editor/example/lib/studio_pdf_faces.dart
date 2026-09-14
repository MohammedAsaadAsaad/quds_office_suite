import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

/// Bundled Cairo and Tajawal faces for studio PDF samples.
///
/// PDF widgets take an [SfntFont], not a family name. These helpers load the
/// bundled OFL files so a sample can choose Cairo or Tajawal and embed a face
/// that actually contains Arabic glyphs.
abstract final class StudioPdfFaces {
  static const String cairoFamily = 'Cairo';
  static const String tajawalFamily = 'Tajawal';

  static SfntFont? _cairo;
  static SfntFont? _tajawal;
  static SfntFont? _tajawalBold;
  static var _flutterReady = false;

  /// Loaded Cairo or Tajawal, or null when that example TTF is not available.
  static SfntFont? tryFamily(String family) {
    final String key = family.trim().toLowerCase();
    if (key != 'cairo' && key != 'tajawal') {
      return null;
    }
    if (key == 'cairo' && _cairo != null) {
      return _cairo;
    }
    if (key == 'tajawal' && _tajawal != null) {
      return _tajawal;
    }
    _loadFromFiles();
    return key == 'cairo' ? _cairo : _tajawal;
  }

  /// True when [font] can embed the Arabic the PDF writer actually draws.
  ///
  /// Nominal letters plus an initial Yeh presentation form. Isolated Yeh
  /// (U+FEF1) is optional — many Arabic faces omit it and the exporter
  /// draws the nominal letter, which is the same isolated shape.
  static bool coversArabic(SfntFont font) {
    return font.hasTable('glyf') &&
        font.glyphIdFor(0x062A) != 0 &&
        font.glyphIdFor(0x064A) != 0 &&
        font.glyphIdFor(0xFEF3) != 0;
  }

  /// Cairo Regular (Arabic + Latin). No separate Bold file is published.
  static SfntFont cairo() => _require(_cairo, 'Cairo-Regular.ttf', cairoFamily);

  /// Tajawal Regular (Arabic + Latin).
  static SfntFont tajawal() =>
      _require(_tajawal, 'Tajawal-Regular.ttf', tajawalFamily);

  /// Tajawal Bold, for headings.
  static SfntFont tajawalBold() =>
      _require(_tajawalBold, 'Tajawal-Bold.ttf', tajawalFamily);

  /// Loads bundled faces from the asset bundle, then from the example tree.
  static Future<void> ensureLoaded() async {
    if (_ready) {
      return;
    }
    try {
      _cairo = await _asset('Cairo-Regular.ttf');
      _tajawal = await _asset('Tajawal-Regular.ttf');
      _tajawalBold = await _asset('Tajawal-Bold.ttf');
    } on Object {
      _loadFromFiles();
    }
    if (!_ready) {
      _loadFromFiles();
    }
    _assertReady();
  }

  /// Registers the faces with Flutter so the studio can paint the same names.
  static Future<void> registerFlutterFaces() async {
    if (_flutterReady) {
      return;
    }
    await ensureLoaded();
    await _loader(cairoFamily, <SfntFont>[cairo()]);
    await _loader(tajawalFamily, <SfntFont>[tajawal(), tajawalBold()]);
    _flutterReady = true;
  }

  static bool get _ready =>
      _cairo != null && _tajawal != null && _tajawalBold != null;

  static SfntFont _require(SfntFont? cached, String file, String family) {
    if (cached != null) {
      _check(cached, family);
      return cached;
    }
    _loadFromFiles();
    final SfntFont? loaded = switch (file) {
      'Cairo-Regular.ttf' => _cairo,
      'Tajawal-Regular.ttf' => _tajawal,
      'Tajawal-Bold.ttf' => _tajawalBold,
      _ => null,
    };
    if (loaded == null) {
      throw StateError(
        '$file is not loaded. Call StudioFonts.register() before building '
        'the $family PDF sample.',
      );
    }
    _check(loaded, family);
    return loaded;
  }

  static void _check(SfntFont font, String family) {
    if (font.familyName != family) {
      throw StateError(
        'Bundled face family is "${font.familyName}", expected $family.',
      );
    }
    if (font.glyphIdFor(0x062A) == 0 || font.glyphIdFor(0x0041) == 0) {
      throw StateError('$family does not cover Arabic and Latin.');
    }
  }

  static Future<SfntFont> _asset(String file) async {
    final ByteData data = await rootBundle.load('fonts/$file');
    return SfntFont.parse(data.buffer.asUint8List());
  }

  static void _loadFromFiles() {
    _cairo ??= _read('Cairo-Regular.ttf');
    _tajawal ??= _read('Tajawal-Regular.ttf');
    _tajawalBold ??= _read('Tajawal-Bold.ttf');
  }

  static SfntFont? _read(String file) {
    if (kIsWeb) {
      return null;
    }
    for (final String dir in _searchDirs()) {
      final File candidate = File('$dir${Platform.pathSeparator}$file');
      if (candidate.existsSync()) {
        return SfntFont.parse(candidate.readAsBytesSync());
      }
    }
    return null;
  }

  static List<String> _searchDirs() {
    final List<String> dirs = <String>[
      'fonts',
      'example${Platform.pathSeparator}fonts',
      'packages${Platform.pathSeparator}quds_office_editor'
          '${Platform.pathSeparator}example${Platform.pathSeparator}fonts',
    ];
    return dirs;
  }

  static void _assertReady() {
    cairo();
    tajawal();
    tajawalBold();
  }

  static Future<void> _loader(String family, List<SfntFont> faces) async {
    final FontLoader loader = FontLoader(family);
    for (final SfntFont face in faces) {
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(face.bytes)));
    }
    await loader.load();
  }
}
