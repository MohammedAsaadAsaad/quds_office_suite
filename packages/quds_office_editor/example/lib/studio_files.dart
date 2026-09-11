import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

enum StudioSaveStage { picking, writing }

class PickedOfficeFile {
  const PickedOfficeFile({
    required this.bytes,
    required this.name,
    required this.kind,
    this.path,
  });

  final Uint8List bytes;
  final String name;
  final OpcPackageKind kind;
  final String? path;
}

abstract final class StudioFiles {
  static const List<String> extensions = <String>[
    'docx',
    'xlsx',
    'pptx',
    'docm',
    'xlsm',
    'pptm',
    'pdf',
  ];

  static Future<Uint8List?> pickImage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final PlatformFile file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null && !kIsWeb) {
      bytes = await File(file.path!).readAsBytes();
    }
    return bytes;
  }

  static Future<PickedOfficeFile?> open() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final PlatformFile file = result.files.first;
    final Uint8List bytes = file.bytes ?? Uint8List(0);
    if (bytes.isEmpty && (file.path == null || file.path!.isEmpty)) {
      return null;
    }
    return PickedOfficeFile(
      bytes: bytes,
      name: file.name,
      kind: kindOf(file.name, bytes),
      path: file.path,
    );
  }

  /// Loads picked file bytes on a worker isolate when the picker only returned a path.
  static Future<Uint8List> ensureBytes(PickedOfficeFile picked) async {
    if (picked.bytes.isNotEmpty) {
      return picked.bytes;
    }
    final String? path = picked.path;
    if (path == null || kIsWeb) {
      return picked.bytes;
    }
    try {
      return await Isolate.run(() => File(path).readAsBytes());
    } on IsolateSpawnException {
      return File(path).readAsBytes();
    } on UnsupportedError {
      return File(path).readAsBytes();
    }
  }

  static const List<String> _uiFonts = <String>[
    '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
    '/usr/share/fonts/truetype/freefont/FreeSans.ttf',
  ];

  static const Map<String, List<String>> _familyFiles =
      <String, List<String>>{
    'noto naskh arabic': <String>[
      'NotoNaskhArabic-Regular.ttf',
      'NotoNaskhArabic-Regular.otf',
    ],
    'noto sans arabic': <String>[
      'NotoSansArabic-Regular.ttf',
    ],
    'tajawal': <String>[
      'Tajawal-Regular.ttf',
    ],
    'calibri': <String>[
      'Carlito-Regular.ttf',
      'LiberationSans-Regular.ttf',
    ],
    'carlito': <String>[
      'Carlito-Regular.ttf',
    ],
    'arial': <String>[
      'LiberationSans-Regular.ttf',
      'DejaVuSans.ttf',
    ],
    'liberation sans': <String>[
      'LiberationSans-Regular.ttf',
    ],
    'times new roman': <String>[
      'LiberationSerif-Regular.ttf',
    ],
    'georgia': <String>[
      'LiberationSerif-Regular.ttf',
    ],
    'liberation serif': <String>[
      'LiberationSerif-Regular.ttf',
    ],
    'courier new': <String>[
      'LiberationMono-Regular.ttf',
      'DejaVuSansMono.ttf',
    ],
    'tahoma': <String>[
      'DejaVuSans.ttf',
    ],
    'dejavu sans': <String>[
      'DejaVuSans.ttf',
    ],
    'dejavu': <String>[
      'DejaVuSans.ttf',
    ],
  };

  static List<String> get _fontSearchDirs {
    final String home = Platform.environment['HOME'] ?? '';
    return <String>[
      '/usr/share/fonts/truetype/noto',
      '/usr/share/fonts/opentype/noto',
      '/usr/share/fonts/truetype/liberation',
      '/usr/share/fonts/truetype/liberation2',
      '/usr/share/fonts/truetype/crosextra',
      '/usr/share/fonts/truetype/dejavu',
      '/usr/share/fonts/truetype/freefont',
      if (home.isNotEmpty) '$home/.local/share/fonts',
      '/usr/share/fonts/truetype',
    ];
  }

  static SfntFont? systemUiFont() =>
      fontForFamily(OfficeTypeface.arabicTheme) ?? _firstExisting(_uiFonts);

  /// Latin-capable UI face for PDF export (never Arabic-only).
  static SfntFont? latinExportFont() =>
      fontForFamily('Liberation Sans') ??
      fontForFamily('DejaVu Sans') ??
      fontForFamily('Arial') ??
      _firstExisting(const <String>[
        '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
      ]);

  /// Bold companion for [latinExportFont] (real weight, not faux stroke).
  static SfntFont? latinExportBoldFont() => _firstExisting(const <String>[
        '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf',
      ]);

  /// Arabic-capable face for mixed-script PDF export.
  static SfntFont? arabicExportFont() =>
      fontForFamily(OfficeTypeface.arabicTheme) ??
      fontForFamily('Noto Sans Arabic') ??
      fontForFamily('Tajawal');

  /// Multi-face pack so Latin and Arabic both get real advances when exporting.
  static OfficeFontSet exportFontSetCovering(Iterable<String> texts) {
    final SfntFont? latin = latinExportFont();
    final SfntFont? arabic = arabicExportFont();
    var needsLatin = false;
    var needsArabic = false;
    for (final String text in texts) {
      for (final int cp in text.runes) {
        if (cp >= 0x0600 && cp <= 0x06FF) {
          needsArabic = true;
        } else if ((cp >= 0x0041 && cp <= 0x007A) ||
            (cp >= 0x00C0 && cp <= 0x024F)) {
          needsLatin = true;
        }
      }
    }
    if (needsLatin && needsArabic && latin != null && arabic != null) {
      return OfficeFontSet(primary: latin, fallbacks: <SfntFont>[arabic]);
    }
    if (needsArabic && !needsLatin && arabic != null) {
      return OfficeFontSet(
        primary: arabic,
        fallbacks: <SfntFont>[
          if (latin != null) latin,
        ],
      );
    }
    final SfntFont? covered = exportFontCovering(texts);
    return OfficeFontSet(
      primary: covered ?? latin ?? arabic,
      fallbacks: <SfntFont>[
        if (latin != null && !identical(latin, covered)) latin,
        if (arabic != null && !identical(arabic, covered)) arabic,
      ],
    );
  }

  static SfntFont? exportFontForWord(WmlDocument document, {String? themeFamily}) {
    return exportFontSetForWord(document, themeFamily: themeFamily).primary ??
        exportFontCovering(
          <String>[
            for (final WmlParagraph paragraph in document.paragraphs)
              paragraph.text,
          ],
          preferred: OfficeTypeface.preferredExportFamily(
            document,
            themeFamily: themeFamily,
          ),
        );
  }

  /// Font set for Word → PDF (Latin primary when the doc mixes scripts).
  static OfficeFontSet exportFontSetForWord(
    WmlDocument document, {
    String? themeFamily,
  }) {
    return exportFontSetCovering(<String>[
      for (final WmlParagraph paragraph in document.paragraphs) paragraph.text,
    ]);
  }

  /// Picks a TrueType face that covers the most requested characters.
  static SfntFont? exportFontCovering(
    Iterable<String> texts, {
    String? preferred,
  }) {
    final Set<int> cps = <int>{};
    for (final String text in texts) {
      cps.addAll(text.runes);
    }
    final List<SfntFont?> candidates = <SfntFont?>[
      if (preferred != null && preferred.isNotEmpty) fontForFamily(preferred),
      latinExportFont(),
      systemUiFont(),
      fontForFamily('DejaVu Sans'),
      fontForFamily('Noto Sans Arabic'),
      fontForFamily('Tajawal'),
      _firstExisting(_uiFonts),
    ];
    SfntFont? best;
    var bestHits = -1;
    final int printable =
        cps.where((int cp) => cp >= 32).length.clamp(1, 0x7fffffff);
    for (final SfntFont? font in candidates) {
      if (font == null || !font.hasTable('glyf')) {
        continue;
      }
      var hits = 0;
      for (final int cp in cps) {
        if (cp >= 32 && font.glyphIdFor(cp) != 0) {
          hits++;
        }
      }
      if (hits > bestHits && hits * 2 >= printable) {
        best = font;
        bestHits = hits;
      } else if (best == null && hits > bestHits) {
        best = font;
        bestHits = hits;
      }
    }
    return best ?? latinExportFont() ?? systemUiFont();
  }

  static SfntFont? fontForFamily(String family) {
    if (kIsWeb) {
      return null;
    }
    final String key = family.toLowerCase();
    final List<String> names = _familyFiles[key] ??
        <String>['${family.replaceAll(' ', '')}-Regular.ttf'];
    for (final String name in names) {
      for (final String dir in _fontSearchDirs) {
        final File file = File('$dir/$name');
        if (file.existsSync()) {
          return SfntFont.parse(file.readAsBytesSync());
        }
      }
    }
    return null;
  }

  static SfntFont? _firstExisting(List<String> paths) {
    if (kIsWeb) {
      return null;
    }
    for (final String path in paths) {
      final File file = File(path);
      if (file.existsSync()) {
        return SfntFont.parse(file.readAsBytesSync());
      }
    }
    return null;
  }

  static Future<String?> pickSavePath({required String fileName}) async {
    final String ext = fileName.split('.').last;
    return FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: <String>[ext],
    );
  }

  static String withExtension(String path, String fileName) {
    final String ext = fileName.split('.').last.toLowerCase();
    if (path.toLowerCase().endsWith('.$ext')) {
      return path;
    }
    return '$path.$ext';
  }

  static String nameOf(String path) {
    final int slash = path.lastIndexOf(Platform.pathSeparator);
    return slash < 0 ? path : path.substring(slash + 1);
  }

  static Future<void> saveOfficeToPath({
    required String path,
    required OpcPackageKind kind,
    WmlDocument? word,
    SmlWorkbook? workbook,
    PmlPresentation? presentation,
    String? password,
  }) async {
    final _OfficeDiskSaveJob job = _OfficeDiskSaveJob(
      path: path,
      kind: kind,
      word: word,
      workbook: workbook,
      presentation: presentation,
      password: password,
    );
    try {
      await Isolate.run(() => _encodeAndWriteOffice(job));
    } on IsolateSpawnException {
      _encodeAndWriteOffice(job);
    } on UnsupportedError {
      _encodeAndWriteOffice(job);
    } on ArgumentError catch (error) {
      final String text = error.toString();
      if (text.contains('isolate message') || text.contains('unsendable')) {
        _encodeAndWriteOffice(job);
        return;
      }
      rethrow;
    }
  }

  static Future<bool> save({
    required Uint8List bytes,
    required String fileName,
    void Function(StudioSaveStage stage)? onStage,
  }) async {
    final String ext = fileName.split('.').last;
    onStage?.call(StudioSaveStage.picking);
    final String? path = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: kIsWeb ? bytes : null,
      type: FileType.custom,
      allowedExtensions: <String>[ext],
    );
    if (kIsWeb) {
      return true;
    }
    if (path == null) {
      return false;
    }
    onStage?.call(StudioSaveStage.writing);
    await File(path).writeAsBytes(bytes, flush: true);
    return true;
  }

  static OpcPackageKind kindOf(String name, Uint8List bytes) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xlsm')) {
      return OpcPackageKind.sheet;
    }
    if (lower.endsWith('.pptx') || lower.endsWith('.pptm')) {
      return OpcPackageKind.slide;
    }
    if (lower.endsWith('.docx') || lower.endsWith('.docm')) {
      return OpcPackageKind.word;
    }
    if (lower.endsWith('.pdf')) {
      return OpcPackageKind.unknown;
    }
    try {
      return OfficeRepair.open(bytes).kind;
    } catch (_) {
      return OpcPackageKind.unknown;
    }
  }
}

class _OfficeDiskSaveJob {
  const _OfficeDiskSaveJob({
    required this.path,
    required this.kind,
    this.word,
    this.workbook,
    this.presentation,
    this.password,
  });

  final String path;
  final OpcPackageKind kind;
  final WmlDocument? word;
  final SmlWorkbook? workbook;
  final PmlPresentation? presentation;
  final String? password;
}

void _encodeAndWriteOffice(_OfficeDiskSaveJob job) {
  final Uint8List bytes = switch (job.kind) {
    OpcPackageKind.word => WordSerializer().writeBytes(
        job.word!,
        password: job.password,
      ),
    OpcPackageKind.sheet => SheetSerializer().writeBytes(
        job.workbook!,
        password: job.password,
      ),
    OpcPackageKind.slide => SlideSerializer().writeBytes(
        job.presentation!,
        password: job.password,
      ),
    OpcPackageKind.unknown =>
      throw ArgumentError('Cannot save an unknown Office package.'),
  };
  File(job.path).writeAsBytesSync(bytes, flush: true);
}
