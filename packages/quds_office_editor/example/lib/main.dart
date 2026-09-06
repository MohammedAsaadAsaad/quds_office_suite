import 'package:flutter/material.dart';

import 'sample_library.dart';
import 'studio_fonts.dart';
import 'studio_window.dart';
import 'suite_workspace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StudioWindow.bootstrap();
  await StudioFonts.register();
  await SampleLibrary.preload();
  runApp(const QudsOfficeStudioApp());
}

class QudsOfficeStudioApp extends StatelessWidget {
  const QudsOfficeStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quds Office Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Noto Naskh Arabic',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B579A)),
      ),
      builder: (BuildContext context, Widget? child) {
        return StudioWindow.wrap(child ?? const SizedBox.shrink());
      },
      home: const SuiteWorkspace(),
    );
  }
}
