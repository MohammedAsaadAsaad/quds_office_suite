import 'dart:io';
import 'dart:isolate';

import 'package:quds_office_editor/quds_office_editor.dart';

/// One upright TrueType face found on disk.
typedef DeviceFontFace = ({String path, int weight});

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
/// CFF (`.otf`), italic faces, and fonts whose license forbids embedding are
/// left out.
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
    final (DeviceFontFace? regular, DeviceFontFace? bold) = pick(faces);
    if (regular == null && bold == null) {
      return null;
    }
    return ReportFontFiles(
      regular: regular == null ? null : await File(regular.path).readAsBytes(),
      bold: bold == null ? null : await File(bold.path).readAsBytes(),
    );
  }

  /// The regular face (weight below 600 closest to 400) and the bold face
  /// (weight 600 or more closest to 700) of one family.
  static (DeviceFontFace?, DeviceFontFace?) pick(List<DeviceFontFace> faces) {
    DeviceFontFace? regular;
    DeviceFontFace? bold;
    for (final DeviceFontFace f in faces) {
      if (f.weight < 600) {
        if (regular == null ||
            (f.weight - 400).abs() < (regular.weight - 400).abs()) {
          regular = f;
        }
      } else if (bold == null ||
          (f.weight - 700).abs() < (bold.weight - 700).abs()) {
        bold = f;
      }
    }
    return (regular, bold);
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
      if (info.italic || !ReportPackage.isValidFontFamily(info.family)) {
        return;
      }
      final DeviceFontFace face = (path: file.path, weight: info.weight);
      final List<DeviceFontFace> faces = out.putIfAbsent(
        info.family,
        () => <DeviceFontFace>[],
      );
      if (!faces.any((DeviceFontFace f) => f.weight == face.weight)) {
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
