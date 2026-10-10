import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'recent_files.dart';
import 'report_document.dart';
import 'studio_window.dart';

/// Brand colors of the studio chrome.
abstract final class StudioColors {
  static const Color chrome = Color(0xFF1F3B63);
  static const Color chromeLight = Color(0xFF2B5797);
  static const Color accent = Color(0xFF4F9DFF);
  static const Color status = Color(0xFFF3F5F8);
}

/// Main window: title bar with the File menu, the designer, and a status bar.
class ReportStudioPage extends StatefulWidget {
  const ReportStudioPage({
    super.key,
    required this.recent,
    this.initialPath,
    this.templates = ReportTemplates.all,
  });

  /// Recently opened files.
  final RecentFiles recent;

  /// File to open on start (command-line argument).
  final String? initialPath;

  /// Starter templates offered by File › New from template.
  final List<ReportTemplateInfo> templates;

  @override
  State<ReportStudioPage> createState() => ReportStudioPageState();
}

/// State of [ReportStudioPage]; public so tests can drive file commands.
class ReportStudioPageState extends State<ReportStudioPage> {
  final ReportDocument _doc = ReportDocument();
  final MenuController _fileMenu = MenuController();

  /// The open document.
  ReportDocument get document => _doc;

  @override
  void initState() {
    super.initState();
    _doc.addListener(_onDocument);
    final String? path = widget.initialPath;
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPath(path));
    } else if (widget.templates.isNotEmpty) {
      _doc.newFromTemplate(widget.templates.first);
    }
    _onDocument();
  }

  @override
  void dispose() {
    _doc.removeListener(_onDocument);
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

  void _toast(String text, {bool error = false}) {
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
          duration: const Duration(seconds: 3),
        ),
      );
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
        title: Text('Save changes to ${_doc.fileName}?'),
        content: const Text('Your changes will be lost if you don\'t save.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, _Discard.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _Discard.discard),
            child: const Text('Don\'t save'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _Discard.save),
            child: const Text('Save'),
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
      dialogTitle: 'Open report template',
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
      _doc.loadXml(utf8.decode(bytes), name: file.name);
    } on ReportTemplateException catch (e) {
      _toast('Cannot open ${file.name}: $e', error: true);
    }
  }

  Future<void> _openPath(String path, {bool confirmed = false}) async {
    if (!confirmed && !await confirmDiscard()) {
      return;
    }
    try {
      await _doc.open(path);
      await widget.recent.add(path);
    } on ReportTemplateException catch (e) {
      _toast('Cannot open ${ReportDocument.baseName(path)}: $e', error: true);
    } on FileSystemException catch (e) {
      await widget.recent.remove(path);
      _toast(
        'Cannot read ${ReportDocument.baseName(path)}: ${e.message}',
        error: true,
      );
    }
  }

  /// Saves to the current path, or asks for one. Returns whether it saved.
  Future<bool> save({bool saveAs = false}) async {
    _finishEdits();
    String? target = saveAs ? null : _doc.path;
    if (target == null) {
      target = await FilePicker.platform.saveFile(
        dialogTitle: 'Save report template',
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
      _toast('Saved ${ReportDocument.baseName(target)}');
      return true;
    } on FileSystemException catch (e) {
      _toast('Cannot save: ${e.message}', error: true);
      return false;
    }
  }

  Future<void> _export(ReportExportFormat format, Uint8List bytes) async {
    final String name = '${_doc.name}.${format.name}';
    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export ${format.name.toUpperCase()}',
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
      _toast('Exported ${ReportDocument.baseName(path)}');
    } on FileSystemException catch (e) {
      _toast('Cannot export: ${e.message}', error: true);
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
        },
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _titleBar(),
              Expanded(
                child: QudsReportDesigner(
                  controller: _doc.controller,
                  templates: widget.templates,
                  inspectorWidth: 320,
                  onExport: _export,
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
    const Color ink = Colors.white;
    return Material(
      color: StudioColors.chrome,
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
                  tooltip: 'New (Ctrl+N)',
                  onPressed: _newBlank,
                ),
                _QuickButton(
                  icon: Icons.folder_open_outlined,
                  tooltip: 'Open (Ctrl+O)',
                  onPressed: _open,
                ),
                _QuickButton(
                  icon: Icons.save_outlined,
                  tooltip: 'Save (Ctrl+S)',
                  onPressed: save,
                ),
                Expanded(
                  child: WindowDragArea(
                    child: IgnorePointer(
                      child: Center(child: _documentTitle(ink)),
                    ),
                  ),
                ),
                const WindowCaptionButtons(foreground: ink),
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
            style: const TextStyle(
              color: Colors.white,
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
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Edited',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
        Text(
          '  —  Quds Report Studio',
          style: TextStyle(color: ink.withValues(alpha: 0.65), fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _fileMenuButton() {
    final List<String> recent = widget.recent.paths;
    return MenuAnchor(
      controller: _fileMenu,
      alignmentOffset: const Offset(0, 2),
      menuChildren: <Widget>[
        MenuItemButton(
          leadingIcon: const Icon(Icons.note_add_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyN,
            control: true,
          ),
          onPressed: _newBlank,
          child: const Text('New blank report'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.dashboard_customize_outlined, size: 18),
          menuChildren: <Widget>[
            for (final ReportTemplateInfo info in widget.templates)
              MenuItemButton(
                onPressed: () => _newFrom(info),
                child: SizedBox(
                  width: 280,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(info.title),
                      Text(
                        info.description,
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
          ],
          child: const Text('New from template'),
        ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_open_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyO,
            control: true,
          ),
          onPressed: _open,
          child: const Text('Open…'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.history, size: 18),
          menuChildren: <Widget>[
            if (recent.isEmpty)
              const MenuItemButton(child: Text('No recent files')),
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
                child: const Text('Clear recent files'),
              ),
            ],
          ],
          child: const Text('Open recent'),
        ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.save_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
          ),
          onPressed: save,
          child: const Text('Save'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.save_as_outlined, size: 18),
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
            shift: true,
          ),
          onPressed: () => save(saveAs: true),
          child: const Text('Save as…'),
        ),
        if (StudioWindow.supported) ...<Widget>[
          const Divider(height: 8),
          MenuItemButton(
            leadingIcon: const Icon(Icons.logout, size: 18),
            onPressed: StudioWindow.close,
            child: const Text('Exit'),
          ),
        ],
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return _QuickButton(
              label: 'File',
              icon: Icons.menu,
              tooltip: 'File menu',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            );
          },
    );
  }

  int _diagnosticsRevision = -1;
  List<ReportDiagnostic> _diagnostics = const <ReportDiagnostic>[];

  List<ReportDiagnostic> get _currentDiagnostics {
    final ReportDesignerController c = _doc.controller;
    if (_diagnosticsRevision != c.revision) {
      _diagnosticsRevision = c.revision;
      try {
        _diagnostics = c.validate();
      } on Object catch (e) {
        _diagnostics = <ReportDiagnostic>[
          ReportDiagnostic(ReportDiagnosticSeverity.error, 'template', '$e'),
        ];
      }
    }
    return _diagnostics;
  }

  Widget _statusBar() {
    final ReportDesignerController c = _doc.controller;
    const TextStyle style = TextStyle(fontSize: 11.5, color: Color(0xFF374151));
    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, Widget? child) {
        final ReportTemplate t = c.template;
        final int elements = t.allElements.length;
        final List<ReportDiagnostic> diagnostics = _currentDiagnostics;
        final int errors = diagnostics
            .where(
              (ReportDiagnostic d) =>
                  d.severity == ReportDiagnosticSeverity.error,
            )
            .length;
        final int warnings = diagnostics.length - errors;
        return Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: StudioColors.status,
            border: Border(top: BorderSide(color: Color(0xFFD9DEE5))),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                _doc.dirty ? Icons.edit_note : Icons.check_circle_outline,
                size: 15,
                color: _doc.dirty
                    ? const Color(0xFFB45309)
                    : const Color(0xFF15803D),
              ),
              const SizedBox(width: 6),
              Text(_doc.dirty ? 'Unsaved changes' : 'Saved', style: style),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _doc.path ?? 'Not saved to disk yet',
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: const Color(0xFF6B7280)),
                ),
              ),
              _StatusChip(
                icon: Icons.layers_outlined,
                text: '${t.bands.length} bands · $elements elements',
              ),
              _StatusChip(
                icon: Icons.data_object,
                text: '${t.variables.length} variables',
              ),
              _StatusChip(
                icon: errors > 0
                    ? Icons.error_outline
                    : warnings > 0
                    ? Icons.warning_amber_rounded
                    : Icons.verified_outlined,
                text: errors + warnings == 0
                    ? 'No problems'
                    : '$errors errors · $warnings warnings',
                color: errors > 0
                    ? const Color(0xFFB3261E)
                    : warnings > 0
                    ? const Color(0xFFB45309)
                    : const Color(0xFF15803D),
              ),
              _StatusChip(
                icon: Icons.straighten,
                text:
                    '${t.pageSize.name} · ${t.orientation.name} · ${t.unit.name}',
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
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[StudioColors.accent, Color(0xFF7C4DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(Icons.assessment, size: 15, color: Colors.white),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final String? label = this.label;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onPressed,
        hoverColor: Colors.white.withValues(alpha: 0.12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 10),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 17, color: Colors.white),
              if (label != null) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tone = color ?? const Color(0xFF4B5563);
    return Padding(
      padding: const EdgeInsets.only(left: 18),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 11.5, color: tone)),
        ],
      ),
    );
  }
}
