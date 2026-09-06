import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// Registers installed system faces under Office family names so Flutter
/// actually paints Calibri, Noto Naskh, Times, etc. instead of Roboto.
abstract final class StudioFonts {
  static final Set<String> _loaded = <String>{};

  static const Map<String, List<String>> _regularFiles =
      <String, List<String>>{
    'noto naskh arabic': <String>['NotoNaskhArabic-Regular.ttf'],
    'noto sans arabic': <String>['NotoSansArabic-Regular.ttf'],
    'tajawal': <String>['Tajawal-Regular.ttf', 'NotoSansArabic-Regular.ttf'],
    'calibri': <String>['Carlito-Regular.ttf', 'LiberationSans-Regular.ttf'],
    'arial': <String>['LiberationSans-Regular.ttf'],
    'liberation sans': <String>['LiberationSans-Regular.ttf'],
    'times new roman': <String>['LiberationSerif-Regular.ttf'],
    'georgia': <String>['DejaVuSerif.ttf', 'LiberationSerif-Regular.ttf'],
    'liberation serif': <String>['LiberationSerif-Regular.ttf'],
    'courier new': <String>['LiberationMono-Regular.ttf', 'DejaVuSansMono.ttf'],
    'tahoma': <String>['DejaVuSans.ttf'],
  };

  static List<String> get _dirs {
    final String home = Platform.environment['HOME'] ?? '';
    return <String>[
      '/usr/share/fonts/truetype/noto',
      '/usr/share/fonts/opentype/noto',
      '/usr/share/fonts/truetype/liberation',
      '/usr/share/fonts/truetype/liberation2',
      '/usr/share/fonts/truetype/crosextra',
      '/usr/share/fonts/truetype/dejavu',
      '/usr/share/fonts/truetype/freefont',
      if (home.isNotEmpty) '$home/.local/share/fonts',
      '/usr/share/fonts/truetype',
    ];
  }

  static Future<void> register() async {
    if (kIsWeb) {
      return;
    }
    for (final String family in OfficeTypeface.families) {
      await _load(family);
    }
  }

  static Future<void> _load(String family) async {
    if (_loaded.contains(family)) {
      return;
    }
    final List<File> files = _filesFor(family);
    if (files.isEmpty) {
      return;
    }
    final FontLoader loader = FontLoader(family);
    for (final File file in files) {
      final Uint8List bytes = await file.readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    _loaded.add(family);
  }

  static List<File> _filesFor(String family) {
    final List<String> names = _regularFiles[family.toLowerCase()] ??
        <String>['${family.replaceAll(' ', '')}-Regular.ttf'];
    for (final String name in names) {
      for (final String dir in _dirs) {
        final File regular = File('$dir/$name');
        if (!regular.existsSync()) {
          continue;
        }
        return <File>[
          regular,
          ..._variants(regular),
        ];
      }
    }
    return const <File>[];
  }

  static List<File> _variants(File regular) {
    final String path = regular.path;
    final List<String> replacements = <String>[
      path.replaceFirst('-Regular.', '-Bold.'),
      path.replaceFirst('-Regular.', '-Italic.'),
      path.replaceFirst('-Regular.', '-BoldItalic.'),
      path.replaceFirst('.ttf', '-Bold.ttf'),
      path.replaceFirst('.ttf', '-Italic.ttf'),
      path.replaceFirst('.ttf', '-BoldItalic.ttf'),
    ];
    final List<File> found = <File>[];
    final Set<String> seen = <String>{path};
    for (final String candidate in replacements) {
      if (seen.add(candidate) && File(candidate).existsSync()) {
        found.add(File(candidate));
      }
    }
    return found;
  }
}
