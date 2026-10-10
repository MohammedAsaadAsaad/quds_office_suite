/// Public entry point: `.qrep` template → PDF / XLSX / DOCX.
library;

import 'dart:typed_data';

import '../pdf/pdf_save_options.dart';
import 'report_docx_writer.dart';
import 'report_expression.dart';
import 'report_expression_engine.dart';
import 'report_fonts.dart';
import 'report_format.dart';
import 'report_generator.dart';
import 'report_layout.dart';
import 'report_pdf_writer.dart';
import 'report_template.dart';
import 'report_value.dart';
import 'report_xlsx_writer.dart';
import 'report_xml.dart';

/// Band report engine.
///
/// ```dart
/// final engine = QudsReportEngine.fromXml(templateXml, fonts: fonts);
/// final Uint8List pdf = await engine.exportToPdf(<String, Object?>{
///   'invoiceNo': 'INV-2026-001',
///   'items': <Map<String, Object?>>[
///     <String, Object?>{'code': 'P01', 'qty': 1, 'price': 500, 'total': 500},
///   ],
/// });
/// ```
///
/// Data is converted once into typed [ReportValue]s (maps → records,
/// iterables → lists). The template is read at export time, so a designer
/// can keep editing [template] and re-export.
class QudsReportEngine {
  /// QudsReportEngine API.
  QudsReportEngine(
    this.template, {
    ReportFontRegistry? fonts,
    Map<String, Uint8List>? images,
    this.userName = '',
    this.clock,
    Map<String, ReportFunction>? functions,
    Map<String, Object?>? variables,
    this.strict = false,
    this.diagnostics = const <ReportDiagnostic>[],
  }) : fonts = fonts ?? ReportFontRegistry(),
       images = images ?? <String, Uint8List>{},
       functions = functions ?? <String, ReportFunction>{},
       variables = variables ?? <String, Object?>{};

  /// Parses [xml]; throws [ReportTemplateException] when it has errors.
  factory QudsReportEngine.fromXml(
    String xml, {
    ReportFontRegistry? fonts,
    Map<String, Uint8List>? images,
    String userName = '',
    DateTime Function()? clock,
    Map<String, ReportFunction>? functions,
    Map<String, Object?>? variables,
    bool strict = false,
  }) {
    final ReportParseResult parsed = QudsReportXmlParser().parse(xml);
    return QudsReportEngine(
      parsed.templateOrThrow,
      fonts: fonts,
      images: images,
      userName: userName,
      clock: clock,
      functions: functions,
      variables: variables,
      strict: strict,
      diagnostics: parsed.diagnostics,
    );
  }

  /// Template being generated (mutable; edits apply to the next export).
  final ReportTemplate template;

  /// Fonts used for shaping and PDF embedding.
  final ReportFontRegistry fonts;

  /// Named images (`<Image source="logo"/>`).
  final Map<String, Uint8List> images;

  /// `System.UserName`.
  final String userName;

  /// Clock for `System.CurrentDate` (tests pin it).
  final DateTime Function()? clock;

  /// Host functions callable from expressions.
  final Map<String, ReportFunction> functions;

  /// Host values overriding template `<Variables>`.
  final Map<String, Object?> variables;

  /// Throw on expression errors instead of printing `#ERR`.
  final bool strict;

  /// Parser warnings from [QudsReportEngine.fromXml].
  final List<ReportDiagnostic> diagnostics;

  /// Expression engine with the template's display formats.
  QudsExpressionEngine get expressions => QudsExpressionEngine(
    formatter: ReportFormatter(defaults: template.formats),
    functions: functions,
  );

  /// Serializes [template] back to `.qrep` XML.
  String toXml() => const QudsReportXmlWriter().write(template);

