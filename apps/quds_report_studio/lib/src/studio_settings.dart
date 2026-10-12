import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'recent_files.dart';

/// Light, dark, or the operating system's choice.
enum StudioThemeChoice { system, light, dark }

/// Interface language; [system] follows the operating system and falls back
/// to English.
enum StudioLanguage {
  system(null),
  english('en'),
  arabic('ar');

  const StudioLanguage(this.code);

  /// ISO 639-1 code, or null for the system language.
  final String? code;
}

/// User preferences persisted as `settings.json` next to `recent.json`.
class StudioSettings extends ChangeNotifier {
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

  /// Window theme.
  StudioThemeChoice theme = StudioThemeChoice.system;

  /// Interface language.
  StudioLanguage language = StudioLanguage.system;

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
        final Object? theme = decoded['theme'];
        for (final StudioThemeChoice t in StudioThemeChoice.values) {
          if (t.name == theme) {
            this.theme = t;
          }
        }
        final Object? language = decoded['language'];
        for (final StudioLanguage l in StudioLanguage.values) {
          if (l.name == language) {
            this.language = l;
          }
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

  /// Switches the window theme.
  Future<void> setTheme(StudioThemeChoice value) async {
    if (value == theme) {
      return;
    }
    theme = value;
    notifyListeners();
    await _save();
  }

  /// Switches the interface language.
  Future<void> setLanguage(StudioLanguage value) async {
    if (value == language) {
      return;
    }
    language = value;
    notifyListeners();
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
          'theme': theme.name,
          'language': language.name,
        }),
        flush: true,
      );
    } on FileSystemException {
      return;
    }
  }
}
