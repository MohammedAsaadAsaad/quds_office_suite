import 'dart:convert';
import 'dart:io';

import 'recent_files.dart';

/// User preferences persisted as `settings.json` next to `recent.json`.
class StudioSettings {
  StudioSettings({File? store, bool persist = true})
    : _store = persist
          ? store ?? RecentFiles.configFile('settings.json')
          : null;

  /// Inspector width used until the user drags the splitter.
  static const double defaultInspectorWidth = 320;

  final File? _store;

  /// Width of the property inspector, logical pixels.
  double inspectorWidth = defaultInspectorWidth;

  /// Executable that `.qrep` files were last associated with, or null.
  String? associatedExecutable;

  /// Reads the stored settings; missing or corrupt files keep the defaults.
  Future<void> load() async {
    final File? store = _store;
    if (store == null || !await store.exists()) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(await store.readAsString());
      if (decoded is Map<String, Object?>) {
        final Object? width = decoded['inspectorWidth'];
        if (width is num && width.isFinite && width > 0) {
          inspectorWidth = width.toDouble();
        }
        final Object? exe = decoded['associatedExecutable'];
        if (exe is String && exe.isNotEmpty) {
          associatedExecutable = exe;
        }
      }
    } on FormatException {
      return;
    } on FileSystemException {
      return;
    }
  }

  /// Remembers [width] as the inspector width.
  Future<void> setInspectorWidth(double width) async {
    inspectorWidth = width;
    await _save();
  }

  /// Remembers that `.qrep` files open with [executable].
  Future<void> setAssociatedExecutable(String executable) async {
    associatedExecutable = executable;
    await _save();
  }

  Future<void> _save() async {
    final File? store = _store;
    if (store == null) {
      return;
    }
    try {
      await store.parent.create(recursive: true);
      await store.writeAsString(
        jsonEncode(<String, Object?>{
          'inspectorWidth': inspectorWidth.roundToDouble(),
          'associatedExecutable': ?associatedExecutable,
        }),
        flush: true,
      );
    } on FileSystemException {
      return;
    }
  }
}
