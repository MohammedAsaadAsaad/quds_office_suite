import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'src/device_fonts.dart';
import 'src/file_association.dart';
import 'src/recent_files.dart';
import 'src/report_studio_page.dart';
import 'src/studio_printing.dart';
import 'src/studio_settings.dart';
import 'src/studio_strings.dart';
import 'src/studio_templates.dart';
import 'src/studio_theme.dart';
import 'src/studio_window.dart';

/// Quds Report Studio. Pass a `.qrep` path to open it on start:
/// `quds_report_studio invoice.qrep`.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfficeHostFonts.ensureRegistered();
  await StudioWindow.bootstrap();
  final RecentFiles recent = RecentFiles();
  await recent.load();
  final StudioSettings settings = StudioSettings();
  await settings.load();
  unawaited(QrepFileAssociation.ensureRegistered(settings));
  final StudioTemplates templates = StudioTemplates(
    bundled: await ReportTemplateLibrary.bundled(),
  );
  await templates.load();
  final String? initial = args
      .where((String a) => !a.startsWith('-'))
      .firstOrNull;
  runApp(
    ReportStudioApp(
      recent: recent,
      settings: settings,
      templates: templates,
      initialPath: initial,
      deviceFonts: StudioDeviceFonts(),
    ),
  );
}

/// Root widget of the studio.
class ReportStudioApp extends StatelessWidget {
  ReportStudioApp({
    super.key,
    required this.recent,
    StudioSettings? settings,
    this.initialPath,
    this.deviceFonts,
    this.printer = StudioPrinting.system,
    this.templates,
  }) : settings = settings ?? StudioSettings(persist: false);

  final RecentFiles recent;
  final StudioSettings settings;
  final String? initialPath;

  /// Installed fonts for the Fonts page; none when null.
  final ReportDeviceFonts? deviceFonts;

  /// Shows the print dialog; tests pass a fake.
  final StudioPrinter printer;

  /// Bundled and user templates; none when null.
  final StudioTemplates? templates;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, Widget? child) {
        final String? code = settings.language.code;
        return MaterialApp(
          title: 'Quds Report Studio',
          debugShowCheckedModeBanner: false,
          theme: StudioTheme.data(Brightness.light),
          darkTheme: StudioTheme.data(Brightness.dark),
          themeMode: switch (settings.theme) {
            StudioThemeChoice.system => ThemeMode.system,
            StudioThemeChoice.light => ThemeMode.light,
            StudioThemeChoice.dark => ThemeMode.dark,
          },
          locale: code == null ? null : Locale(code),
          supportedLocales: StudioStrings.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: child,
        );
      },
      child: ListenableBuilder(
        listenable: recent,
        builder: (BuildContext context, Widget? child) => ReportStudioPage(
          recent: recent,
          settings: settings,
          initialPath: initialPath,
          deviceFonts: deviceFonts,
          printer: printer,
          templates: templates,
        ),
      ),
    );
  }
}
