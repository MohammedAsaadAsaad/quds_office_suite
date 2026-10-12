import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'src/device_fonts.dart';
import 'src/file_association.dart';
import 'src/recent_files.dart';
import 'src/report_studio_page.dart';
import 'src/studio_settings.dart';
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
  final String? initial = args
      .where((String a) => !a.startsWith('-'))
      .firstOrNull;
  runApp(
    ReportStudioApp(
      recent: recent,
      settings: settings,
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
  }) : settings = settings ?? StudioSettings(persist: false);

  final RecentFiles recent;
  final StudioSettings settings;
  final String? initialPath;

  /// Installed fonts for the Fonts page; none when null.
  final ReportDeviceFonts? deviceFonts;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quds Report Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Liberation Sans',
        fontFamilyFallback: const <String>['Noto Naskh Arabic'],
        colorScheme: ColorScheme.fromSeed(seedColor: StudioColors.chromeLight),
        menuTheme: const MenuThemeData(
          style: MenuStyle(visualDensity: VisualDensity.compact),
        ),
        tooltipTheme: const TooltipThemeData(
          textStyle: TextStyle(fontSize: 11.5, color: Colors.white),
        ),
      ),
      home: ListenableBuilder(
        listenable: recent,
        builder: (BuildContext context, Widget? child) => ReportStudioPage(
          recent: recent,
          settings: settings,
          initialPath: initialPath,
          deviceFonts: deviceFonts,
        ),
      ),
    );
  }
}
