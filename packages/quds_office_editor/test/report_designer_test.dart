import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

const double mm = 72 / 25.4;

const String sampleXml = r'''<?xml version="1.0" encoding="UTF-8"?>
<QudsReport name="Sample" pageSize="A4" mirrorRtl="true">
    <Settings>
        <Margins top="10mm" bottom="10mm" left="10mm" right="10mm"/>
    </Settings>
    <Bands>
        <ReportHeader height="30mm">
            <Element type="Text" name="title" x="20mm" y="5mm" width="60mm" height="10mm">Hello {{Data.customer}}</Element>
            <Element type="Text" name="sub" x="100mm" y="12mm" width="40mm" height="8mm">Sub</Element>
            <Element type="Shape" kind="Rectangle" name="box" x="150mm" y="2mm" width="30mm" height="20mm"/>
        </ReportHeader>
        <Detail dataSet="items" height="8mm">
            <Element type="Text" name="line" x="10mm" y="1mm" width="80mm" height="6mm">{{item.name}} {{item.qty}}</Element>
        </Detail>
        <ReportSummary height="12mm">
            <Element type="Text" x="10mm" y="2mm" width="80mm" height="8mm">{{SUM(items.qty)}}</Element>
        </ReportSummary>
    </Bands>
</QudsReport>
''';

ReportElement byName(ReportDesignerController c, String name) => c
    .template
    .allElements
    .map(((ReportBand, ReportElement) p) => p.$2)
    .firstWhere((ReportElement e) => e.name == name);

