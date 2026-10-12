import 'package:flutter/material.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

/// Colors of the studio window around the designer, per brightness.
@immutable
class StudioPalette {
  const StudioPalette({
    required this.titleBar,
    required this.titleInk,
    required this.titleHover,
    required this.status,
    required this.statusBorder,
    required this.statusInk,
    required this.statusMuted,
    required this.ok,
    required this.warning,
    required this.error,
    required this.office,
  });

  /// Title bar fill.
  final Color titleBar;

  /// Text and icons on the title bar.
  final Color titleInk;

  /// Hover fill of title bar buttons.
  final Color titleHover;

  /// Status bar fill.
  final Color status;

  /// Line above the status bar.
  final Color statusBorder;

  /// Status bar text.
  final Color statusInk;

  /// Secondary status bar text.
  final Color statusMuted;

  /// Healthy / saved.
  final Color ok;

  /// Unsaved / warnings.
  final Color warning;

  /// Errors.
  final Color error;

  /// Designer surfaces (toolbar, canvas, inspector, explorer).
  final OfficeTheme office;

  /// Light studio.
  static const StudioPalette light = StudioPalette(
    titleBar: Color(0xFF1F3B63),
    titleInk: Color(0xFFFFFFFF),
    titleHover: Color(0x1FFFFFFF),
    status: Color(0xFFF3F5F8),
    statusBorder: Color(0xFFD9DEE5),
    statusInk: Color(0xFF374151),
    statusMuted: Color(0xFF6B7280),
    ok: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    error: Color(0xFFB3261E),
    office: OfficeTheme(
      canvasBackground: Color(0xFFD9DDE3),
      pageBackground: Color(0xFFFFFFFF),
      pageBorder: Color(0xFFC3C9D1),
      caret: Color(0xC8000000),
      selectionFill: Color(0x332B6CD4),
      selectionStroke: Color(0xFF2B6CD4),
      gridLine: Color(0xFFD3D8DF),
      frozenFill: Color(0xFFE8EBEF),
      headerFill: Color(0xFFF1F3F6),
      headerText: Color(0xFF3F4752),
      chromeFill: Color(0xFFF8F9FB),
      chromeText: Color(0xFF1F2328),
      handleStroke: Color(0xFF2B6CD4),
      handleFill: Color(0xFFFFFFFF),
      snapGuide: Color(0xFFFF4FA0),
      slideBackground: Color(0xFFFFFFFF),
      focusRing: Color(0xFF2B6CD4),
    ),
  );

  /// Dark studio; report paper stays white so the design reads as printed.
  static const StudioPalette dark = StudioPalette(
    titleBar: Color(0xFF14161A),
    titleInk: Color(0xFFE6E8EB),
    titleHover: Color(0x1AFFFFFF),
    status: Color(0xFF1B1E23),
    statusBorder: Color(0xFF2F343B),
    statusInk: Color(0xFFD1D5DB),
    statusMuted: Color(0xFF9AA1AB),
    ok: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    office: OfficeTheme(
      canvasBackground: Color(0xFF111316),
      pageBackground: Color(0xFFFFFFFF),
      pageBorder: Color(0xFF3A3F47),
      caret: Color(0xC8000000),
      selectionFill: Color(0x554C9AFF),
      selectionStroke: Color(0xFF4C9AFF),
      gridLine: Color(0xFF353A42),
      frozenFill: Color(0xFF2A2E35),
      headerFill: Color(0xFF1E2126),
      headerText: Color(0xFFD7DBE0),
      chromeFill: Color(0xFF24272D),
      chromeText: Color(0xFFE6E8EB),
      handleStroke: Color(0xFF4C9AFF),
      handleFill: Color(0xFFFFFFFF),
      snapGuide: Color(0xFFFF6FB5),
      slideBackground: Color(0xFFFFFFFF),
      focusRing: Color(0xFF4C9AFF),
    ),
  );

  /// Palette for [brightness].
  static StudioPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Material themes of the studio.
abstract final class StudioTheme {
  /// Theme for [brightness].
  static ThemeData data(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B5797),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Liberation Sans',
      fontFamilyFallback: const <String>['Noto Naskh Arabic'],
      scaffoldBackgroundColor: StudioPalette.of(brightness).office.chromeFill,
      menuTheme: MenuThemeData(
        style: MenuStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStatePropertyAll<Color>(
            dark ? const Color(0xFF2A2E35) : const Color(0xFFFFFFFF),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: TextStyle(
          fontSize: 11.5,
          color: dark ? const Color(0xFF1F2328) : Colors.white,
        ),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFE8EAED) : const Color(0xF2202428),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF3A3F47) : const Color(0xFFE2E6EB),
      ),
    );
  }
}
