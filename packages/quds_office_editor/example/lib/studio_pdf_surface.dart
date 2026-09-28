import 'package:flutter/widgets.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'studio_pdf_viewer_demo.dart';

export 'studio_sample_pdf.dart';
export 'studio_pdf_viewer_demo.dart';

/// Page canvas for the studio PDF app (chrome stays in [SuiteWorkspace]).
class StudioPdfSurface extends StatelessWidget {
  /// StudioPdfSurface API.
  const StudioPdfSurface({
    super.key,
    required this.controller,
    required this.config,
    this.options = const PdfViewerOptions(),
    this.events,
    this.onFollowLink,
  });

  /// Editing controller.
  final PdfEditorController controller;

  /// Surface theme / interaction mode.
  final OfficeSurfaceConfig config;

  /// Viewer options (night, swipe axis, snap, …).
  final PdfViewerOptions options;

  /// Optional event sink for the status bar / toasts.
  final StudioPdfViewerEvents? events;

  /// Extra host hook for links (alongside [events]).
  final void Function(PdfLinkAction action)? onFollowLink;

  @override
  Widget build(BuildContext context) {
    final StudioPdfViewerEvents? sink = events;
    return QudsPdfEditor(
      controller: controller,
      config: config,
      options: options,
      onViewCreated: sink?.viewCreated,
      onLoadComplete: sink?.loadComplete,
      onPageChanged: sink?.pageChanged,
      onRender: sink?.render,
      onError: sink?.error,
      onPageError: sink?.pageError,
      onLinkHandle: (PdfLinkAction action) {
        sink?.link(action);
        onFollowLink?.call(action);
      },
      onFollowLink: onFollowLink,
      onDraw: sink?.draw,
    );
  }
}
