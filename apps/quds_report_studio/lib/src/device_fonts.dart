import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:quds_office_editor/quds_office_editor.dart';

/// One TrueType face found on disk.
typedef DeviceFontFace = ({String path, int weight, bool italic});

/// The four faces a report package can embed for one family.
typedef DeviceFontPick = ({
  DeviceFontFace? regular,
  DeviceFontFace? bold,
  DeviceFontFace? italic,
  DeviceFontFace? boldItalic,
});

/// Faces per family and the writing systems each family covers.
typedef DeviceFontIndex = ({
  Map<String, List<DeviceFontFace>> faces,
  Map<String, Set<ReportScript>> scripts,
});

/// TrueType fonts installed in the operating system's font folders, offered
/// on the designer's Fonts page.
///
/// Folders are scanned once, in a background isolate, reading only each
/// file's table directory and `name` / `OS/2` / `head` tables. Collections,
/// CFF (`.otf`) and fonts whose license forbids embedding are left out.
/// Italic faces are kept as `italic.ttf` and `boldItalic.ttf`.
class StudioDeviceFonts implements ReportDeviceFonts, ReportDeviceFontScripts {
  StudioDeviceFonts({List<String>? folders})
    : folders = folders ?? defaultFolders();

  /// Folders searched recursively.
  final List<String> folders;

  Future<DeviceFontIndex>? _index;

  /// The usual system and per-user font folders of the current platform.
  static List<String> defaultFolders() {
    final Map<String, String> env = Platform.environment;
    final String home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    if (Platform.isWindows) {
      final String windir = env['WINDIR'] ?? r'C:\Windows';
      final String? local = env['LOCALAPPDATA'];
      return <String>[
        '$windir\\Fonts',
        if (local != null) '$local\\Microsoft\\Windows\\Fonts',
      ];
    }
    if (Platform.isMacOS) {
      return <String>[
        '/System/Library/Fonts',
        '/Library/Fonts',
        if (home.isNotEmpty) '$home/Library/Fonts',
      ];
    }
    return <String>[
      '/usr/share/fonts',
      '/usr/local/share/fonts',
      if (home.isNotEmpty) ...<String>[
        '$home/.local/share/fonts',
        '$home/.fonts',
      ],
    ];
  }

  Future<DeviceFontIndex> _scan() {
    final List<String> roots = folders;
    return _index ??= Isolate.run(() => index(roots));
  }

  Future<Map<String, List<DeviceFontFace>>> _faces() async =>
      (await _scan()).faces;

  @override
  Future<Map<String, Set<ReportScript>>> scripts() async =>
      (await _scan()).scripts;

  @override
  Future<List<String>> families() async => (await _faces()).keys.toList()
    ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));

  @override
  Future<ReportFontFiles?> load(String family) async {
    final List<DeviceFontFace>? faces = (await _faces())[family];
    if (faces == null) {
      return null;
    }
    final DeviceFontPick chosen = pick(faces);
    if (chosen.regular == null &&
        chosen.bold == null &&
        chosen.italic == null &&
        chosen.boldItalic == null) {
      return null;
    }
    Future<Uint8List?> read(DeviceFontFace? face) async =>
        face == null ? null : File(face.path).readAsBytes();
    return ReportFontFiles(
      regular: await read(chosen.regular),
      bold: await read(chosen.bold),
      italic: await read(chosen.italic),
      boldItalic: await read(chosen.boldItalic),
    );
  }

  /// Upright and italic faces closest to weights 400 and 700.
  static DeviceFontPick pick(List<DeviceFontFace> faces) {
    DeviceFontFace? regular;
    DeviceFontFace? bold;
    DeviceFontFace? italic;
    DeviceFontFace? boldItalic;
    for (final DeviceFontFace f in faces) {
      if (f.italic) {
        if (f.weight < 600) {
          if (italic == null ||
              (f.weight - 400).abs() < (italic.weight - 400).abs()) {
            italic = f;
          }
        } else if (boldItalic == null ||
            (f.weight - 700).abs() < (boldItalic.weight - 700).abs()) {
          boldItalic = f;
        }
      } else if (f.weight < 600) {
        if (regular == null ||
            (f.weight - 400).abs() < (regular.weight - 400).abs()) {
          regular = f;
        }
      } else if (bold == null ||
          (f.weight - 700).abs() < (bold.weight - 700).abs()) {
        bold = f;
      }
    }
    return (
      regular: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    );
  }

  /// Upright embeddable faces under [roots], grouped by family. Unreadable
  /// folders and files are skipped.
  static Map<String, List<DeviceFontFace>> scan(List<String> roots) =>
      index(roots).faces;

  /// [scan] plus the writing systems of each family (the union over its
  /// faces).
  static DeviceFontIndex index(List<String> roots) {
    final Map<String, List<DeviceFontFace>> out =
        <String, List<DeviceFontFace>>{};
    final Map<String, Set<ReportScript>> scripts =
        <String, Set<ReportScript>>{};
    final Set<String> seen = <String>{};
    void visit(Directory dir) {
      final String real;
      final List<FileSystemEntity> entries;
      try {
        real = dir.resolveSymbolicLinksSync();
        if (!seen.add(real)) {
          return;
        }
        entries = dir.listSync(followLinks: true);
      } on FileSystemException {
        return;
      }
      for (final FileSystemEntity e in entries) {
        if (e is Directory) {
          visit(e);
        } else if (e is File && e.path.toLowerCase().endsWith('.ttf')) {
          _add(e, out, scripts);
        }
      }
    }

    for (final String root in roots) {
      visit(Directory(root));
    }
    return (faces: out, scripts: scripts);
  }

  static void _add(
    File file,
    Map<String, List<DeviceFontFace>> out,
    Map<String, Set<ReportScript>> scripts,
  ) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final int length = raf.lengthSync();
      if (length > ReportPackage.maxEntryBytes) {
        return;
      }
      final RandomAccessFile handle = raf;
      final ReportFontFileInfo info = ReportFontFile.inspectWith((
        int offset,
        int count,
      ) {
        if (offset < 0 || offset + count > length) {
          throw const ReportFontException('Font file is truncated');
        }
        handle.setPositionSync(offset);
        return handle.readSync(count);
      });
      if (!ReportPackage.isValidFontFamily(info.family)) {
        return;
      }
      final DeviceFontFace face = (
        path: file.path,
        weight: info.weight,
        italic: info.italic,
      );
      final List<DeviceFontFace> faces = out.putIfAbsent(
        info.family,
        () => <DeviceFontFace>[],
      );
      if (!faces.any(
        (DeviceFontFace f) => f.weight == face.weight && f.italic == face.italic,
      )) {
        faces.add(face);
      }
      scripts
          .putIfAbsent(info.family, () => <ReportScript>{})
          .addAll(info.scripts);
    } on ReportFontException {
      return;
    } on FileSystemException {
      return;
    } on RangeError {
      return;
    } finally {
      raf?.closeSync();
    }
  }
}
