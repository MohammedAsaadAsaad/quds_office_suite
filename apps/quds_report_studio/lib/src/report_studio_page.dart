import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'file_association.dart';
import 'recent_files.dart';
import 'report_document.dart';
import 'studio_printing.dart';
import 'studio_settings.dart';
import 'studio_strings.dart';
import 'studio_templates.dart';
import 'studio_theme.dart';
import 'studio_window.dart';

/// Main window: title bar with the File menu, the designer, and a status bar.
class ReportStudioPage extends StatefulWidget {
  const ReportStudioPage({
    super.key,
    required this.recent,
    required this.settings,
    this.initialPath,
    this.templates,
    this.deviceFonts,
    this.printer = StudioPrinting.system,
  });

  /// Recently opened files.
  final RecentFiles recent;

  /// Persisted preferences (inspector width).
  final StudioSettings settings;

  /// File to open on start (command-line argument).
  final String? initialPath;

  /// Starter templates offered by File › New from template: the bundled
  /// ones and the user's own. None when null.
  final StudioTemplates? templates;

  /// Installed fonts offered on the inspector's Fonts page.
  final ReportDeviceFonts? deviceFonts;

  /// Shows the print dialog for the rendered report.
  final StudioPrinter printer;

  @override
  State<ReportStudioPage> createState() => ReportStudioPageState();
}

/// State of [ReportStudioPage]; public so tests can drive file commands.
class ReportStudioPageState extends State<ReportStudioPage> {
  final ReportDocument _doc = ReportDocument();
  final MenuController _fileMenu = MenuController();
  late final double _startInspectorWidth = widget.settings.inspectorWidth;

  /// The open document.
  ReportDocument get document => _doc;

  StudioStrings get _s => StudioStrings.of(context);

  StudioPalette get _p => StudioPalette.of(Theme.of(context).brightness);

  late final StudioTemplates _catalog = widget.templates ?? StudioTemplates();

