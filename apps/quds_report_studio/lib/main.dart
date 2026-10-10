import 'package:flutter/material.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'src/recent_files.dart';
import 'src/report_studio_page.dart';
import 'src/studio_window.dart';

/// Quds Report Studio. Pass a `.qrep` path to open it on start:
/// `quds_report_studio invoice.qrep`.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfficeHostFonts.ensureRegistered();
  await StudioWindow.bootstrap();
  final RecentFiles recent = RecentFiles();
  await recent.load();
  final String? initial = args
      .where((String a) => !a.startsWith('-'))
      .firstOrNull;
  runApp(ReportStudioApp(recent: recent, initialPath: initial));
}

/// Root widget of the studio.
class ReportStudioApp extends StatelessWidget {
  const ReportStudioApp({super.key, required this.recent, this.initialPath});

  final RecentFiles recent;
  final String? initialPath;

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
        builder: (BuildContext context, Widget? child) =>
            ReportStudioPage(recent: recent, initialPath: initialPath),
      ),
    );
  }
}
