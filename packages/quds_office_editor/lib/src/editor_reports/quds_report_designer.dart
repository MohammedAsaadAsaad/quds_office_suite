import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quds_office_engine/quds_reports.dart';

import '../editor_sheet/inline_cell_editor.dart';
import '../embed/office_context_menu.dart';
import '../embed/office_host_fonts.dart';
import '../embed/office_theme.dart';
import 'render_report_designer.dart';
import 'render_report_inspector.dart';
import 'render_report_preview.dart';
import 'render_report_toolbar.dart';
import 'report_completion_popup.dart';
import 'report_bundled_fonts.dart';
import 'report_designer_controller.dart';

/// Band report designer: toolbar, design canvas or live preview, and the
/// property inspector, all painted by custom RenderBoxes.
///
/// ```dart
/// final controller = ReportDesignerController.fromXml(qrepXml);
/// QudsReportDesigner(
///   controller: controller,
///   onExport: (format, bytes) => save(format, bytes),
/// );
/// ```
class QudsReportDesigner extends StatefulWidget {
  /// QudsReportDesigner API.
  const QudsReportDesigner({
    super.key,
    required this.controller,
    this.theme = OfficeTheme.light,
    this.inspectorWidth = 300,
    this.focusNode,
    this.autofocus = true,
    this.loadBundledFonts = true,
    this.onExport,
    this.templates = ReportTemplates.all,
  });

  /// controller API.
  final ReportDesignerController controller;

  /// theme API.
  final OfficeTheme theme;

  /// Width of the property inspector, logical pixels.
  final double inspectorWidth;

  /// Keyboard focus; created internally when null.
  final FocusNode? focusNode;

  /// autofocus API.
  final bool autofocus;

  /// When the controller has no fonts, load the faces bundled with this
  /// package (Liberation, Noto Naskh Arabic) for the preview and exports.
  final bool loadBundledFonts;

  /// Receives exported bytes; the export button is hidden when null.
  final void Function(ReportExportFormat format, Uint8List bytes)? onExport;

  /// Ready-made reports offered by the Templates button (hidden when empty).
  /// Picking one replaces the template and uses its sample data.
  final List<ReportTemplateInfo> templates;

  @override
  State<QudsReportDesigner> createState() => _QudsReportDesignerState();
}

class _QudsReportDesignerState extends State<QudsReportDesigner> {
  FocusNode? _ownFocus;
  OverlayEntry? _menu;
  String _message = '';
  final GlobalKey _inspectorKey = GlobalKey();

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  ReportDesignerController get _c => widget.controller;

