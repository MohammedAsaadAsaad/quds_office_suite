import 'package:flutter/widgets.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

export 'studio_sample_pdf.dart';

/// Page canvas for the studio PDF app (chrome stays in [SuiteWorkspace]).
class StudioPdfSurface extends StatelessWidget {
  const StudioPdfSurface({
    super.key,
    required this.controller,
    required this.config,
  });

  final PdfEditorController controller;
  final OfficeSurfaceConfig config;

  @override
  Widget build(BuildContext context) {
    return QudsPdfEditor(controller: controller, config: config);
  }
}
