import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// The open `.qrep` file: designer state, path, and unsaved-changes flag.
///
/// Files are saved as `.qrep` packages (ZIP: `layout.xml` plus embedded
/// images and fonts); legacy plain-XML `.qrep` files still open.
class ReportDocument extends ChangeNotifier {
  ReportDocument({ReportDesignerController? controller})
    : controller = controller ?? ReportDesignerController() {
    _savedXml = this.controller.toXml();
    _savedAssets = _assetSignature();
    this.controller.addListener(_onEdit);
  }

  /// Designer state shared with [QudsReportDesigner].
  final ReportDesignerController controller;

  String? _path;
  String _name = 'Untitled';
  String _savedXml = '';
  String _savedAssets = '';
  bool _dirty = false;
  int _checkedRevision = -1;
  Timer? _debounce;

  /// File on disk, null until the first save.
  String? get path => _path;

  /// Display name without the extension.
  String get name => _name;

  /// Whether the template differs from the last open or save.
  bool get dirty => _dirty;

  /// Suggested file name for save dialogs.
  String get fileName => '$_name.qrep';

  void _onEdit() {
    if (controller.revision == _checkedRevision) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _recheck);
  }

  void _recheck() {
    _checkedRevision = controller.revision;
    final bool dirty =
        controller.toXml() != _savedXml || _assetSignature() != _savedAssets;
    if (dirty != _dirty) {
      _dirty = dirty;
      notifyListeners();
    }
  }

  void _markClean({String? path, required String name}) {
    _debounce?.cancel();
    _path = path;
    _name = name;
    _savedXml = controller.toXml();
    _savedAssets = _assetSignature();
    _checkedRevision = controller.revision;
    _dirty = false;
    notifyListeners();
  }

  /// Starts an empty report.
  void newBlank() {
    controller.mockData = null;
    controller.replaceTemplate(ReportTemplate());
    _markClean(name: 'Untitled');
  }

  /// Starts from a bundled template (unsaved copy).
  void newFromTemplate(ReportTemplateInfo info) {
    controller.loadTemplate(info);
    _markClean(name: info.id);
  }

  /// Embedded images, fonts and sample data by identity: undo restores the
  /// same objects, so returning to the saved state reads as clean again.
  String _assetSignature() => <String>[
    'data:${identityHashCode(controller.sampleData)}',
    for (final String key in controller.imageNames)
      '$key:${controller.images[key]!.length}:'
          '${identityHashCode(controller.images[key])}',
    for (final String family in controller.embeddedFamilies)
      'font:$family:${identityHashCode(controller.embeddedFonts[family])}',
  ].join('|');

  /// Loads `.qrep` bytes read from [path] (or a picker with no path, on the
  /// web): a package or a legacy plain-XML file.
  ///
  /// Throws [ReportPackageException] or [ReportTemplateException].
  void loadBytes(Uint8List bytes, {String? path, required String name}) {
    controller.mockData = null;
    controller.loadPackage(bytes);
    _markClean(path: path, name: _stem(name));
  }

  /// Reads and loads [path].
  Future<void> open(String path) async {
    final Uint8List bytes = await File(path).readAsBytes();
    loadBytes(bytes, path: path, name: baseName(path));
  }

  /// Writes the `.qrep` package to [target].
  Future<void> saveTo(String target) async {
    await File(target).writeAsBytes(controller.toPackage(), flush: true);
    _markClean(path: target, name: _stem(baseName(target)));
  }

  /// Last path segment.
  static String baseName(String path) {
    final int slash = path.lastIndexOf(RegExp(r'[\\/]'));
    return slash < 0 ? path : path.substring(slash + 1);
  }

  static String _stem(String name) =>
      name.replaceAll(RegExp(r'\.(qrep|xml)$', caseSensitive: false), '');

  @override
  void dispose() {
    _debounce?.cancel();
    controller.removeListener(_onEdit);
    controller.dispose();
    super.dispose();
  }
}