  static const double _mm = 72 / 25.4;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
    OfficeHostFonts.ensureRegistered().then((_) {
      if (mounted) {
        _c.refresh();
      }
    });
    _loadFonts();
  }

  @override
  void didUpdateWidget(QudsReportDesigner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _loadFonts();
    }
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _ownFocus?.dispose();
      _ownFocus = null;
    }
  }

  @override
  void dispose() {
    _dismissMenu();
    _c.removeListener(_onController);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _loadFonts() {
    if (!widget.loadBundledFonts || !_c.fonts.isEmpty) {
      return;
    }
    final ReportDesignerController target = _c;
    ReportBundledFonts.shared().then(
      (ReportFontRegistry fonts) {
        if (mounted && identical(target, _c) && _c.fonts.isEmpty) {
          _c.useFonts(fonts);
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() => _message = 'Fonts unavailable: $e');
        }
      },
    );
  }

  void _onController() {
    if (mounted) {
      setState(() => _message = '');
    }
  }

  void _activate() {
    if (!_focus.hasFocus) {
      _focus.requestFocus();
    }
  }

  // ------------------------------------------------------------ menus

  void _dismissMenu() {
    OfficeContextMenu.dismiss(_menu);
    _menu = null;
  }

  void _showMenu(
    Offset at,
    List<OfficeContextAction> actions,
    ValueChanged<String> onSelect,
  ) {
    _dismissMenu();
    _menu = OfficeContextMenu.show(
      context: context,
      globalPosition: at,
      actions: actions,
      onSelect: (String id) {
        _menu = null;
        onSelect(id);
      },
    );
  }

  void _canvasMenu(ReportCanvasContextHit hit) {
    _activate();
    final String? id = hit.elementId;
    final ReportElement? element = id == null
        ? null
        : _c.template.findElement(id)?.$2;
    final bool any = _c.selection.isNotEmpty;
    final List<OfficeContextAction> actions = <OfficeContextAction>[
      if (element is ReportTextElement)
        const OfficeContextAction(
          id: 'editText',
          label: 'Edit text',
          icon: Icons.edit,
          shortcut: 'F2',
        ),
      OfficeContextAction(
        id: 'cut',
        label: 'Cut',
        icon: Icons.content_cut,
        shortcut: 'Ctrl+X',
        enabled: any,
        separatorBefore: element is ReportTextElement,
      ),
      OfficeContextAction(
        id: 'copy',
        label: 'Copy',
        icon: Icons.content_copy,
        shortcut: 'Ctrl+C',
        enabled: any,
      ),
      OfficeContextAction(
        id: 'paste',
        label: 'Paste',
        icon: Icons.content_paste,
        shortcut: 'Ctrl+V',
        enabled: _c.canPaste,
      ),
      OfficeContextAction(
        id: 'duplicate',
        label: 'Duplicate',
        icon: Icons.copy_all,
        shortcut: 'Ctrl+D',
        enabled: any,
      ),
      OfficeContextAction(
        id: 'front',
        label: 'Bring to front',
        icon: Icons.flip_to_front,
        enabled: any,
        separatorBefore: true,
      ),
      OfficeContextAction(
        id: 'back',
        label: 'Send to back',
        icon: Icons.flip_to_back,
        enabled: any,
      ),
      if (element is ReportTableElement)
        const OfficeContextAction(
          id: 'addColumn',
          label: 'Add column',
          icon: Icons.view_column,
          separatorBefore: true,
        ),
      if (element is ReportTableElement && element.columns.length > 1)
        const OfficeContextAction(
          id: 'removeColumn',
          label: 'Remove last column',
          icon: Icons.remove,
        ),
      OfficeContextAction(
        id: 'delete',
        label: 'Delete',
        icon: Icons.delete_outline,
        shortcut: 'Del',
        enabled: any,
        danger: true,
        separatorBefore: true,
      ),
      if (hit.band case final ReportBandKind band)
        OfficeContextAction(
          id: 'removeBand',
          label: 'Remove ${band.xmlName} band',
          icon: Icons.remove_circle_outline,
          danger: true,
        ),
    ];
    _showMenu(hit.globalPosition, actions, (String action) {
      switch (action) {
        case 'editText':
          if (id != null) {
            _c.beginTextEdit(id);
          }
        case 'cut':
          _c.cutSelection();
        case 'copy':
          _c.copySelection();
        case 'paste':
          _c.paste();
        case 'duplicate':
          _c.duplicateSelection();
        case 'front':
          _c.bringToFront();
        case 'back':
          _c.sendToBack();
        case 'addColumn':
          if (id != null) {
            _c.addTableColumn(id);
          }
        case 'removeColumn':
          if (id != null && element is ReportTableElement) {
            _c.removeTableColumn(id, element.columns.length - 1);
          }
        case 'delete':
          _c.deleteSelection();
        case 'removeBand':
          final ReportBandKind? band = hit.band;
          if (band != null) {
            _c.removeBand(band);
          }
      }
    });
  }

  void _bandMenu(Offset at) {
    final List<OfficeContextAction> actions = <OfficeContextAction>[
      const OfficeContextAction.caption('Add band'),
      for (final ReportBandKind kind in ReportBandKind.values)
        OfficeContextAction(
          id: kind.name,
          label: kind.xmlName,
          icon: _c.template.band(kind) != null ? Icons.check : null,
        ),
    ];
    _showMenu(at, actions, (String id) {
      for (final ReportBandKind kind in ReportBandKind.values) {
        if (kind.name == id) {
          _c.addBand(kind);
        }
      }
    });
  }

  void _exportMenu(Offset at) {
    _showMenu(
      at,
      const <OfficeContextAction>[
        OfficeContextAction(
          id: 'pdf',
          label: 'PDF document',
          icon: Icons.picture_as_pdf,
        ),
        OfficeContextAction(
          id: 'xlsx',
          label: 'Excel workbook',
          icon: Icons.grid_on,
        ),
        OfficeContextAction(
          id: 'docx',
          label: 'Word document',
          icon: Icons.description,
        ),
      ],
      (String id) {
        for (final ReportExportFormat f in ReportExportFormat.values) {
          if (f.name == id) {
            _export(f);
          }
        }
      },
    );
  }

  static IconData _variableIcon(ReportVariableType t) => switch (t) {
    ReportVariableType.text => Icons.text_fields,
    ReportVariableType.number => Icons.pin_outlined,
    ReportVariableType.boolean => Icons.toggle_on_outlined,
    ReportVariableType.date => Icons.event,
    ReportVariableType.list => Icons.format_list_bulleted,
    ReportVariableType.expression => Icons.functions,
  };

  void _variablesMenu(Offset at) {
    final List<ReportVariable> vars = _c.template.variables;
    final bool editing = _c.editingId != null || _c.editingProperty != null;
    _showMenu(
      at,
      <OfficeContextAction>[
        OfficeContextAction.caption(
          vars.isEmpty
              ? 'No template variables yet'
              : (editing ? 'Insert at the caret' : 'Insert as a text box'),
        ),
        for (int i = 0; i < vars.length; i++)
          OfficeContextAction(
            id: 'insert.$i',
            label: vars[i].description.isEmpty
                ? '${vars[i].name}   ·  ${vars[i].type.name}'
                : '${vars[i].name}   ·  ${vars[i].description}',
            icon: _variableIcon(vars[i].type),
          ),
        const OfficeContextAction(
          id: 'new',
          label: 'New variable…',
          icon: Icons.add,
          separatorBefore: true,
        ),
        const OfficeContextAction(
          id: 'edit',
          label: 'Edit variables',
          icon: Icons.tune,
        ),
      ],
      (String id) {
        if (id.startsWith('insert.')) {
          final int i = int.parse(id.substring(7));
          if (i < vars.length) {
            _c.insertVariable(vars[i].name);
          }
          return;
        }
        if (id == 'new') {
          _c.select(null);
          _c.addVariable();
          _c.beginPropertyEdit('var.${_c.template.variables.length - 1}.name');
          return;
        }
        if (id == 'edit') {
          _c.select(null);
        }
      },
    );
  }

  static IconData _categoryIcon(ReportTemplateCategory c) => switch (c) {
    ReportTemplateCategory.sales => Icons.point_of_sale,
    ReportTemplateCategory.finance => Icons.account_balance,
    ReportTemplateCategory.inventory => Icons.inventory_2,
    ReportTemplateCategory.analytics => Icons.insights,
  };

  void _templatesMenu(Offset at) {
    final List<ReportTemplateInfo> list = widget.templates;
    _showMenu(
      at,
      <OfficeContextAction>[
        const OfficeContextAction.caption('Ready-made reports'),
        for (final ReportTemplateInfo info in list)
          OfficeContextAction(
            id: 'tpl.${info.id}',
            label: '${info.title}  ·  ${info.titleAr}',
            icon: _categoryIcon(info.category),
          ),
        const OfficeContextAction(
          id: 'blank',
          label: 'Blank report',
          icon: Icons.note_add_outlined,
          separatorBefore: true,
        ),
      ],
      (String id) {
        if (id == 'blank') {
          _c.mockData = null;
          _c.replaceTemplate(ReportTemplate());
          return;
        }
        for (final ReportTemplateInfo info in list) {
          if (id == 'tpl.${info.id}') {
            _c.loadTemplate(info);
            _c.fitWidth();
            setState(() => _message = 'Loaded "${info.title}"');
          }
        }
      },
    );
  }

  Future<void> _export(ReportExportFormat format) async {
    final void Function(ReportExportFormat, Uint8List)? sink = widget.onExport;
    if (sink == null) {
      return;
    }
    setState(() => _message = 'Exporting ${format.name.toUpperCase()}…');
    try {
      final Uint8List bytes = await _c.export(format);
      sink(format, bytes);
      if (mounted) {
        setState(
          () => _message =
              'Exported ${format.name.toUpperCase()} (${_size(bytes.length)})',
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _message = 'Export failed: $e');
      }
    }
  }

  static String _size(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _inspectorChoice(ReportInspectorChoice choice) {
    _activate();
    final ReportProperty p = choice.property;
    _showMenu(choice.globalPosition, <OfficeContextAction>[
      OfficeContextAction.caption(p.label),
      for (final String option in choice.choices)
        OfficeContextAction(
          id: option,
          label: option.isEmpty ? '(none)' : option,
          icon: option == p.value ? Icons.check : null,
          shortcut: choice.details[option],
        ),
    ], (String value) => _c.setProperty(p.key, value));
  }

  // ------------------------------------------------------------ toolbar

  static const Map<ReportDesignTool, (ReportToolbarIcon, String)> _tools =
      <ReportDesignTool, (ReportToolbarIcon, String)>{
        ReportDesignTool.select: (ReportToolbarIcon.select, 'Select (Esc)'),
        ReportDesignTool.text: (ReportToolbarIcon.text, 'Text box'),
        ReportDesignTool.image: (ReportToolbarIcon.image, 'Image'),
        ReportDesignTool.table: (ReportToolbarIcon.table, 'Repeating table'),
        ReportDesignTool.barcode: (ReportToolbarIcon.barcode, 'Barcode'),
        ReportDesignTool.qr: (ReportToolbarIcon.qr, 'QR code'),
        ReportDesignTool.line: (ReportToolbarIcon.line, 'Line'),
        ReportDesignTool.rectangle: (ReportToolbarIcon.rectangle, 'Rectangle'),
        ReportDesignTool.ellipse: (ReportToolbarIcon.ellipse, 'Ellipse'),
        ReportDesignTool.chart: (ReportToolbarIcon.chart, 'Chart'),
      };

  static const Map<ReportAlignAction, (ReportToolbarIcon, String)>
  _aligns = <ReportAlignAction, (ReportToolbarIcon, String)>{
    ReportAlignAction.left: (ReportToolbarIcon.alignLeft, 'Align left'),
    ReportAlignAction.centerX: (ReportToolbarIcon.alignCenter, 'Align centers'),
    ReportAlignAction.right: (ReportToolbarIcon.alignRight, 'Align right'),
    ReportAlignAction.top: (ReportToolbarIcon.alignTop, 'Align top'),
    ReportAlignAction.middle: (ReportToolbarIcon.alignMiddle, 'Align middles'),
    ReportAlignAction.bottom: (ReportToolbarIcon.alignBottom, 'Align bottom'),
    ReportAlignAction.distributeX: (
      ReportToolbarIcon.distributeX,
      'Distribute horizontally',
    ),
    ReportAlignAction.distributeY: (
      ReportToolbarIcon.distributeY,
      'Distribute vertically',
    ),
    ReportAlignAction.sameWidth: (ReportToolbarIcon.sameWidth, 'Same width'),
    ReportAlignAction.sameHeight: (ReportToolbarIcon.sameHeight, 'Same height'),
  };

  List<ReportToolbarItem> _toolbarItems() {
    final bool design = _c.mode == ReportDesignMode.design;
    final int n = _c.selectedElements.length;
    return <ReportToolbarItem>[
      if (widget.templates.isNotEmpty)
        const ReportToolbarItem(
          id: 'templates',
          icon: ReportToolbarIcon.templates,
          tooltip: 'Start from a ready-made report',
          label: 'Templates',
        ),
      ReportToolbarItem(
        id: 'variables',
        icon: ReportToolbarIcon.variables,
        tooltip: 'Insert or edit template variables',
        label: 'Variables',
        enabled: design,
      ),
      for (final MapEntry<ReportDesignTool, (ReportToolbarIcon, String)> t
          in _tools.entries)
        ReportToolbarItem(
          id: 'tool.${t.key.name}',
          icon: t.value.$1,
          tooltip: t.value.$2,
          enabled: design,
          active: design && _c.tool == t.key,
          separatorBefore: t.key == ReportDesignTool.select,
        ),
      ReportToolbarItem(
        id: 'undo',
        icon: ReportToolbarIcon.undo,
        tooltip: 'Undo (Ctrl+Z)',
        enabled: _c.canUndo,
        separatorBefore: true,
      ),
      ReportToolbarItem(
        id: 'redo',
        icon: ReportToolbarIcon.redo,
        tooltip: 'Redo (Ctrl+Y)',
        enabled: _c.canRedo,
      ),
      ReportToolbarItem(
        id: 'duplicate',
        icon: ReportToolbarIcon.duplicate,
        tooltip: 'Duplicate (Ctrl+D)',
        enabled: design && n > 0,
      ),
      ReportToolbarItem(
        id: 'delete',
        icon: ReportToolbarIcon.delete,
        tooltip: 'Delete (Del)',
        enabled: design && n > 0,
      ),
      for (final MapEntry<ReportAlignAction, (ReportToolbarIcon, String)> a
          in _aligns.entries)
        ReportToolbarItem(
          id: 'align.${a.key.name}',
          icon: a.value.$1,
          tooltip: a.value.$2,
          enabled: design && n >= _minSelection(a.key),
          separatorBefore:
              a.key == ReportAlignAction.left ||
              a.key == ReportAlignAction.distributeX,
        ),
      ReportToolbarItem(
        id: 'front',
        icon: ReportToolbarIcon.front,
        tooltip: 'Bring to front',
        enabled: design && n > 0,
        separatorBefore: true,
      ),
      ReportToolbarItem(
        id: 'back',
        icon: ReportToolbarIcon.back,
        tooltip: 'Send to back',
        enabled: design && n > 0,
      ),
      ReportToolbarItem(
        id: 'band',
        icon: ReportToolbarIcon.band,
        tooltip: 'Add band',
        enabled: design,
        separatorBefore: true,
      ),
      ReportToolbarItem(
        id: 'grid',
        icon: ReportToolbarIcon.grid,
        tooltip: 'Grid and snapping',
        enabled: design,
        active: design && _c.showGrid,
      ),
      const ReportToolbarItem(
        id: 'zoomOut',
        icon: ReportToolbarIcon.zoomOut,
        tooltip: 'Zoom out (Ctrl+-)',
        separatorBefore: true,
      ),
      const ReportToolbarItem(
        id: 'zoomIn',
        icon: ReportToolbarIcon.zoomIn,
        tooltip: 'Zoom in (Ctrl+=)',
      ),
      ReportToolbarItem(
        id: 'fit',
        icon: ReportToolbarIcon.fitWidth,
        tooltip: 'Fit page width',
        enabled: design,
      ),
      ReportToolbarItem(
        id: 'mode',
        icon: design ? ReportToolbarIcon.preview : ReportToolbarIcon.design,
        tooltip: design ? 'Live preview (F5)' : 'Back to design (F5)',
        label: design ? 'Preview' : 'Design',
        active: !design,
        separatorBefore: true,
      ),
      if (widget.onExport != null)
        const ReportToolbarItem(
          id: 'export',
          icon: ReportToolbarIcon.export,
          tooltip: 'Export with preview data',
          label: 'Export',
        ),
    ];
  }

  static int _minSelection(ReportAlignAction a) => switch (a) {
    ReportAlignAction.distributeX || ReportAlignAction.distributeY => 3,
    ReportAlignAction.sameWidth || ReportAlignAction.sameHeight => 2,
    _ => 1,
  };

  void _onToolbar(String id, Offset at) {
    _activate();
    if (id.startsWith('tool.')) {
      for (final ReportDesignTool t in ReportDesignTool.values) {
        if (id == 'tool.${t.name}') {
          _c.tool = t;
        }
      }
      return;
    }
    if (id.startsWith('align.')) {
      for (final ReportAlignAction a in ReportAlignAction.values) {
        if (id == 'align.${a.name}') {
          _c.align(a);
        }
      }
      return;
    }
    switch (id) {
      case 'undo':
        _c.undo();
      case 'redo':
        _c.redo();
      case 'duplicate':
        _c.duplicateSelection();
      case 'delete':
        _c.deleteSelection();
      case 'front':
        _c.bringToFront();
      case 'back':
        _c.sendToBack();
      case 'band':
        _bandMenu(at);
      case 'grid':
        _c.toggleGrid();
      case 'zoomOut':
        _c.zoom = _c.zoom / 1.2;
      case 'zoomIn':
        _c.zoom = _c.zoom * 1.2;
      case 'fit':
        _c.fitWidth();
      case 'mode':
        _c.togglePreview();
      case 'export':
        _exportMenu(at);
      case 'templates':
        _templatesMenu(at);
      case 'variables':
        _variablesMenu(at);
    }
  }

  String _status() {
    if (_message.isNotEmpty) {
      return _message;
    }
    final StringBuffer s = StringBuffer('${(_c.zoom * 100).round()}%');
    final List<ReportElement> sel = _c.selectedElements;
    if (sel.length == 1) {
      final ReportRect r = _c.physicalRect(sel.first);
      s.write(
        '  ·  ${sel.first.displayName}  '
        '${ReportUnits.trimNumber(r.left / _mm, decimals: 1)}, '
        '${ReportUnits.trimNumber(r.top / _mm, decimals: 1)} mm  '
        '${ReportUnits.trimNumber(r.width / _mm, decimals: 1)} × '
        '${ReportUnits.trimNumber(r.height / _mm, decimals: 1)} mm',
      );
    } else if (sel.length > 1) {
      s.write('  ·  ${sel.length} selected');
    }
    if (_c.hasHostData) {
      s.write('  ·  host data');
    }
    return s.toString();
  }

  // ------------------------------------------------------------ keyboard

  static bool get _ctrl =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  static bool get _shift => HardwareKeyboard.instance.isShiftPressed;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (_c.editingId != null) {
      return _editKey(
        _c.textEditor,
        event,
        multiline: true,
        commit: _c.commitTextEdit,
        cancel: _c.cancelTextEdit,
        tab: _c.commitTextEdit,
      );
    }
    if (_c.editingProperty != null) {
      final ReportProperty? p = _editingProperty();
      if (p != null &&
          p.isSteppable &&
          _c.completion == null &&
          (key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown)) {
        final InlineCellEditor ed = _c.propertyEditor;
        final String text = ed.formulaBar;
        final String next = _c.steppedValue(
          p,
          key == LogicalKeyboardKey.arrowUp ? 1 : -1,
          large: _shift,
          from: text,
        );
        ed.replaceRange(0, text.length, next);
        return KeyEventResult.handled;
      }
      return _editKey(
        _c.propertyEditor,
        event,
        multiline: p?.kind == ReportPropertyKind.multiline,
        commit: _c.commitPropertyEdit,
        cancel: _c.cancelPropertyEdit,
        tab: () {
          final RenderObject? ro = _inspectorKey.currentContext
              ?.findRenderObject();
          if (ro is RenderReportInspector) {
            ro.editNext(backwards: _shift);
          } else {
            _c.commitPropertyEdit();
          }
        },
      );
    }
    if (key == LogicalKeyboardKey.f5) {
      _c.togglePreview();
      return KeyEventResult.handled;
    }
    if (_ctrl &&
        (key == LogicalKeyboardKey.equal ||
            key == LogicalKeyboardKey.add ||
            key == LogicalKeyboardKey.numpadAdd)) {
      _c.zoom = _c.zoom * 1.2;
      return KeyEventResult.handled;
    }
    if (_ctrl &&
        (key == LogicalKeyboardKey.minus ||
            key == LogicalKeyboardKey.numpadSubtract)) {
      _c.zoom = _c.zoom / 1.2;
      return KeyEventResult.handled;
    }
    if (_ctrl && key == LogicalKeyboardKey.digit0) {
      _c.fitWidth();
      return KeyEventResult.handled;
    }
    if (_ctrl && key == LogicalKeyboardKey.keyZ) {
      _shift ? _c.redo() : _c.undo();
      return KeyEventResult.handled;
    }
    if (_ctrl && key == LogicalKeyboardKey.keyY) {
      _c.redo();
      return KeyEventResult.handled;
    }
    if (_c.mode != ReportDesignMode.design) {
      if (key == LogicalKeyboardKey.escape) {
        _c.togglePreview();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (_ctrl) {
      if (key == LogicalKeyboardKey.keyC) {
        _c.copySelection();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyX) {
        _c.cutSelection();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyV) {
        _c.paste();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyD) {
        _c.duplicateSelection();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyA) {
        _c.selectAll();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _c.deleteSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_c.tool != ReportDesignTool.select) {
        _c.tool = ReportDesignTool.select;
      } else {
        _c.select(null);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final ReportElement? e = _c.primary;
      if (e is ReportTextElement) {
        _c.beginTextEdit(e.id);
      }
      return KeyEventResult.handled;
    }
    final double step = _shift
        ? 0.1 * _mm
        : (_c.snapToGrid ? _c.gridSize : _mm);
    final (double, double)? delta = switch (key) {
      LogicalKeyboardKey.arrowLeft => (-step, 0),
      LogicalKeyboardKey.arrowRight => (step, 0),
      LogicalKeyboardKey.arrowUp => (0, -step),
      LogicalKeyboardKey.arrowDown => (0, step),
      _ => null,
    };
    if (delta != null) {
      if (_c.selection.isNotEmpty) {
        _c.nudge(delta.$1, delta.$2);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      final List<ReportElement> all = <ReportElement>[
        for (final (ReportBand, ReportElement) be in _c.template.allElements)
          be.$2,
      ];
      if (all.isNotEmpty) {
        final ReportElement? p = _c.primary;
        var i = p == null ? -1 : all.indexOf(p);
        i = _shift ? i - 1 : i + 1;
        _c.select(all[(i + all.length) % all.length].id);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  ReportProperty? _editingProperty() {
    final String? key = _c.editingProperty;
    for (final ReportProperty p in _c.properties) {
      if (p.key == key) {
        return p;
      }
    }
    return null;
  }

  /// Keys the IME does not deliver as text, plus keys the app-level
  /// [Shortcuts] would otherwise steal (arrows, Tab).
  KeyEventResult _editKey(
    InlineCellEditor ed,
    KeyEvent event, {
    required bool multiline,
    required VoidCallback commit,
    required VoidCallback cancel,
    required VoidCallback tab,
  }) {
    final LogicalKeyboardKey key = event.logicalKey;
    final bool shift = _shift;
    final String text = ed.formulaBar;
    if (_ctrl && key == LogicalKeyboardKey.space) {
      _c.triggerCompletion();
      return KeyEventResult.handled;
    }
    if (_c.completion != null) {
      final int? move = switch (key) {
        LogicalKeyboardKey.arrowDown => 1,
        LogicalKeyboardKey.arrowUp => -1,
        LogicalKeyboardKey.pageDown => ReportCompletionPopup.maxRows,
        LogicalKeyboardKey.pageUp => -ReportCompletionPopup.maxRows,
        _ => null,
      };
      if (move != null) {
        _c.moveCompletion(move);
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.tab) &&
          !_ctrl &&
          _c.acceptCompletion()) {
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _c.dismissCompletion();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.escape) {
      cancel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      tab();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_ctrl || !multiline) {
        commit();
      } else {
        ed.replaceRange(ed.selectionStart, ed.selectionEnd, '\n');
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      ed.deleteBackward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      ed.deleteForward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final int dir = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      if (!shift && ed.hasSelection) {
        ed.setCaret(dir < 0 ? ed.selectionStart : ed.selectionEnd);
      } else if (_ctrl) {
        ed.setCaret(_wordEdge(text, ed.caretIndex, dir), extend: shift);
      } else {
        ed.moveCaret(dir, extend: shift);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      ed.setCaret(
        _ctrl ? 0 : text.lastIndexOf('\n', ed.caretIndex - 1) + 1,
        extend: shift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      final int nl = text.indexOf('\n', ed.caretIndex);
      ed.setCaret(_ctrl || nl < 0 ? text.length : nl, extend: shift);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final bool up = key == LogicalKeyboardKey.arrowUp;
      final int caret = ed.caretIndex;
      final int start = caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
      final int column = caret - start;
      int target;
      if (up) {
        if (start == 0) {
          target = 0;
        } else {
          final int prevStart = text.lastIndexOf('\n', start - 2) + 1;
          target = (prevStart + column).clamp(prevStart, start - 1);
        }
      } else {
        final int nl = text.indexOf('\n', caret);
        if (nl < 0) {
          target = text.length;
        } else {
          final int nextEnd = text.indexOf('\n', nl + 1);
          final int end = nextEnd < 0 ? text.length : nextEnd;
          target = (nl + 1 + column).clamp(nl + 1, end);
        }
      }
      ed.setCaret(target, extend: shift);
      return KeyEventResult.handled;
    }
    if (_ctrl) {
      if (key == LogicalKeyboardKey.keyA) {
        ed.selectAll();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyC || key == LogicalKeyboardKey.keyX) {
        if (ed.hasSelection) {
          Clipboard.setData(
            ClipboardData(
              text: text.substring(ed.selectionStart, ed.selectionEnd),
            ),
          );
          if (key == LogicalKeyboardKey.keyX) {
            ed.deleteBackward();
          }
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyV) {
        Clipboard.getData(Clipboard.kTextPlain).then((ClipboardData? data) {
          final String? paste = data?.text;
          if (paste != null && ed.editing) {
            ed.replaceRange(
              ed.selectionStart,
              ed.selectionEnd,
              multiline ? paste : paste.replaceAll(RegExp(r'[\r\n]+'), ' '),
            );
          }
        });
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  static int _wordEdge(String text, int from, int dir) {
    var i = from;
    bool word(int at) {
      final int c = text.codeUnitAt(at);
      return c != 0x20 && c != 0x0A && c != 0x09;
    }

    if (dir < 0) {
      while (i > 0 && !word(i - 1)) {
        i--;
      }
      while (i > 0 && word(i - 1)) {
        i--;
      }
    } else {
      while (i < text.length && !word(i)) {
        i++;
      }
      while (i < text.length && word(i)) {
        i++;
      }
    }
    return i;
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final OfficeTheme theme = widget.theme;
    final bool design = _c.mode == ReportDesignMode.design;
    final Widget surface = design
        ? ReportDesignerCanvas(
            controller: _c,
            theme: theme,
            onContextMenu: _canvasMenu,
            onActivate: _activate,
          )
        : ReportPreviewSurface(
            document: _c.previewLayout,
            error: _c.previewError?.toString(),
            zoom: _c.zoom,
            theme: theme,
            onZoom: (double z) => _c.zoom = z,
            onPickElement: (String id) {
              _c.mode = ReportDesignMode.design;
              _c.select(id);
            },
          );
    return Focus(
      focusNode: _focus,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ReportToolbar(
            items: _toolbarItems(),
            status: _status(),
            theme: theme,
            onPressedAt: _onToolbar,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: surface),
                SizedBox(width: 1, child: ColoredBox(color: theme.pageBorder)),
                SizedBox(
                  width: widget.inspectorWidth,
                  child: ReportInspector(
                    key: _inspectorKey,
                    controller: _c,
                    theme: theme,
                    onChoose: _inspectorChoice,
                    onActivate: _activate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
