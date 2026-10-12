import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'recent_files.dart';

/// Templates offered by File › New from template: the ready-made `.qrep`
/// files bundled with the editor, plus the user's own templates, which are
/// `.qrep` files in [folder].
///
/// A `.qrep` in [folder] without a `template.json` still counts: its file
/// name becomes its title.
class StudioTemplates extends ChangeNotifier {
  StudioTemplates({
    this.bundled = const <ReportTemplateInfo>[],
    Directory? folder,
    bool persist = true,
  }) : folder = persist ? folder ?? defaultFolder() : null;

  /// The ready-made templates ([ReportTemplateLibrary.bundled]).
  final List<ReportTemplateInfo> bundled;

  /// Folder of the user's templates; null when there is none.
  final Directory? folder;

  List<ReportTemplateInfo> _user = const <ReportTemplateInfo>[];
  List<String> _skipped = const <String>[];

  /// The user's templates, in menu order.
  List<ReportTemplateInfo> get user => _user;

  /// File names in [folder] that could not be read on the last [load].
  List<String> get skipped => _skipped;

  /// [bundled] followed by [user].
  List<ReportTemplateInfo> get all => <ReportTemplateInfo>[
    ...bundled,
    ..._user,
  ];

  /// `templates` in the studio's config folder.
  static Directory? defaultFolder() {
    final File? marker = RecentFiles.configFile('templates');
    return marker == null ? null : Directory(marker.path);
  }

  /// Reads the `.qrep` files of [folder].
  Future<void> load() async {
    final Directory? dir = folder;
    final List<ReportTemplateInfo> found = <ReportTemplateInfo>[];
    final List<String> skipped = <String>[];
    if (dir != null && await dir.exists()) {
      await for (final FileSystemEntity e in dir.list()) {
        if (e is! File || !e.path.toLowerCase().endsWith('.qrep')) {
          continue;
        }
        final String name = e.uri.pathSegments.last;
        try {
          found.add(_read(name, await e.readAsBytes()));
        } on ReportPackageException {
          skipped.add(name);
        } on FileSystemException {
          skipped.add(name);
        }
      }
    }
    _user = ReportTemplateLibrary.sorted(found);
    _skipped = skipped;
    notifyListeners();
  }

  static ReportTemplateInfo _read(String fileName, Uint8List bytes) {
    final ReportPackage package = ReportPackage.decode(bytes);
    if (package.template != null) {
      return ReportTemplateInfo.fromPackage(package);
    }
    final ReportParseResult parsed = QudsReportXmlParser().parse(package.xml);
    if (!parsed.readable) {
      throw ReportPackageException('$fileName is not a report');
    }
    final String title = fileName.substring(0, fileName.length - 5);
    return ReportTemplateInfo.fromPackage(
      ReportPackage(
        xml: package.xml,
        images: package.images,
        fonts: package.fonts,
        sampleData: package.sampleData,
        template: ReportTemplateManifest(
          id: idFor(title),
          title: title,
          language: parsed.template.isRtl
              ? ReportTemplateLanguage.arabic
              : ReportTemplateLanguage.english,
        ),
      ),
    );
  }

  /// A valid [ReportTemplateManifest.id] for [title]: its ASCII letters and
  /// digits, or `template_` plus a hash for titles without any.
  static String idFor(String title) {
    final String slug = title
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isNotEmpty) {
      return slug.length > 48 ? slug.substring(0, 48) : slug;
    }
    int hash = 0x811C9DC5;
    for (final int b in utf8.encode(title)) {
      hash = ((hash ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    return 'template_${hash.toRadixString(16)}';
  }

  /// Saves [package] as a template named [title] in [folder], replacing a
  /// template with the same id, then reloads. Returns the saved template.
  ///
  /// Throws [FileSystemException] when there is no folder or it cannot be
  /// written.
  Future<ReportTemplateInfo> save(
    ReportPackage package, {
    required String title,
    required ReportTemplateCategory category,
    required bool rtl,
  }) async {
    final Directory? dir = folder;
    if (dir == null) {
      throw const FileSystemException('No folder for templates');
    }
    final String id = idFor(title);
    final ReportPackage template = ReportPackage(
      xml: package.xml,
      images: package.images,
      fonts: package.fonts,
      sampleData: package.sampleData,
      template: ReportTemplateManifest(
        id: id,
        title: title,
        category: category,
        language: rtl
            ? ReportTemplateLanguage.arabic
            : ReportTemplateLanguage.english,
        order: 1000,
      ),
    );
    await dir.create(recursive: true);
    await File(
      '${dir.path}${Platform.pathSeparator}$id.qrep',
    ).writeAsBytes(template.encode(), flush: true);
    await load();
    return _user.firstWhere((ReportTemplateInfo t) => t.id == id);
  }
}
