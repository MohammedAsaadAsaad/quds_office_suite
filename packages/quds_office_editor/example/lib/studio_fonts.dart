import 'package:quds_office_editor/quds_office_editor.dart';

import 'studio_files.dart';
import 'studio_pdf_faces.dart';

/// Studio extras on top of [OfficeHostFonts].
///
/// Core Liberation / Noto faces ship inside `quds_office_editor`. Cairo and
/// Tajawal ship with this example so PDF samples embed Arabic-capable faces.
abstract final class StudioFonts {
  static Future<void> register() async {
    await OfficeHostFonts.ensureRegistered();
    await StudioFiles.installBundledAssets();
    await StudioPdfFaces.ensureLoaded();
    await StudioPdfFaces.registerFlutterFaces();
  }
}