  /// Static checks: every placeholder parses and calls known functions.
  List<ReportDiagnostic> validate() {
    final QudsExpressionEngine engine = expressions;
    final List<ReportDiagnostic> out = <ReportDiagnostic>[];
    void check(String path, String? source, {bool expression = false}) {
      if (source == null || source.trim().isEmpty) {
        return;
      }
      final List<ReportExpression> exprs = <ReportExpression>[];
      try {
        if (expression && !source.contains('{{')) {
          exprs.add(ReportExpression.parse(source));
        } else {
          exprs.addAll(ReportTemplateText.parse(source).expressions);
        }
      } on ReportExpressionException catch (e) {
        out.add(
          ReportDiagnostic(ReportDiagnosticSeverity.error, path, e.message),
        );
        return;
      }
      for (final ReportExpression x in exprs) {
        for (final String fn in ReportExpression.functions(x.root)) {
          if (!engine.knowsFunction(fn)) {
            out.add(
              ReportDiagnostic(
                ReportDiagnosticSeverity.error,
                path,
                'Unknown function $fn() in "${x.source}"',
              ),
            );
          }
        }
      }
    }

    for (final ReportVariable v in template.variables) {
      final String path = 'Variables/${v.name}';
      switch (v.type) {
        case ReportVariableType.text:
          check(path, v.value);
        case ReportVariableType.expression:
          check(path, v.value, expression: true);
        case ReportVariableType.number:
        case ReportVariableType.boolean:
        case ReportVariableType.date:
        case ReportVariableType.list:
          final String? err = v.error;
          if (err != null) {
            out.add(
              ReportDiagnostic(ReportDiagnosticSeverity.error, path, err),
            );
          }
      }
    }
    for (final ReportBand b in template.bands) {
      final String bp = 'Bands/${b.kind.xmlName}';
      check('$bp@dataSet', b.dataSet, expression: true);
      check('$bp@groupBy', b.groupBy, expression: true);
      check('$bp@filter', b.filter, expression: true);
      check('$bp@visibleWhen', b.visibleWhen, expression: true);
      final String? sortBy = b.sortBy;
      if (sortBy != null) {
        for (final ({String source, bool? descending}) key
            in ReportExpression.sortKeys(sortBy)) {
          check('$bp@sortBy', key.source, expression: true);
        }
      }
      for (int i = 0; i < b.elements.length; i++) {
        final ReportElement e = b.elements[i];
        final String ep = '$bp/${e.displayName}[$i]';
        check('$ep@visibleWhen', e.visibleWhen, expression: true);
        switch (e) {
          case ReportTextElement(:final String text):
            check(ep, text);
          case ReportImageElement(:final String source):
            check(ep, source);
          case ReportBarcodeElement(:final String data):
            check(ep, data);
          case ReportTableElement():
            check('$ep@dataSet', e.dataSet, expression: true);
            for (int c = 0; c < e.columns.length; c++) {
              check('$ep/Column[$c]', e.columns[c].header);
            }
            for (int c = 0; c < e.cells.length; c++) {
              check('$ep/Cell[$c]', e.cells[c].template);
            }
            for (int c = 0; c < e.footerCells.length; c++) {
              check('$ep/FooterCell[$c]', e.footerCells[c].template);
            }
          case ReportShapeElement():
            break;
          case ReportChartElement():
            check('$ep@dataSet', e.dataSet, expression: true);
            check('$ep@title', e.title);
            check('$ep@category', e.category, expression: true);
            for (int s = 0; s < e.series.length; s++) {
              check('$ep/Series[$s]', e.series[s].name);
              check(
                '$ep/Series[$s]@value',
                e.series[s].value,
                expression: true,
              );
            }
            for (int p = 0; p < e.points.length; p++) {
              check('$ep/Point[$p]', e.points[p].label);
              check('$ep/Point[$p]@value', e.points[p].value, expression: true);
            }
        }
      }
    }
    return out;
  }

  ReportGenerator _generator(QudsExpressionEngine engine, DateTime now) {
    return ReportGenerator(
      template: template,
      engine: engine,
      shaper: ReportTextShaper(fonts),
      images: images,
      now: now,
      userName: userName,
      variableOverrides: <String, ReportValue>{
        for (final MapEntry<String, Object?> e in variables.entries)
          e.key: ReportValue.from(e.value),
      },
      strict: strict,
    );
  }

  static ReportRecord _record(Map<String, Object?> data) {
    final ReportValue v = ReportValue.from(data);
    return v is ReportRecord ? v : ReportRecord.empty;
  }

  /// Paginated layout (what the PDF writer and the designer preview paint).
  ReportDocumentLayout layout(Map<String, Object?> data) {
    final ReportDocumentLayout result = _generator(
      expressions,
      clock?.call() ?? DateTime.now(),
    ).generate(_record(data));
    if (!fonts.isEmpty) {
      return result;
    }
    return ReportDocumentLayout(
      template: result.template,
      pageWidth: result.pageWidth,
      pageHeight: result.pageHeight,
      pages: result.pages,
      fonts: result.fonts,
      flow: result.flow,
      warnings: <String>[
        'No font registered: only WinAnsi Latin text is drawn (Helvetica)',
        ...result.warnings,
      ],
    );
  }

  /// PDF bytes for [data].
  Uint8List exportToPdfSync(
    Map<String, Object?> data, {
    PdfSaveOptions options = const PdfSaveOptions(),
  }) => ReportPdfWriter(author: userName, options: options).write(layout(data));

  /// PDF bytes for [data].
  Future<Uint8List> exportToPdf(
    Map<String, Object?> data, {
    PdfSaveOptions options = const PdfSaveOptions(),
  }) async => exportToPdfSync(data, options: options);

  /// XLSX bytes for [data].
  Uint8List exportToExcelSync(Map<String, Object?> data) =>
      const ReportXlsxWriter().write(layout(data));

  /// XLSX bytes for [data].
  Future<Uint8List> exportToExcel(Map<String, Object?> data) async =>
      exportToExcelSync(data);

  /// DOCX bytes for [data].
  Uint8List exportToWordSync(Map<String, Object?> data) {
    final QudsExpressionEngine engine = expressions;
    final DateTime now = clock?.call() ?? DateTime.now();
    final ReportGenerator generator = _generator(engine, now);
    final ReportRecord record = _record(data);
    final ReportDocumentLayout laid = generator.generate(record);
    return ReportDocxWriter(
      engine: engine,
      scope: generator.baseScope(record, totalPages: laid.pages.length),
    ).write(laid);
  }

  /// DOCX bytes for [data].
  Future<Uint8List> exportToWord(Map<String, Object?> data) async =>
      exportToWordSync(data);
}