ReportDesignerController sample({bool rtl = false}) {
  final String xml = rtl
      ? sampleXml.replaceFirst('pageSize="A4"', 'pageSize="A4" isRtl="true"')
      : sampleXml;
  return ReportDesignerController.fromXml(
    xml,
    clock: () => DateTime(2026, 10, 10, 9, 30),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportDesignerController', () {
    test('nudge records one undo step and redo re-applies it', () {
      final ReportDesignerController c = sample();
      final ReportElement title = byName(c, 'title');
      c.select(title.id);
      final double x0 = title.x;
      c.nudge(5 * mm, 0);
      expect(title.x, closeTo(x0 + 5 * mm, 0.01));
      expect(c.canUndo, isTrue);
      c.undo();
      expect(byName(c, 'title').x, closeTo(x0, 0.01));
      expect(c.canRedo, isTrue);
      c.redo();
      expect(byName(c, 'title').x, closeTo(x0 + 5 * mm, 0.01));
      expect(c.selection, <String>[title.id]);
      c.dispose();
    });

    test('align and size tools use the primary element', () {
      final ReportDesignerController c = sample();
      final ReportElement title = byName(c, 'title');
      final ReportElement sub = byName(c, 'sub');
      final ReportElement box = byName(c, 'box');
      c.selectIds(<String>[title.id, sub.id]);
      c.align(ReportAlignAction.left);
      expect(sub.x, closeTo(title.x, 0.01));
      c.align(ReportAlignAction.sameWidth);
      expect(sub.width, closeTo(title.width, 0.01));
      c.align(ReportAlignAction.top);
      expect(sub.y, closeTo(title.y, 0.01));

      c.selectIds(<String>[box.id, title.id, sub.id]);
      title.x = 10 * mm;
      sub.x = 50 * mm;
      box.x = 150 * mm;
      title.width = sub.width = box.width = 20 * mm;
      c.align(ReportAlignAction.distributeX);
      expect(sub.x, closeTo(80 * mm, 0.05));

      c.select(null);
      c.select(box.id);
      c.align(ReportAlignAction.right);
      expect(
        box.x + box.width,
        closeTo(c.template.pageWidth - c.template.margins.right, 0.05),
      );
      c.dispose();
    });

    test('setProperty applies valid values and ignores invalid ones', () {
      final ReportDesignerController c = sample();
      final ReportTextElement title = byName(c, 'title') as ReportTextElement;
      c.select(title.id);
      c.setProperty('width', '50mm');
      expect(title.width, closeTo(50 * mm, 0.01));
      c.setProperty('bold', 'true');
      expect(title.style.bold, isTrue);
      final int revision = c.revision;
      c.setProperty('width', 'not a length');
      expect(c.revision, revision);
      expect(title.width, closeTo(50 * mm, 0.01));
      final List<ReportProperty> props = c.properties;
      expect(props.map((ReportProperty p) => p.key), contains('text'));
      expect(c.inspectorTitle, isNotEmpty);
      c.dispose();
    });

    test('addElement uses default sizes for clicks and undo removes it', () {
      final ReportDesignerController c = sample();
      final int before = c.template.allElements.length;
      final ReportElement? e = c.addElement(
        ReportDesignTool.text,
        ReportBandKind.detail,
        const ReportRect(30 * mm, 0, 0, 0),
      );
      expect(e, isA<ReportTextElement>());
      expect(e!.width, closeTo(40 * mm, 0.01));
      expect(c.selection, <String>[e.id]);
      expect(c.template.allElements.length, before + 1);
      c.undo();
      expect(c.template.allElements.length, before);
      c.dispose();
    });

    test('mirrored RTL templates edit in physical coordinates', () {
      final ReportDesignerController c = sample(rtl: true);
      expect(c.template.mirrored, isTrue);
      final ReportElement title = byName(c, 'title');
      final ReportRect r = c.physicalRect(title);
      expect(
        r.left,
        closeTo(c.template.pageWidth - title.x - title.width, 0.01),
      );
      c.select(title.id);
      c.nudge(10 * mm, 0);
      expect(title.x, closeTo(20 * mm - 10 * mm, 0.01));
      c.beginGesture();
      c.gestureSetRects(<String, ReportRect>{
        title.id: ReportRect(100 * mm, r.top, r.width, r.height),
      });
      c.endGesture();
      expect(
        title.x,
        closeTo(c.template.pageWidth - 100 * mm - title.width, 0.01),
      );
      c.undo();
      expect(byName(c, 'title').x, closeTo(10 * mm, 0.01));
      c.dispose();
    });

    test('copy and paste clone elements with fresh ids', () {
      final ReportDesignerController c = sample();
      final ReportElement title = byName(c, 'title');
      c.select(title.id);
      c.copySelection();
      expect(c.canPaste, isTrue);
      c.paste();
      expect(c.selection, hasLength(1));
      expect(c.selection.single, isNot(title.id));
      expect(
        c.template.allElements.where(
          ((ReportBand, ReportElement) p) => p.$2.name == 'title',
        ),
        hasLength(2),
      );
      c.deleteSelection();
      expect(c.selection, isEmpty);
      c.dispose();
    });

    test('bands can be added and removed', () {
      final ReportDesignerController c = sample();
      expect(c.template.band(ReportBandKind.pageFooter), isNull);
      c.addBand(ReportBandKind.pageFooter);
      expect(c.template.band(ReportBandKind.pageFooter), isNotNull);
      expect(c.selectedBand, ReportBandKind.pageFooter);
      c.removeBand(ReportBandKind.pageFooter);
      expect(c.template.band(ReportBandKind.pageFooter), isNull);
      c.dispose();
    });

    test('XML round-trips and the live preview uses inferred data', () async {
      final ReportDesignerController c = sample();
      final int count = c.template.allElements.length;
      c.loadXml(c.toXml());
      expect(c.template.allElements.length, count);
      expect(c.mockData['customer'], isNotNull);
      expect(c.mockData['items'], isA<List<Object?>>());
      final ReportDocumentLayout? layout = c.previewLayout;
      expect(c.previewError, isNull);
      expect(layout, isNotNull);
      expect(layout!.pages, isNotEmpty);
      final Uint8List pdf = await c.export(ReportExportFormat.pdf);
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
      c.dispose();
    });

    test('charts are added, edited, previewed, and round-tripped', () {
      final ReportDesignerController c = sample();
      final ReportElement? e = c.addElement(
        ReportDesignTool.chart,
        ReportBandKind.reportSummary,
        const ReportRect(20 * mm, 0, 0, 0),
      );
      expect(e, isA<ReportChartElement>());
      final ReportChartElement chart = e! as ReportChartElement;
      expect(chart.width, closeTo(90 * mm, 0.01));
      expect(chart.series, hasLength(1));
      expect(
        c.properties.map((ReportProperty p) => p.key),
        containsAll(<String>['chartType', 'category', 'series.0.value']),
      );

      c.setProperty('dataSet', 'Data.items');
      c.setProperty('category', 'Row.name');
      c.setProperty('series.0.value', 'Row.qty');
      c.setProperty('seriesCount', '2');
      expect(chart.series, hasLength(2));
      c.setProperty('series.1.color', '#FF0000');
      expect(chart.series[1].color, '#FF0000');
      c.setProperty('chartType', 'nonsense');
      expect(chart.chartType, ReportChartType.bar);
      c.setProperty('chartType', 'donut');
      expect(chart.chartType, ReportChartType.donut);
      c.setProperty('limit', '3');
      expect(chart.limit, 3);

      final ReportDocumentLayout? layout = c.previewLayout;
      expect(c.previewError, isNull);
      final List<ReportPrimitive> prims = <ReportPrimitive>[
        for (final ReportPageLayout page in layout!.pages)
          for (final ReportPrimitive p in page.primitives)
            if (p.elementId == chart.id) p,
      ];
      expect(prims.whereType<ReportPathPrimitive>(), isNotEmpty);

      c.setProperty('seriesCount', '0');
      expect(chart.series, isEmpty);
      expect(chart.points, hasLength(3));
      c.setProperty('pointCount', '5');
      c.setProperty('point.4.value', '75');
      expect(chart.points[4].value, '75');

      c.loadXml(c.toXml());
      final ReportChartElement back = c.template.allElements
          .map(((ReportBand, ReportElement) p) => p.$2)
          .whereType<ReportChartElement>()
          .single;
      expect(back.chartType, ReportChartType.donut);
      expect(back.points, hasLength(5));
      expect(back.points[4].value, '75');
      c.dispose();
    });

    test('ready-made templates load with their sample data', () {
      for (final ReportTemplateInfo info in ReportTemplates.all) {
        final ReportDesignerController c = ReportDesignerController(
          clock: () => DateTime(2026, 10, 10, 9, 30),
        );
        c.loadTemplate(info);
        expect(c.hasHostData, isTrue, reason: info.id);
        expect(c.template.isRtl, info.rtl, reason: info.id);
        final ReportDocumentLayout? layout = c.previewLayout;
        expect(c.previewError, isNull, reason: info.id);
        expect(layout!.pages, isNotEmpty, reason: info.id);
        c.dispose();
      }
    });

    test('bindings complete from data, functions, and formats', () {
      final ReportDesignerController c = sample();
      final ReportTextElement title = byName(c, 'title') as ReportTextElement;
      c.beginTextEdit(title.id);
      final InlineCellEditor ed = c.textEditor;
      void type(String text) => ed.replaceRange(0, ed.formulaBar.length, text);

      type('Hi {{');
      expect(
        c.completion!.items.map((ReportCompletionItem i) => i.insert),
        containsAll(<String>['item', 'Data', 'SUM()']),
      );
      type('Hi {{Data.cu');
      expect(c.completion!.items.first.insert, 'customer');
      expect(c.acceptCompletion(), isTrue);
      expect(ed.formulaBar, 'Hi {{Data.customer');
      expect(c.completion, isNull);

      type('{{SU');
      c.acceptCompletion();
      expect(ed.formulaBar, '{{SUM()');
      expect(ed.caretIndex, 6);
      expect(c.completion, isNotNull);

      type('{{item.price | n');
      expect(c.completion!.items.first.insert, 'n0');
      c.moveCompletion(1);
      expect(c.completionIndex, 1);
      c.dismissCompletion();
      expect(c.completion, isNull);
      ed.replaceRange(ed.formulaBar.length, ed.formulaBar.length, '2');
      expect(c.completion, isNull);
      c.triggerCompletion();
      expect(c.completion, isNotNull);
      c.cancelTextEdit();
      expect(c.completion, isNull);

      c.select(title.id);
      c.beginPropertyEdit('visibleWhen');
      c.propertyEditor.replaceRange(
        0,
        c.propertyEditor.formulaBar.length,
        'item.',
      );
      expect(
        c.completion!.items.map((ReportCompletionItem i) => i.insert),
        containsAll(<String>['name', 'qty']),
      );
      c.cancelPropertyEdit();
      c.dispose();
    });

    test('template variables are typed, renamed, inserted, and previewed', () {
      final ReportDesignerController c = sample();
      c.select(null);
      final ReportVariable v = c.addVariable();
      expect(v.name, 'variable1');
      expect(
        c.properties.map((ReportProperty p) => p.key),
        containsAll(<String>[
          'var+',
          'var.0.name',
          'var.0.type',
          'var.0.value',
        ]),
      );
      c.setProperty('var.0.type', 'number');
      expect(v.type, ReportVariableType.number);
      expect(v.value, '0');
      c.setProperty('var.0.value', 'abc');
      expect(v.value, '0');
      c.setProperty('var.0.value', '1250.5');
      expect(v.value, '1250.5');
      c.setProperty('var.0.format', 'n2');
      expect(v.placeholder, '{{Variables.variable1 | n2}}');

      final ReportTextElement title = byName(c, 'title') as ReportTextElement;
      c.select(title.id);
      final ReportElement? box = c.insertVariable('variable1');
      expect(box, isA<ReportTextElement>());
      expect((box! as ReportTextElement).text, '{{Variables.variable1 | n2}}');
      expect(
        c.template.findElement(box.id)!.$1.kind,
        ReportBandKind.reportHeader,
      );

      c.beginTextEdit(title.id);
      c.textEditor.setCaret(0);
      c.insertVariable('variable1');
      expect(
        c.textEditor.formulaBar,
        startsWith('{{Variables.variable1 | n2}}Hello'),
      );
      c.commitTextEdit();

      c.select(null);
      c.setProperty('var.0.name', 'bad name');
      expect(c.template.variables.single.name, 'variable1');
      c.setProperty('var.0.name', 'amount');
      expect(c.template.variables.single.name, 'amount');
      final List<String> texts = <String>[
        for (final (ReportBand, ReportElement) be in c.template.allElements)
          if (be.$2 case final ReportTextElement t) t.text,
      ];
      expect(
        texts.where((String t) => t.contains('Variables.amount')),
        hasLength(2),
      );
      expect(texts.where((String t) => t.contains('variable1')), isEmpty);

      final List<String> preview = <String>[
        for (final ReportPageLayout page in c.previewLayout!.pages)
          for (final ReportPrimitive p in page.primitives)
            if (p case final ReportTextPrimitive t) t.text,
      ];
      expect(preview, contains('1,250.50'));

      c.undo();
      expect(c.template.variables.single.name, 'variable1');
      c.select(null);
      c.addVariable(type: ReportVariableType.boolean);
      c.setProperty('var.1.value', 'true');
      expect(c.template.variables[1].value, 'true');
      c.setProperty('var.1.remove', 'Remove');
      expect(c.template.variables, hasLength(1));
      expect(c.toXml(), contains('type="number"'));
      c.dispose();
    });

    test('inspector metadata drives steppers, presets, and pairs', () {
      final ReportDesignerController c = sample();
      final ReportTextElement title = byName(c, 'title') as ReportTextElement;
      c.select(title.id);
      ReportProperty prop(String key) =>
          c.properties.firstWhere((ReportProperty p) => p.key == key);

      expect(prop('x').pair && prop('y').pair, isTrue);
      expect(prop('width').pair && prop('height').pair, isTrue);
      expect(prop('bold').glyph, 'bold');
      expect(prop('italic').glyph, 'italic');
      expect(prop('format').presets, contains('n2'));
      expect(prop('fontFamily').presets, contains('Noto Naskh Arabic'));
      expect(prop('fontSize').presets, contains('12'));
      expect(prop('color').hint, 'none');
      expect(prop('x').isSteppable, isTrue);

      final String x = prop('x').value;
      expect(c.stepProperty('x', 1), isTrue);
      expect(
        ReportUnits.tryParse(prop('x').value, defaultUnit: c.template.unit),
        closeTo(
          ReportUnits.tryParse(x, defaultUnit: c.template.unit)! +
              c.template.unit.points,
          0.01,
        ),
      );
      expect(prop('x').value, endsWith(c.template.unit.suffix));

      c.setProperty('fontSize', '');
      expect(c.stepProperty('fontSize', 1), isTrue);
      expect(
        double.parse(prop('fontSize').value),
        c.template.defaultFontSize + 1,
      );
      expect(c.stepProperty('fontSize', 1, large: true), isTrue);
      expect(
        double.parse(prop('fontSize').value),
        c.template.defaultFontSize + 11,
      );

      c.setProperty('borderWidth', '0');
      expect(c.stepProperty('borderWidth', -1), isFalse);
      expect(c.stepProperty('borderWidth', 1), isTrue);
      expect(prop('borderWidth').value, '0.25');
      expect(c.steppedValue(prop('x'), 1, from: '10.5mm'), endsWith('mm'));

      c.select(null);
      c.addVariable();
      expect(prop('var.0.insert').pair && prop('var.0.remove').pair, isTrue);
      c.dispose();
    });

    test('property editing commits through the inline editor', () {
      final ReportDesignerController c = sample();
      final ReportTextElement title = byName(c, 'title') as ReportTextElement;
      c.select(title.id);
      c.beginPropertyEdit('text');
      expect(c.editingProperty, 'text');
      c.propertyEditor.replaceRange(
        0,
        c.propertyEditor.formulaBar.length,
        'Changed',
      );
      c.commitPropertyEdit();
      expect(c.editingProperty, isNull);
      expect(title.text, 'Changed');
      c.beginTextEdit(title.id);
      c.textEditor.replaceRange(0, 0, 'X');
      c.cancelTextEdit();
      expect(title.text, 'Changed');
      c.dispose();
    });
  });

  group('QudsReportDesigner', () {
    Future<ReportDesignerController> pumpDesigner(
      WidgetTester tester, {
      ReportDesignerController? controller,
    }) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ReportDesignerController c = controller ?? sample();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: QudsReportDesigner(
            controller: c,
            loadBundledFonts: false,
            templates: const <ReportTemplateInfo>[],
            onExport: (ReportExportFormat f, Uint8List bytes) {},
          ),
        ),
      );
      await tester.pump();
      return c;
    }

    Offset elementCenter(
      WidgetTester tester,
      ReportDesignerController c,
      ReportElement e,
    ) {
      final Rect canvas = tester.getRect(find.byType(ReportDesignerCanvas));
      final ReportDesignLayout layout = ReportDesignLayout.of(c.template);
      final (ReportDesignSlot, ReportElement) f = layout.find(e.id)!;
      final Rect r = layout.elementRect(f.$1, f.$2);
      final double s = c.zoom;
      final double docW = layout.width * s;
      final double avail = canvas.width - RenderReportDesigner.ruler;
      final double ox = docW + 2 * RenderReportDesigner.pad < avail
          ? RenderReportDesigner.ruler + (avail - docW) / 2
          : RenderReportDesigner.ruler + RenderReportDesigner.pad;
      const double oy = RenderReportDesigner.ruler + RenderReportDesigner.pad;
      return canvas.topLeft + Offset(ox, oy) + r.center * s;
    }

    testWidgets('inspector paints sections and the color palette', (
      WidgetTester tester,
    ) async {
      final ReportDesignerController c = sample();
      await pumpDesigner(tester, controller: c);
      c.select((byName(c, 'title') as ReportTextElement).id);
      await tester.pump();
      final RenderReportInspector inspector = tester.renderObject(
        find.byType(ReportInspector),
      );
      inspector.openPalette('color');
      await tester.pump();
      expect(inspector.paletteKey, 'color');
      inspector.setCollapsed('Font', true);
      await tester.pump();
      expect(inspector.isCollapsed('Font'), isTrue);
      inspector.openPalette(null);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap selects and drag moves an element as one undo step', (
      WidgetTester tester,
    ) async {
      final ReportDesignerController c = await pumpDesigner(tester);
      final ReportElement sub = byName(c, 'sub');
      final double x0 = sub.x;
      final Offset at = elementCenter(tester, c, sub);

      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.selection, <String>[sub.id]);

      // Away from the tap so the press is not read as a double-click.
      final TestGesture g = await tester.startGesture(
        at + const Offset(10, 0),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(20, 0));
      await g.moveBy(const Offset(40, 0));
      await g.up();
      await tester.pump();
      expect(sub.x, greaterThan(x0 + 50));
      expect(sub.x, lessThan(x0 + 70));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(byName(c, 'sub').x, closeTo(x0, 0.01));
    });

    testWidgets('keyboard nudges and deletes the selection', (
      WidgetTester tester,
    ) async {
      final ReportDesignerController c = await pumpDesigner(tester);
      final ReportElement box = byName(c, 'box');
      await tester.tapAt(elementCenter(tester, c, box));
      await tester.pump(const Duration(milliseconds: 500));
      final double x0 = box.x;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(box.x, closeTo(x0 + c.gridSize, 0.02));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(c.template.findElement(box.id), isNull);
    });

    testWidgets('toolbar switches tools and the preview', (
      WidgetTester tester,
    ) async {
      final ReportDesignerController c = await pumpDesigner(tester);
      final Offset bar = tester.getTopLeft(find.byType(ReportToolbar));
      final RenderReportToolbar toolbar = tester.renderObject(
        find.byType(ReportToolbar),
      );
      await tester.tapAt(bar + toolbar.rectOf('tool.text')!.center);
      await tester.pump();
      expect(c.tool, ReportDesignTool.text);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(c.tool, ReportDesignTool.select);

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(c.mode, ReportDesignMode.preview);
      expect(find.byType(ReportPreviewSurface), findsOneWidget);
      expect(find.byType(ReportDesignerCanvas), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(find.byType(ReportDesignerCanvas), findsOneWidget);
    });

    testWidgets('creating with a tool adds an element where clicked', (
      WidgetTester tester,
    ) async {
      final ReportDesignerController c = await pumpDesigner(tester);
      final int before = c.template.allElements.length;
      c.tool = ReportDesignTool.rectangle;
      await tester.pump();
      final ReportElement line = byName(c, 'line');
      final Offset at = elementCenter(tester, c, line) + const Offset(0, 40);
      final TestGesture g = await tester.startGesture(
        at,
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(60, 30));
      await g.up();
      await tester.pump();
      expect(c.template.allElements.length, before + 1);
      final ReportElement created = c.primary!;
      expect(created, isA<ReportShapeElement>());
      expect(created.width, greaterThan(50));
      expect(c.tool, ReportDesignTool.select);
    });

    testWidgets('chart templates paint in design and preview', (
      WidgetTester tester,
    ) async {
      final ReportDesignerController c = ReportDesignerController(
        clock: () => DateTime(2026, 10, 10, 9, 30),
      )..loadTemplate(ReportTemplates.byId('sales_performance')!);
      await pumpDesigner(tester, controller: c);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(find.byType(ReportPreviewSurface), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard picks a suggestion while editing on the canvas', (
      WidgetTester tester,
    ) async {
      final ReportDesignerController c = await pumpDesigner(tester);
      final ReportTextElement title = byName(c, 'title') as ReportTextElement;
      title.style.color = '#FFFFFF';
      title.background = '#1F4E78';
      c.beginTextEdit(title.id);
      c.textEditor.replaceRange(0, c.textEditor.formulaBar.length, '{{Sys');
      await tester.pump();
      expect(c.completion, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(c.textEditor.formulaBar, '{{System');
      c.textEditor.replaceRange(8, 8, '.Page');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(c.textEditor.formulaBar, '{{System.PageNumber');
      expect(c.editingId, title.id);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(c.editingId, isNull);
      expect(tester.takeException(), isNull);
    });

    test('editor text keeps contrast on dark fills', () {
      expect(
        RenderReportDesigner.contrast(
          const Color(0xFFFFFFFF),
          const Color(0xFF1F4E78),
        ),
        greaterThan(4.5),
      );
      expect(
        RenderReportDesigner.contrast(
          const Color(0xFFFFFFFF),
          const Color(0xFFFFFFFF),
        ),
        closeTo(1, 1e-9),
      );
    });
  });
}
