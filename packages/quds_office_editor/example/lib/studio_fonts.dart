import 'package:flutter/foundation.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// Studio extras on top of [OfficeHostFonts] (system-only faces like Tajawal).
///
/// Core Liberation / Noto faces ship inside `quds_office_editor` — do not rely
/// on `/usr/share/fonts` for those.
abstract final class StudioFonts {
  static Future<void> register() async {
    await OfficeHostFonts.ensureRegistered();
    if (kIsWeb) {
      return;
    }
  }
}
