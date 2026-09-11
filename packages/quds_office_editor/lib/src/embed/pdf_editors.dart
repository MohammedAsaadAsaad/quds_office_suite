import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quds_office_engine/pdf_file.dart';

import '../editor_pdf/render_pdf_canvas.dart';
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
    widget.controller.removeListener(_tick);
    super.dispose();
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
              findHits: c.findHits,
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
            ),
          ),
        ),
        if (widget.statusBarBuilder != null) widget.statusBarBuilder!(context, c),
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