  @override
  void initState() {
    super.initState();
    _doc.addListener(_onDocument);
    _catalog.addListener(_onDocument);
    final String? path = widget.initialPath;
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPath(path));
    } else if (_catalog.bundled.isNotEmpty) {
      _doc.newFromTemplate(_catalog.bundled.first);
    }
    _onDocument();
  }

  @override
  void dispose() {
    _doc.removeListener(_onDocument);
    _catalog.removeListener(_onDocument);
    _doc.dispose();
    super.dispose();
  }

  void _onDocument() {
    unawaited(StudioWindow.setTitle(_windowTitle));
    if (mounted) {
      setState(() {});
    }
  }

  String get _windowTitle =>
      '${_doc.dirty ? '• ' : ''}${_doc.fileName} — Quds Report Studio';

  void _toast(
    String text, {
    bool error = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          width: 420,
          backgroundColor: error ? const Color(0xFFB3261E) : null,
          showCloseIcon: duration.inSeconds > 4,
          duration: duration,
        ),
      );
  }

  Future<void> _associateFiles() async {
    final String exe = Platform.resolvedExecutable;
    final bool ok = await QrepFileAssociation.register(exe);
    if (ok) {
      await widget.settings.setAssociatedExecutable(exe);
    }
    if (mounted) {
      _toast(
        _s.t(
          ok
              ? '.qrep files now open with Report Studio'
              : 'Could not register .qrep files',
        ),
        error: !ok,
      );
    }
  }

  void _finishEdits() {
    final ReportDesignerController c = _doc.controller;
    if (c.editingId != null) {
      c.commitTextEdit();
    }
    if (c.editingProperty != null) {
      c.commitPropertyEdit();
    }
  }

  // ------------------------------------------------------------ commands

  /// Asks to save unsaved changes; returns false when the user cancels.
  Future<bool> confirmDiscard() async {
    _finishEdits();
    if (!_doc.dirty) {
      return true;
    }
    final _Discard? answer = await showDialog<_Discard>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.save_outlined),
        title: Text(
          _s.f('Save changes to {name}?', <String, String>{
            'name': _doc.fileName,
          }),
        ),
        content: Text(_s.t("Your changes will be lost if you don't save.")),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, _Discard.cancel),
            child: Text(_s.t('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _Discard.discard),
            child: Text(_s.t("Don't save")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _Discard.save),
            child: Text(_s.t('Save')),
          ),
        ],
      ),
    );
    switch (answer) {
      case _Discard.save:
        return save();
      case _Discard.discard:
        return true;
      case _Discard.cancel:
      case null:
        return false;
    }
  }

  Future<void> _newBlank() async {
    if (await confirmDiscard()) {
      _doc.newBlank();
    }
  }

  Future<void> _newFrom(ReportTemplateInfo info) async {
    if (await confirmDiscard()) {
      _doc.newFromTemplate(info);
    }
  }

  Future<void> _open() async {
    if (!await confirmDiscard()) {
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: _s.t('Open report template'),
      type: FileType.custom,
      allowedExtensions: const <String>['qrep', 'xml'],
      withData: kIsWeb,
    );
    final PlatformFile? file = result?.files.firstOrNull;
    if (file == null) {
      return;
    }
    final String? path = file.path;
    if (path != null && !kIsWeb) {
      await _openPath(path, confirmed: true);
      return;
    }
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    try {
      _doc.loadBytes(bytes, name: file.name);
    } on ReportTemplateException catch (e) {
      _cannot('Cannot open {name}: {error}', file.name, '$e');
    } on ReportPackageException catch (e) {
      _cannot('Cannot open {name}: {error}', file.name, e.message);
    }
  }

  void _cannot(String message, String name, String error) {
    _toast(
      _s.f(message, <String, String>{'name': name, 'error': error}),
      error: true,
    );
  }

  Future<void> _openPath(String path, {bool confirmed = false}) async {
    if (!confirmed && !await confirmDiscard()) {
      return;
    }
    try {
      await _doc.open(path);
      await widget.recent.add(path);
    } on ReportTemplateException catch (e) {
      _cannot(
        'Cannot open {name}: {error}',
        ReportDocument.baseName(path),
        '$e',
      );
    } on ReportPackageException catch (e) {
      _cannot(
        'Cannot open {name}: {error}',
        ReportDocument.baseName(path),
        e.message,
      );
    } on FileSystemException catch (e) {
      await widget.recent.remove(path);
      _cannot(
        'Cannot read {name}: {error}',
        ReportDocument.baseName(path),
        e.message,
      );
    }
  }

  /// Saves to the current path, or asks for one. Returns whether it saved.
  Future<bool> save({bool saveAs = false}) async {
    _finishEdits();
    String? target = saveAs ? null : _doc.path;
    if (target == null) {
      target = await FilePicker.platform.saveFile(
        dialogTitle: _s.t('Save report template'),
        fileName: _doc.fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['qrep'],
      );
      if (target == null) {
        return false;
      }
      if (!target.toLowerCase().endsWith('.qrep')) {
        target = '$target.qrep';
      }
    }
    try {
      await _doc.saveTo(target);
      await widget.recent.add(target);
      _doc.controller.clearLoadDiagnostics();
      _toast(
        _s.f('Saved {name}', <String, String>{
          'name': ReportDocument.baseName(target),
        }),
      );
      return true;
    } on FileSystemException catch (e) {
      _cannot('Cannot save: {error}', '', e.message);
      return false;
    } on ReportPackageException catch (e) {
      _cannot('Cannot save: {error}', '', e.message);
      return false;
    }
  }

  Future<({String name, Uint8List bytes})?> _pickImage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: _s.t('Embed image in report'),
      type: FileType.custom,
      allowedExtensions: const <String>['png', 'jpg', 'jpeg'],
      withData: true,
    );
    final PlatformFile? file = result?.files.firstOrNull;
    final Uint8List? bytes = file?.bytes;
    if (file == null || bytes == null) {
      return null;
    }
    return (name: file.name, bytes: bytes);
  }

  Future<List<({String name, Uint8List bytes})>?> _pickFonts() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: _s.t('Embed TrueType fonts in report'),
      type: FileType.custom,
      allowedExtensions: const <String>['ttf'],
      allowMultiple: true,
      withData: true,
    );
    return <({String name, Uint8List bytes})>[
      for (final PlatformFile file in result?.files ?? const <PlatformFile>[])
        if (file.bytes case final Uint8List bytes)
          (name: file.name, bytes: bytes),
    ];
  }

  Future<({String name, String text})?> _pickData() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: _s.t('Import sample data'),
      type: FileType.custom,
      allowedExtensions: const <String>['csv', 'tsv', 'txt', 'json'],
      withData: true,
    );
    final PlatformFile? file = result?.files.firstOrNull;
    final Uint8List? bytes = file?.bytes;
    if (file == null || bytes == null) {
      return null;
    }
    return (name: file.name, text: utf8.decode(bytes, allowMalformed: true));
  }

  /// Shapefile (with a sibling `.dbf` when the path is known), GeoJSON, or
  /// a previously saved `.qmap` layer.
  Future<({String name, Uint8List bytes, Uint8List? attributes})?>
  _pickShape() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: _s.t('Import shapes'),
      type: FileType.custom,
      allowedExtensions: const <String>['shp', 'geojson', 'json', 'qmap'],
      withData: true,
    );
    final PlatformFile? file = result?.files.singleOrNull;
    final Uint8List? bytes = file?.bytes;
    if (file == null || bytes == null) {
      return null;
    }
    Uint8List? attributes;
    final String path = file.path ?? '';
    if (!kIsWeb && path.isNotEmpty && file.extension?.toLowerCase() == 'shp') {
      final String dbf = path.replaceAll(
        RegExp(r'shp$', caseSensitive: false),
        'dbf',
      );
      final File sibling = File(dbf);
      if (sibling.existsSync()) {
        attributes = await sibling.readAsBytes();
      }
    }
    return (name: file.name, bytes: bytes, attributes: attributes);
  }

  Future<void> _export(ReportExportFormat format, Uint8List bytes) async {
    final String name = '${_doc.name}.${format.name}';
    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: _s.f('Export {format}', <String, String>{
        'format': format.name.toUpperCase(),
      }),
      fileName: name,
      type: FileType.custom,
      allowedExtensions: <String>[format.name],
      bytes: kIsWeb ? bytes : null,
    );
    if (path == null || kIsWeb) {
      return;
    }
    try {
      await File(path).writeAsBytes(bytes, flush: true);
      _toast(
        _s.f('Exported {name}', <String, String>{
          'name': ReportDocument.baseName(path),
        }),
      );
    } on FileSystemException catch (e) {
      _cannot('Cannot export: {error}', '', e.message);
    }
  }

  bool _printing = false;

  /// Asks for [ReportVariable.prompt] values. Cancel leaves the current mode.
  Future<bool> _promptParameters(List<ReportVariable> prompts) async {
    final Map<String, Object?>? answers = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (BuildContext context) => _ParameterDialog(
        strings: _s,
        prompts: prompts,
        previous: _doc.controller.runtimeVariables,
      ),
    );
    if (answers == null) {
      return false;
    }
    _doc.controller.setRuntimeValues(answers);
    return true;
  }

  /// Renders the report with the preview data and opens the print dialog.
  Future<void> printReport() async {
    _finishEdits();
    final List<ReportVariable> prompts = _doc.controller.promptVariables;
    if (prompts.isNotEmpty && !await _promptParameters(prompts)) {
      return;
    }
    try {
      await _print(await _doc.controller.export(ReportExportFormat.pdf));
    } on Object catch (e) {
      _cannot('Cannot print: {error}', '', '$e');
    }
  }

  Future<void> _print(Uint8List document) async {
    if (_printing) {
      return;
    }
    _printing = true;
    try {
      final ReportTemplate t = _doc.controller.template;
      await widget.printer(
        document,
        name: _doc.name,
        width: t.pageWidth,
        height: t.pageHeight,
      );
    } on Object catch (e) {
      _cannot('Cannot print: {error}', '', '$e');
    } finally {
      _printing = false;
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return StudioWindowScope(
      onCloseRequest: confirmDiscard,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyN, control: true):
              _newBlank,
          const SingleActivator(LogicalKeyboardKey.keyO, control: true): _open,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
              save(),
          const SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
            shift: true,
          ): () =>
              save(saveAs: true),
          const SingleActivator(LogicalKeyboardKey.keyP, control: true):
              printReport,
        },
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _titleBar(),
              Expanded(
                child: QudsReportDesigner(
                  controller: _doc.controller,
                  theme: _p.office,
                  strings: _s.designer,
                  templates: _catalog.all,
                  inspectorWidth: StudioSettings.defaultInspectorWidth,
                  initialInspectorWidth: _startInspectorWidth,
                  onInspectorWidthChanged: widget.settings.setInspectorWidth,
                  onExport: _export,
                  onPrint: _print,
                  onPickImage: _pickImage,
                  onPickFont: _pickFonts,
                  onPickData: _pickData,
                  onPickShape: _pickShape,
                  onPromptParameters: _promptParameters,
                  deviceFonts: widget.deviceFonts,
                ),
              ),
              _statusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar() {
    final StudioPalette p = _p;
    final Color ink = p.titleInk;
    return Material(
      color: p.titleBar,
      child: SizedBox(
        height: 38,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const WindowDragArea(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(width: 10),
                const _AppMark(),
                const SizedBox(width: 6),
                _fileMenuButton(),
                _QuickButton(
                  icon: Icons.note_add_outlined,
                  tooltip: _s.t('New (Ctrl+N)'),
                  ink: ink,
                  hover: p.titleHover,
                  onPressed: _newBlank,
                ),
                _QuickButton(
                  icon: Icons.folder_open_outlined,
                  tooltip: _s.t('Open (Ctrl+O)'),
                  ink: ink,
                  hover: p.titleHover,
                  onPressed: _open,
                ),
                _QuickButton(
                  icon: Icons.save_outlined,
                  tooltip: _s.t('Save (Ctrl+S)'),
                  ink: ink,
                  hover: p.titleHover,
                  onPressed: save,
                ),
                _QuickButton(
                  icon: Icons.print_outlined,
                  tooltip: _s.t('Print (Ctrl+P)'),
                  ink: ink,
                  hover: p.titleHover,
                  onPressed: printReport,
                ),
                Expanded(
                  child: WindowDragArea(
                    child: IgnorePointer(
                      child: Center(child: _documentTitle(ink)),
                    ),
                  ),
                ),
                _settingsMenuButton(),
                const SizedBox(width: 4),
                WindowCaptionButtons(foreground: ink),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentTitle(Color ink) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            _doc.fileName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_doc.dirty) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _s.t('Edited'),
              style: TextStyle(color: ink, fontSize: 11),
            ),
          ),
        ],
        Text(
          '  —  ${_s.t('Quds Report Studio')}',
          style: TextStyle(color: ink.withValues(alpha: 0.65), fontSize: 12.5),
        ),
      ],
    );
  }

  static IconData _categoryIcon(ReportTemplateCategory c) => switch (c) {
    ReportTemplateCategory.sales => Icons.point_of_sale,
    ReportTemplateCategory.finance => Icons.account_balance,
    ReportTemplateCategory.inventory => Icons.inventory_2,
    ReportTemplateCategory.analytics => Icons.insights,
    ReportTemplateCategory.hr => Icons.badge_outlined,
  };

  /// Category › family › language submenus for the bundled templates, then
  /// the user's own templates.
  List<Widget> _templateMenus() {
    final List<ReportTemplateInfo> all = _catalog.bundled;
    final List<ReportTemplateInfo> heads = <ReportTemplateInfo>[];
    final Set<String> seen = <String>{};
    for (final ReportTemplateInfo info in all) {
      if (seen.add(info.family)) {
        heads.add(info);
      }
    }
    Widget variant(ReportTemplateInfo info) => MenuItemButton(
      leadingIcon: const Icon(Icons.translate, size: 18),
      trailingIcon: Text(
        info.language.code.toUpperCase(),
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
      ),
      onPressed: () => _newFrom(info),
      child: Text(info.language.label),
    );
    Widget family(ReportTemplateInfo head) => SubmenuButton(
      menuChildren: <Widget>[
        for (final ReportTemplateInfo info in all)
          if (info.family == head.family) variant(info),
      ],
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(head.familyTitle)),
                const SizedBox(width: 12),
                Text(
                  head.familyTitleAr,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            Text(
              head.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
    return <Widget>[
      for (final ReportTemplateCategory c in ReportTemplateCategory.values)
        if (heads.any((ReportTemplateInfo t) => t.category == c))
          SubmenuButton(
            leadingIcon: Icon(_categoryIcon(c), size: 18),
            menuChildren: <Widget>[
              for (final ReportTemplateInfo head in heads)
                if (head.category == c) family(head),
            ],
            child: Text('${c.title}  ·  ${c.titleAr}'),
          ),
      if (_catalog.folder != null) ...<Widget>[
        const Divider(height: 8),
        SubmenuButton(
          leadingIcon: const Icon(Icons.bookmarks_outlined, size: 18),
          menuChildren: <Widget>[
            if (_catalog.user.isEmpty)
              MenuItemButton(
                child: Text(
                  _s.t('No templates yet. Use File › Save as template.'),
                ),
              ),
            for (final ReportTemplateInfo info in _catalog.user)
              MenuItemButton(
                leadingIcon: Icon(_categoryIcon(info.category), size: 18),
                trailingIcon: Text(
                  info.language.code.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                onPressed: () => _newFrom(info),
                child: Text(info.title),
              ),
          ],
          child: Text(_s.t('My templates')),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_special_outlined, size: 18),
          onPressed: _openTemplatesFolder,
          child: Text(_s.t('Open templates folder')),
        ),
      ],
    ];
  }

  Future<void> _saveAsTemplate(ReportTemplateCategory category) async {
    _finishEdits();
    final ReportDesignerController c = _doc.controller;
    final String title = c.template.name.trim().isEmpty
        ? _doc.name
        : c.template.name.trim();
    try {
      final ReportTemplateInfo info = await _catalog.save(
        ReportPackage.decode(c.toPackage()),
        title: title,
        category: category,
        rtl: c.template.isRtl,
      );
      _toast(
        _s.f('Saved as template "{name}"', <String, String>{
          'name': info.title,
        }),
      );
    } on FileSystemException catch (e) {
      _cannot('Cannot save the template: {error}', '', e.message);
    } on ReportPackageException catch (e) {
      _cannot('Cannot save the template: {error}', '', e.message);
    }
  }

  Future<void> _openTemplatesFolder() async {
    final Directory? dir = _catalog.folder;
    if (dir == null) {
      return;
    }
    try {
      await dir.create(recursive: true);
      final String opener = Platform.isWindows
          ? 'explorer'
          : Platform.isMacOS
          ? 'open'
          : 'xdg-open';
      await Process.start(opener, <String>[dir.path], runInShell: false);
      await _catalog.load();
    } on FileSystemException catch (e) {
      _cannot('Cannot open {name}: {error}', dir.path, e.message);
    } on ProcessException catch (e) {
      _cannot('Cannot open {name}: {error}', dir.path, e.message);
    }
  }

  Widget _fileMenuButton() {
    final List<String> recent = widget.recent.paths;
    return MenuAnchor(
      controller: _fileMenu,
      alignmentOffset: const Offset(0, 2),
      onOpen: () => unawaited(_catalog.load()),
      menuChildren: <Widget>[
        MenuItemButton(
          leadingIcon: const Icon(Icons.note_add_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyN,
            control: true,
          ),
          onPressed: _newBlank,
          child: Text(_s.t('New blank report')),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.dashboard_customize_outlined, size: 18),
          menuChildren: _templateMenus(),
          child: Text(_s.t('New from template')),
        ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_open_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyO,
            control: true,
          ),
          onPressed: _open,
          child: Text(_s.t('Open…')),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.history, size: 18),
          menuChildren: <Widget>[
            if (recent.isEmpty)
              MenuItemButton(child: Text(_s.t('No recent files'))),
            for (final String path in recent)
              MenuItemButton(
                onPressed: () => _openPath(path),
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(ReportDocument.baseName(path)),
                      Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (recent.isNotEmpty) ...<Widget>[
              const Divider(height: 8),
              MenuItemButton(
                onPressed: widget.recent.clear,
                child: Text(_s.t('Clear recent files')),
              ),
            ],
          ],
          child: Text(_s.t('Open recent')),
        ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.save_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
          ),
          onPressed: save,
          child: Text(_s.t('Save')),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.save_as_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
            shift: true,
          ),
          onPressed: () => save(saveAs: true),
          child: Text(_s.t('Save as…')),
        ),
        if (_catalog.folder != null)
          SubmenuButton(
            leadingIcon: const Icon(Icons.bookmark_add_outlined, size: 18),
            menuChildren: <Widget>[
              for (final ReportTemplateCategory c
                  in ReportTemplateCategory.values)
                MenuItemButton(
                  leadingIcon: Icon(_categoryIcon(c), size: 18),
                  onPressed: () => _saveAsTemplate(c),
                  child: Text(_s.isRtl ? c.titleAr : c.title),
                ),
            ],
            child: Text(_s.t('Save as template')),
          ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.print_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyP,
            control: true,
          ),
          onPressed: printReport,
          child: Text(_s.t('Print…')),
        ),
        if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) ...<Widget>[
          const Divider(height: 8),
          MenuItemButton(
            leadingIcon: const Icon(Icons.link, size: 18),
            onPressed: _associateFiles,
            child: Text(_s.t('Open .qrep files with Report Studio')),
          ),
        ],
        if (StudioWindow.supported) ...<Widget>[
          const Divider(height: 8),
          MenuItemButton(
            leadingIcon: const Icon(Icons.logout, size: 18),
            onPressed: StudioWindow.close,
            child: Text(_s.t('Exit')),
          ),
        ],
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return _QuickButton(
              label: _s.t('File'),
              icon: Icons.menu,
              tooltip: _s.t('File menu'),
              ink: _p.titleInk,
              hover: _p.titleHover,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            );
          },
    );
  }

  Widget _settingsMenuButton() {
    final StudioSettings settings = widget.settings;
    final StudioStrings s = _s;
    Widget check(bool on) => Icon(on ? Icons.check : null, size: 18);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 2),
      menuChildren: <Widget>[
        SubmenuButton(
          leadingIcon: const Icon(Icons.contrast, size: 18),
          menuChildren: <Widget>[
            for (final (StudioThemeChoice choice, IconData icon, String label)
                in <(StudioThemeChoice, IconData, String)>[
                  (
                    StudioThemeChoice.system,
                    Icons.brightness_auto_outlined,
                    'Same as the system',
                  ),
                  (StudioThemeChoice.light, Icons.light_mode_outlined, 'Light'),
                  (StudioThemeChoice.dark, Icons.dark_mode_outlined, 'Dark'),
                ])
              MenuItemButton(
                leadingIcon: Icon(icon, size: 18),
                trailingIcon: check(settings.theme == choice),
                onPressed: () => settings.setTheme(choice),
                child: Text(s.t(label)),
              ),
          ],
          child: Text(s.t('Theme')),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.translate, size: 18),
          menuChildren: <Widget>[
            for (final (StudioLanguage choice, String label)
                in <(StudioLanguage, String)>[
                  (StudioLanguage.system, s.t('Same as the system')),
                  (StudioLanguage.english, 'English'),
                  (StudioLanguage.arabic, 'العربية'),
                ])
              MenuItemButton(
                trailingIcon: check(settings.language == choice),
                onPressed: () => settings.setLanguage(choice),
                child: Text(label),
              ),
          ],
          child: Text(s.t('Language')),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return _QuickButton(
              icon: Icons.settings_outlined,
              tooltip: s.t('Settings'),
              ink: _p.titleInk,
              hover: _p.titleHover,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            );
          },
    );
  }

  Widget _statusBar() {
    final ReportDesignerController c = _doc.controller;
    final StudioPalette p = _p;
    final StudioStrings s = _s;
    final TextStyle style = TextStyle(fontSize: 11.5, color: p.statusInk);
    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, Widget? child) {
        final ReportTemplate t = c.template;
        final int elements = t.allElements.length;
        final List<ReportDiagnostic> problems = c.problems;
        final int errors = problems
            .where((ReportDiagnostic d) => d.isError)
            .length;
        final int warnings = problems.length - errors;
        return Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: p.status,
            border: Border(top: BorderSide(color: p.statusBorder)),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                _doc.dirty ? Icons.edit_note : Icons.check_circle_outline,
                size: 15,
                color: _doc.dirty ? p.warning : p.ok,
              ),
              const SizedBox(width: 6),
              Text(s.t(_doc.dirty ? 'Unsaved changes' : 'Saved'), style: style),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _doc.path ?? s.t('Not saved to disk yet'),
                  overflow: TextOverflow.ellipsis,
                  textDirection: _doc.path == null ? null : TextDirection.ltr,
                  style: style.copyWith(color: p.statusMuted),
                ),
              ),
              _StatusChip(
                icon: Icons.layers_outlined,
                text:
                    '${s.count(t.bands.length, 'band')} · '
                    '${s.count(elements, 'element')}',
                color: p.statusInk,
              ),
              _StatusChip(
                icon: Icons.data_object,
                text: s.count(t.variables.length, 'variable'),
                color: p.statusInk,
              ),
              _StatusChip(
                icon: errors > 0
                    ? Icons.error_outline
                    : warnings > 0
                    ? Icons.warning_amber_rounded
                    : Icons.verified_outlined,
                text: errors + warnings == 0
                    ? s.t('No problems')
                    : '${s.count(errors, 'error')} · '
                          '${s.count(warnings, 'warning')}',
                color: errors > 0
                    ? p.error
                    : warnings > 0
                    ? p.warning
                    : p.ok,
                tooltip: s.t(
                  c.problemsOpen ? 'Hide problems' : 'Show problems',
                ),
                active: c.problemsOpen,
                hover: p.statusInk.withValues(alpha: 0.08),
                onPressed: () => c.problemsOpen = !c.problemsOpen,
              ),
              _StatusChip(
                icon: Icons.straighten,
                text:
                    '${s.designer.option(t.pageSize.name)} · '
                    '${s.designer.option(t.orientation.name)} · '
                    '${s.designer.option(t.unit.name)}',
                color: p.statusInk,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _Discard { save, discard, cancel }

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/icon/app_icon_256.png',
        width: 24,
        height: 24,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.ink,
    required this.hover,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? label;
  final Color ink;
  final Color hover;

  @override
  Widget build(BuildContext context) {
    final String? label = this.label;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onPressed,
        hoverColor: hover,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 10),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 17, color: ink),
              if (label != null) ...<Widget>[
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: ink, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.text,
    this.color,
    this.tooltip,
    this.onPressed,
    this.active = false,
    this.hover,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final Color? hover;

  @override
  Widget build(BuildContext context) {
    final Color tone = color ?? const Color(0xFF4B5563);
    final Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: tone),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11.5, color: tone)),
      ],
    );
    final VoidCallback? onPressed = this.onPressed;
    final String? tooltip = this.tooltip;
    if (onPressed == null) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 18),
        child: label,
      );
    }
    final Widget button = InkWell(
      onTap: onPressed,
      hoverColor: hover,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? tone.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: label,
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12),
      child: tooltip == null
          ? button
          : Tooltip(
              message: tooltip,
              waitDuration: const Duration(milliseconds: 500),
              child: button,
            ),
    );
  }
}

