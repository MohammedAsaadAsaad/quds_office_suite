import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Most-recently-used `.qrep` paths, persisted as JSON in the user's
/// config directory (`~/.config/quds_report_studio/recent.json` on Linux).
class RecentFiles extends ChangeNotifier {
  RecentFiles({File? store}) : _store = store ?? _defaultStore();

  /// Upper bound of remembered paths.
  static const int limit = 10;

  final File? _store;
  final List<String> _paths = <String>[];

  /// Paths, newest first.
  List<String> get paths => List<String>.unmodifiable(_paths);

  static File? _defaultStore() {
    if (kIsWeb) {
      return null;
    }
    final Map<String, String> env = Platform.environment;
    final String? base = Platform.isWindows
        ? env['APPDATA']
        : Platform.isMacOS
        ? (env['HOME'] == null
              ? null
              : '${env['HOME']}/Library/Application Support')
        : (env['XDG_CONFIG_HOME'] ??
              (env['HOME'] == null ? null : '${env['HOME']}/.config'));
    if (base == null || base.isEmpty) {
      return null;
    }
    final String sep = Platform.pathSeparator;
    return File('$base${sep}quds_report_studio${sep}recent.json');
  }

  /// Reads the stored list; missing or corrupt files give an empty list.
  Future<void> load() async {
    final File? store = _store;
    if (store == null || !await store.exists()) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(await store.readAsString());
      if (decoded is List<Object?>) {
        _paths
          ..clear()
          ..addAll(decoded.whereType<String>().take(limit));
        notifyListeners();
      }
    } on FormatException {
      return;
    } on FileSystemException {
      return;
    }
  }

  /// Moves [path] to the top.
  Future<void> add(String path) async {
    _paths
      ..remove(path)
      ..insert(0, path);
    if (_paths.length > limit) {
      _paths.removeRange(limit, _paths.length);
    }
    notifyListeners();
    await _save();
  }

  /// Forgets [path] (for example after it failed to open).
  Future<void> remove(String path) async {
    if (_paths.remove(path)) {
      notifyListeners();
      await _save();
    }
  }

  /// Forgets everything.
  Future<void> clear() async {
    if (_paths.isEmpty) {
      return;
    }
    _paths.clear();
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
      await store.writeAsString(jsonEncode(_paths), flush: true);
    } on FileSystemException {
      return;
    }
  }
}
