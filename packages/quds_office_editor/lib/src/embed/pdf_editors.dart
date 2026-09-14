import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quds_office_engine/pdf_file.dart';

import '../editor_pdf/render_pdf_canvas.dart';
import 'office_context_menu.dart';
import 'office_theme.dart';
import 'pdf_controller.dart';

/// Display-only PDF surface (`viewing` / `selecting`).
class QudsPdfViewer extends StatefulWidget {
  /// QudsPdfViewer API.
  const QudsPdfViewer({
    super.key,
    required this.controller,
    this.config,
    this.toolbarBuilder,
    this.statusBarBuilder,
    this.onFollowLink,
  });

  /// controller API.
  final PdfViewerController controller;

  /// config API.
  final OfficeSurfaceConfig? config;

  /// toolbarBuilder API.
  final Widget Function(BuildContext context, PdfViewerController controller)?
  toolbarBuilder;

  /// statusBarBuilder API.
  final Widget Function(BuildContext context, PdfViewerController controller)?
  statusBarBuilder;

  /// onFollowLink API.
  final void Function(PdfLinkAction action)? onFollowLink;

  @override
  State<QudsPdfViewer> createState() => _QudsPdfViewerState();
}

class _QudsPdfViewerState extends State<QudsPdfViewer> {
  OverlayEntry? _contextMenu;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_tick);
    if (widget.config != null) {
      widget.controller.config = widget.config!;
    }
  }

  @override
  void dispose() {
    OfficeContextMenu.dismiss(_contextMenu);
    widget.controller.removeListener(_tick);
    super.dispose();
  }

  void _showContext(PdfContextHit hit) {
    OfficeContextMenu.dismiss(_contextMenu);
    _contextMenu = OfficeContextMenu.show(
      context: context,
      globalPosition: hit.globalPosition,
      actions: OfficeContextMenu.pdf(controller: widget.controller, hit: hit),
      onSelect: (String id) {
        _contextMenu = null;
        _runContext(id, hit);
      },
    );
  }

  void _runContext(String id, PdfContextHit hit) {
    final PdfViewerController c = widget.controller;
    final Size view = c.viewport.extent;
    switch (id) {
      case 'copy':
        c.copyToClipboard();
      case 'selectAll':
        c.selectAll();
      case 'selectPage':
        c.selectPage(hit.pageIndex);
      case 'followLink':
        final PdfLinkAction? link = hit.link;
        if (link != null) {
          c.followLink(link);
          widget.onFollowLink?.call(link);
        }
      case 'zoomIn':
        c.zoomBy(1.1);
      case 'zoomOut':
        c.zoomBy(1 / 1.1);
      case 'actualSize':
        c.setScale(1);
      case 'fitWidth':
        c.fitWidth(view.width > 0 ? view.width : 720);
      case 'fitPage':
        c.fitPage(
          view.width > 0 ? view.width : 720,
          view.height > 0 ? view.height : 900,
        );
      case 'previousPage':
        c.goToPage(hit.pageIndex - 1);
      case 'nextPage':
        c.goToPage(hit.pageIndex + 1);
      case 'highlight':
      case 'strikethrough':
      case 'underline':
      case 'deleteAnnot':
      case 'rotatePage':
      case 'rotatePageLeft':
      case 'insertPage':
      case 'deletePage':
      case 'undo':
      case 'redo':
        _runEdit(id, hit);
    }
  }

  void _runEdit(String id, PdfContextHit hit) {
    final PdfViewerController viewer = widget.controller;
    if (viewer is! PdfEditorController || !viewer.config.allowsMutation) {
      return;
    }
    switch (id) {
      case 'highlight':
        viewer.markSelection('Highlight');
      case 'strikethrough':
        viewer.markSelection('StrikeOut', color: 0xCCE53935);
      case 'underline':
        viewer.markSelection('Underline', color: 0xCC1565C0);
      case 'deleteAnnot':
        final PdfAnnot? annot = hit.annot;
        if (annot != null) {
          viewer.deleteAnnot(hit.pageIndex, annot);
        }
      case 'rotatePage':
        viewer.rotatePageAt(hit.pageIndex, 90);
      case 'rotatePageLeft':
        viewer.rotatePageAt(hit.pageIndex, -90);
      case 'insertPage':
        viewer.insertBlankPage(hit.pageIndex + 1);
      case 'deletePage':
        viewer.deletePageAt(hit.pageIndex);
      case 'undo':
        viewer.undo();
      case 'redo':
        viewer.redo();
    }
  }

  void _tick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdfViewerController c = widget.controller;
    return Column(
      children: <Widget>[
        if (widget.toolbarBuilder != null) widget.toolbarBuilder!(context, c),
        Expanded(
          child: Focus(
            autofocus: true,
            onKeyEvent: (FocusNode node, KeyEvent event) {
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              final bool shortcut =
                  HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed;
              if (shortcut && event.logicalKey == LogicalKeyboardKey.keyC) {
                c.copyToClipboard();
                return KeyEventResult.handled;
              }
              if (shortcut && event.logicalKey == LogicalKeyboardKey.keyA) {
                if (HardwareKeyboard.instance.isShiftPressed) {
                  c.selectPage(c.pageIndex);
                } else {
                  c.selectAll();
                }
                return KeyEventResult.handled;
              }
              if (shortcut && event.logicalKey == LogicalKeyboardKey.keyZ) {
                final PdfEditorController? editor = c is PdfEditorController
                    ? c
                    : null;
                if (editor != null && editor.config.allowsMutation) {
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    editor.redo();
                  } else {
                    editor.undo();
                  }
                  return KeyEventResult.handled;
                }
              }
              if (shortcut && event.logicalKey == LogicalKeyboardKey.keyY) {
                final PdfEditorController? editor = c is PdfEditorController
                    ? c
                    : null;
                if (editor != null && editor.config.allowsMutation) {
                  editor.redo();
                  return KeyEventResult.handled;
                }
              }
              if (shortcut &&
                  (event.logicalKey == LogicalKeyboardKey.equal ||
                      event.logicalKey == LogicalKeyboardKey.numpadAdd ||
                      event.logicalKey == LogicalKeyboardKey.add)) {
                c.zoomBy(1.1);
                return KeyEventResult.handled;
              }
              if (shortcut &&
                  (event.logicalKey == LogicalKeyboardKey.minus ||
                      event.logicalKey == LogicalKeyboardKey.numpadSubtract)) {
                c.zoomBy(1 / 1.1);
                return KeyEventResult.handled;
              }
              if (shortcut && event.logicalKey == LogicalKeyboardKey.digit0) {
                c.setScale(1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                c.setSelection(null);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: PdfCanvasView(
              lists: c.lists,
              viewport: c.viewport,
              scale: c.viewport.scale,
              config: c.config,
              selection: c.selection,
              findMarks: c.findMarks,
              findIndex: c.findIndex,
              annots: <List<PdfAnnot>>[
                if (c.file != null)
                  for (int i = 0; i < c.pageCount; i++) c.file!.annotsOn(i),
              ],
              onChanged: c.viewportChanged,
              onZoomBy: (double factor, Offset focal, {bool animate = true}) {
                c.zoomBy(factor, focal: focal, animate: animate);
              },
              onFollowLink: (PdfLinkAction action) {
                c.followLink(action);
                widget.onFollowLink?.call(action);
              },
              onSelectText: c.setSelection,
              onContextMenu: _showContext,
            ),
          ),
        ),
        if (widget.statusBarBuilder != null)
          widget.statusBarBuilder!(context, c),
      ],
    );
  }
}