/// Collects one answer per prompted variable. Cancel pops null.
class _ParameterDialog extends StatefulWidget {
  const _ParameterDialog({
    required this.strings,
    required this.prompts,
    required this.previous,
  });

  final StudioStrings strings;
  final List<ReportVariable> prompts;
  final Map<String, Object?> previous;

  @override
  State<_ParameterDialog> createState() => _ParameterDialogState();
}

class _ParameterDialogState extends State<_ParameterDialog> {
  late final List<TextEditingController> _fields;
  late final List<bool> _flags;
  String? _error;
  int? _invalid;

  @override
  void initState() {
    super.initState();
    _fields = <TextEditingController>[
      for (final ReportVariable v in widget.prompts)
        if (v.type != ReportVariableType.boolean)
          TextEditingController(text: _initial(v)),
    ];
    _flags = <bool>[
      for (final ReportVariable v in widget.prompts)
        if (v.type == ReportVariableType.boolean) _initialBool(v),
    ];
  }

  String _initial(ReportVariable v) {
    final Object? prior = widget.previous[v.name];
    if (prior != null) {
      return '$prior';
    }
    return v.value;
  }

  bool _initialBool(ReportVariable v) {
    final Object? prior = widget.previous[v.name];
    if (prior is bool) {
      return prior;
    }
    return switch (v.literal()) {
      ReportBool(:final bool value) => value,
      _ => false,
    };
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final Map<String, Object?> out = <String, Object?>{};
    var text = 0;
    var flag = 0;
    for (var i = 0; i < widget.prompts.length; i++) {
      final ReportVariable v = widget.prompts[i];
      if (v.type == ReportVariableType.boolean) {
        out[v.name] = _flags[flag];
        flag++;
        continue;
      }
      final String raw = _fields[text].text;
      text++;
      if (v.required && raw.trim().isEmpty) {
        setState(() {
          _invalid = i;
          _error = widget.strings.t('This value is required');
        });
        return;
      }
      out[v.name] = _typed(v, raw);
    }
    Navigator.pop(context, out);
  }

