import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'studio_settings.dart';

/// Registers Quds Report Studio as the per-user handler of `.qrep` files.
///
/// Linux: a shared-mime-info type, a desktop entry and icons under
/// `$XDG_DATA_HOME`, then `xdg-mime default`. Windows: `HKCU\Software\Classes`
/// keys imported with `reg import`, then `SHChangeNotify`. Installers
/// register the same names, so their uninstallers remove them again.
abstract final class QrepFileAssociation {
  /// MIME type of `.qrep` packages.
  static const String mimeType = 'application/vnd.quds.qrep+zip';

  /// Desktop entry id; matches the GTK application id (Wayland `app_id`).
  static const String desktopId = 'com.quds.quds_report_studio.desktop';

  /// Icon theme name of the app.
  static const String appIcon = 'quds-report-studio';

  /// Icon theme name of `.qrep` documents.
  static const String fileIcon = 'application-vnd.quds.qrep+zip';

  /// Windows ProgID.
  static const String progId = 'QudsReportStudio.qrep';

  /// Install folder of the Linux `.deb` package.
  static const String debInstallDir = '/opt/quds-report-studio';

  static bool get _supported =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows);

  /// Associates `.qrep` files on the first run and whenever the app runs from
  /// a new location; returns whether it registered.
  static Future<bool> ensureRegistered(StudioSettings settings) async {
    if (!_supported) {
      return false;
    }
    final String exe = Platform.resolvedExecutable;
    if (settings.associatedExecutable == exe) {
      return false;
    }
    final bool done = await register(exe);
    if (done) {
      await settings.setAssociatedExecutable(exe);
    }
    return done;
  }

  /// Makes [executable] the handler of `.qrep` files for the current user.
  static Future<bool> register(String executable) async {
    try {
      if (Platform.isLinux) {
        return await _registerLinux(executable);
      }
      if (Platform.isWindows) {
        return await _registerWindows(executable);
      }
    } on FileSystemException {
      return false;
    } on ProcessException {
      return false;
    }
    return false;
  }

  /// shared-mime-info package declaring `*.qrep`.
  static String mimeXml() =>
      '''
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="$mimeType">
    <comment>Quds report</comment>
    <comment xml:lang="ar">تقرير قدس</comment>
    <sub-class-of type="application/zip"/>
    <icon name="$fileIcon"/>
    <glob pattern="*.qrep" weight="80"/>
  </mime-type>
</mime-info>
''';

  /// Desktop entry that opens files with [executable].
  static String desktopEntry(String executable) {
    final String quoted = executable
        .replaceAll(r'\', r'\\\\')
        .replaceAll('"', r'\\"')
        .replaceAll(r'$', r'\\$')
        .replaceAll('`', r'\\`')
        .replaceAll('%', '%%');
    return '''
[Desktop Entry]
Type=Application
Version=1.0
Name=Quds Report Studio
Name[ar]=استوديو تقارير القدس
GenericName=Report designer
Comment=Design, preview and export .qrep band reports
Comment[ar]=صمّم تقارير ‎.qrep‎ واستعرضها وصدّرها
Exec="$quoted" %f
Icon=$appIcon
Terminal=false
Categories=Office;
MimeType=$mimeType;
StartupWMClass=com.quds.quds_report_studio
Keywords=report;qrep;pdf;invoice;designer;
''';
  }

  static Future<bool> _registerLinux(String exe) async {
    final Map<String, String> env = Platform.environment;
    final bool packaged =
        exe.startsWith('$debInstallDir/') &&
        File('/usr/share/applications/$desktopId').existsSync();
    if (!packaged) {
      final String? home = env['HOME'];
      final String? xdg = env['XDG_DATA_HOME'];
      final String data = xdg != null && xdg.isNotEmpty
          ? xdg
          : home == null
          ? ''
          : '$home/.local/share';
      if (data.isEmpty) {
        return false;
      }
      await _write('$data/mime/packages/quds-report-studio.xml', mimeXml());
      await _write('$data/applications/$desktopId', desktopEntry(exe));
      final String icons = '${File(exe).parent.path}/data/icons';
      await _copy('$icons/$appIcon.png', '$data/icons/hicolor/256x256/apps');
      await _copy(
        '$icons/$fileIcon.png',
        '$data/icons/hicolor/256x256/mimetypes',
      );
      await _run('update-mime-database', <String>['$data/mime']);
      await _run('update-desktop-database', <String>['$data/applications']);
      await _run('gtk-update-icon-cache', <String>[
        '-f',
        '-t',
        '$data/icons/hicolor',
      ]);
    }
    final String? home = env['HOME'];
    final String? cfg = env['XDG_CONFIG_HOME'];
    final String config = cfg != null && cfg.isNotEmpty
        ? cfg
        : home == null
        ? ''
        : '$home/.config';
    if (config.isNotEmpty) {
      final File list = File('$config/mimeapps.list');
      if (!await list.exists()) {
        await _write(list.path, '');
      }
    }
    return _run('xdg-mime', <String>['default', desktopId, mimeType]);
  }

  /// `.reg` script (UTF-16 text) registering [executable] for `.qrep`.
  static String registryScript(String executable) {
    String str(String v) =>
        '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    const String classes = r'HKEY_CURRENT_USER\Software\Classes';
    return '''
Windows Registry Editor Version 5.00

[$classes\\.qrep]
@=${str(progId)}
"Content Type"=${str(mimeType)}

[$classes\\.qrep\\OpenWithProgids]
${str(progId)}=hex(0):

[$classes\\$progId]
@="Quds report"

[$classes\\$progId\\DefaultIcon]
@=${str('"$executable",1')}

[$classes\\$progId\\shell\\open\\command]
@=${str('"$executable" "%1"')}

'''
        .replaceAll('\n', '\r\n');
  }

  static Future<bool> _registerWindows(String exe) async {
    final Directory tmp = await Directory.systemTemp.createTemp('qrep_assoc');
    try {
      final File reg = File('${tmp.path}\\qrep.reg');
      final String text = registryScript(exe);
      final Uint8List bytes = Uint8List(2 + text.length * 2);
      bytes[0] = 0xFF;
      bytes[1] = 0xFE;
      for (int i = 0; i < text.length; i++) {
        final int unit = text.codeUnitAt(i);
        bytes[2 + i * 2] = unit & 0xFF;
        bytes[3 + i * 2] = unit >> 8;
      }
      await reg.writeAsBytes(bytes, flush: true);
      final bool ok = await _run('reg', <String>['import', reg.path]);
      if (ok) {
        _notifyShell();
      }
      return ok;
    } finally {
      await tmp.delete(recursive: true);
    }
  }

  /// `SHChangeNotify(SHCNE_ASSOCCHANGED)` so Explorer picks up the icon.
  static void _notifyShell() {
    try {
      final DynamicLibrary shell = DynamicLibrary.open('shell32.dll');
      final void Function(int, int, Pointer<Void>, Pointer<Void>) notify = shell
          .lookupFunction<
            Void Function(Int32, Uint32, Pointer<Void>, Pointer<Void>),
            void Function(int, int, Pointer<Void>, Pointer<Void>)
          >('SHChangeNotify');
      notify(0x08000000, 0, nullptr, nullptr);
    } on ArgumentError {
      return;
    }
  }

  static Future<void> _write(String path, String text) async {
    final File f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(text, encoding: utf8, flush: true);
  }

  static Future<void> _copy(String from, String toDir) async {
    final File src = File(from);
    if (!await src.exists()) {
      return;
    }
    await Directory(toDir).create(recursive: true);
    await src.copy('$toDir/${src.uri.pathSegments.last}');
  }

  static Future<bool> _run(String cmd, List<String> args) async {
    try {
      final ProcessResult r = await Process.run(cmd, args);
      return r.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