/// Annotate / form-fill PDF surface.
class QudsPdfEditor extends StatelessWidget {
  /// QudsPdfEditor API.
  const QudsPdfEditor({
    super.key,
    required this.controller,
    this.config,
    this.toolbarBuilder,
    this.statusBarBuilder,
    this.onFollowLink,
  });

  /// controller API.
  final PdfEditorController controller;

  /// config API.
  final OfficeSurfaceConfig? config;

  /// toolbarBuilder API.
  final Widget Function(BuildContext context, PdfEditorController controller)?
  toolbarBuilder;

  /// statusBarBuilder API.
  final Widget Function(BuildContext context, PdfEditorController controller)?
  statusBarBuilder;

  /// onFollowLink API.
  final void Function(PdfLinkAction action)? onFollowLink;

  @override
  Widget build(BuildContext context) {
    return QudsPdfViewer(
      controller: controller,
      config: config ?? controller.config,
      toolbarBuilder: toolbarBuilder == null
          ? null
          : (BuildContext ctx, PdfViewerController _) =>
                toolbarBuilder!(ctx, controller),
      statusBarBuilder: statusBarBuilder == null
          ? null
          : (BuildContext ctx, PdfViewerController _) =>
                statusBarBuilder!(ctx, controller),
      onFollowLink: onFollowLink,
    );
  }
}