  Object? _typed(ReportVariable v, String raw) {
    final String s = raw.trim();
    switch (v.type) {
      case ReportVariableType.number:
        final String n = s.replaceAll(',', '').replaceAll(' ', '');
        return num.tryParse(n) ?? raw;
      case ReportVariableType.date:
        return DateTime.tryParse(s) ?? raw;
      case ReportVariableType.boolean:
        return s == 'true';
      case ReportVariableType.text:
      case ReportVariableType.list:
      case ReportVariableType.expression:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudioStrings s = widget.strings;
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final ColorScheme scheme = theme.colorScheme;
    final Color header = dark
        ? const Color(0xFF1B2433)
        : const Color(0xFF1F3B63);
    final Color paper = dark ? const Color(0xFF24272D) : Colors.white;
    final Color card = dark ? const Color(0xFF1B1E23) : const Color(0xFFF4F6F9);
    final Color line = dark ? const Color(0xFF3A3F47) : const Color(0xFFE3E7ED);
    final Color muted = dark
        ? const Color(0xFF9AA1AB)
        : const Color(0xFF6B7280);
    final List<Widget> fields = <Widget>[];
    var text = 0;
    var flag = 0;
    final int firstText = widget.prompts.indexWhere(
      (ReportVariable v) => v.type != ReportVariableType.boolean,
    );
    for (var i = 0; i < widget.prompts.length; i++) {
      final ReportVariable v = widget.prompts[i];
      final bool invalid = _invalid == i;
      if (v.type == ReportVariableType.boolean) {
        final int slot = flag;
        flag++;
        fields.add(
          _card(
            card: card,
            line: invalid ? scheme.error : line,
            child: _boolRow(s, v, slot, muted),
          ),
        );
      } else {
        final int slot = text;
        text++;
        fields.add(
          _card(
            card: card,
            line: invalid ? scheme.error : line,
            child: _textRow(
              s,
              v,
              slot,
              promptIndex: i,
              muted: muted,
              scheme: scheme,
              paper: paper,
              autofocus: i == firstText,
              invalid: invalid,
            ),
          ),
        );
      }
    }
    return Dialog(
      backgroundColor: paper,
      elevation: 16,
      shadowColor: const Color(0x66000000),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(s, header),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.56,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: fields,
                ),
              ),
            ),
            Divider(height: 1, color: line),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 12),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s.t('Cancel')),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(s.t('Continue')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(StudioStrings s, Color header) {
    return DecoratedBox(
      decoration: BoxDecoration(color: header),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x24FFFFFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.t('Report parameters'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.t(
                      'Enter the values for this run. Saved defaults stay in the template.',
                    ),
                    style: const TextStyle(
                      color: Color(0xD6FFFFFF),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required Color card,
    required Color line,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: child,
    );
  }

  Widget _boolRow(StudioStrings s, ReportVariable v, int slot, Color muted) {
    final String label = v.description.isEmpty ? v.name : v.description;
    return Row(
      children: <Widget>[
        Icon(_typeIcon(v.type), size: 18, color: const Color(0xFF2B5797)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _labelRow(s, label, v.required),
              const SizedBox(height: 2),
              Text(
                '${v.name} · ${s.t(_typeLabel(v.type))}',
                style: TextStyle(color: muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        Switch(
          value: _flags[slot],
          onChanged: (bool value) => setState(() => _flags[slot] = value),
        ),
      ],
    );
  }

  Widget _textRow(
    StudioStrings s,
    ReportVariable v,
    int slot, {
    required int promptIndex,
    required Color muted,
    required ColorScheme scheme,
    required Color paper,
    required bool autofocus,
    required bool invalid,
  }) {
    final String label = v.description.isEmpty ? v.name : v.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _labelRow(s, label, v.required),
        const SizedBox(height: 2),
        Text(
          '${v.name} · ${s.t(_typeLabel(v.type))}',
          style: TextStyle(color: muted, fontSize: 11.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fields[slot],
          autofocus: autofocus,
          keyboardType: _keyboard(v.type),
          style: const TextStyle(fontSize: 14),
          onChanged: (_) {
            if (_invalid == promptIndex) {
              setState(() {
                _invalid = null;
                _error = null;
              });
            }
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: paper,
            hintText: _hint(s, v.type),
            hintStyle: TextStyle(color: muted, fontSize: 13),
            prefixIcon: Icon(_typeIcon(v.type), size: 18),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 36,
            ),
            suffixIcon: v.type == ReportVariableType.date
                ? IconButton(
                    tooltip: s.t('Pick a date'),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    onPressed: () => _pickDate(slot),
                  )
                : null,
            errorText: invalid ? _error : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: invalid ? scheme.error : scheme.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: invalid ? scheme.error : const Color(0xFF2B5797),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _labelRow(StudioStrings s, String label, bool required) {
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        if (required) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x1AB3261E),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              s.t('Required'),
              style: const TextStyle(
                color: Color(0xFFB3261E),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickDate(int slot) async {
    final DateTime initial =
        DateTime.tryParse(_fields[slot].text.trim()) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    final String month = picked.month.toString().padLeft(2, '0');
    final String day = picked.day.toString().padLeft(2, '0');
    setState(() {
      _fields[slot].text = '${picked.year}-$month-$day';
      _invalid = null;
      _error = null;
    });
  }

  String _typeLabel(ReportVariableType type) => switch (type) {
    ReportVariableType.text => 'Text value',
    ReportVariableType.number => 'Number value',
    ReportVariableType.date => 'Date value',
    ReportVariableType.boolean => 'Yes or no',
    ReportVariableType.list => 'List value',
    ReportVariableType.expression => 'Expression value',
  };

  IconData _typeIcon(ReportVariableType type) => switch (type) {
    ReportVariableType.text => Icons.notes_outlined,
    ReportVariableType.number => Icons.tag,
    ReportVariableType.date => Icons.calendar_today_outlined,
    ReportVariableType.boolean => Icons.toggle_on_outlined,
    ReportVariableType.list => Icons.format_list_bulleted,
    ReportVariableType.expression => Icons.functions,
  };

  TextInputType _keyboard(ReportVariableType type) => switch (type) {
    ReportVariableType.number => TextInputType.number,
    ReportVariableType.date => TextInputType.datetime,
    _ => TextInputType.text,
  };

  String? _hint(StudioStrings s, ReportVariableType type) => switch (type) {
    ReportVariableType.date => 'yyyy-MM-dd',
    ReportVariableType.list => s.t('Separate items with ;'),
    ReportVariableType.expression => s.t('Formula without braces'),
    _ => null,
  };
}
