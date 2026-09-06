import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart';

/// In-memory deck: presets, rotation, chart, speaker notes.
PmlPresentation engineDeck() {
  return PmlPresentation(
    master: PmlMaster(name: 'Office Theme', background: 'F4F7FB'),
    slides: <PmlSlide>[
      PmlSlide(
        id: 256,
        notes: 'Welcome the reviewer. Point at the rotated title bar.',
        shapes: <PmlShape>[
          PmlShape(
            id: 2,
            name: 'Rail',
            fillColor: '2B579A',
            transform: const PmlTransform(x: 0, y: 0, cx: 914400, cy: 5143500),
          ),
          PmlShape(
            id: 3,
            name: 'Title',
            text: 'Engine slide stage',
            fillColor: '2B579A',
            transform: const PmlTransform(
              x: 1400000,
              y: 1600000,
              cx: 6200000,
              cy: 900000,
              rot: 8 * 60000,
            ),
          ),
          PmlShape(
            id: 4,
            name: 'Sub',
            text: 'Rotation, fills, and notes travel into PDF.',
            fillColor: 'FFFFFF',
            transform: const PmlTransform(
              x: 1400000,
              y: 2800000,
              cx: 6200000,
              cy: 700000,
            ),
          ),
        ],
      ),
      PmlSlide(
        id: 257,
        notes: 'Walk the three presets: rounded, ellipse, triangle.',
        shapes: <PmlShape>[
          PmlShape(
            id: 5,
            name: 'Round',
            preset: PmlShapePreset.roundRect,
            text: 'roundRect',
            fillColor: '2B579A',
            transform: const PmlTransform(
              x: 600000,
              y: 1200000,
              cx: 2400000,
              cy: 1600000,
            ),
          ),
          PmlShape(
            id: 6,
            name: 'Oval',
            preset: PmlShapePreset.ellipse,
            text: 'ellipse',
            fillColor: '217346',
            transform: const PmlTransform(
              x: 3400000,
              y: 1200000,
              cx: 2400000,
              cy: 1600000,
            ),
          ),
          PmlShape(
            id: 7,
            name: 'Tri',
            preset: PmlShapePreset.triangle,
            text: 'triangle',
            fillColor: 'B7472A',
            transform: const PmlTransform(
              x: 6200000,
              y: 1200000,
              cx: 2400000,
              cy: 1600000,
            ),
          ),
        ],
      ),
      PmlSlide(
        id: 258,
        notes: 'The pie is an OfficeVisual, not a screenshot.',
        shapes: <PmlShape>[
          PmlShape(
            id: 8,
            name: 'Chart',
            visual: OfficeVisual(
              kind: OfficeVisualKind.chartPie,
              title: 'Gallery share',
              points: OfficeVisual.sampleSeries(),
              width: 420,
              height: 240,
            ),
            transform: const PmlTransform(
              x: 800000,
              y: 900000,
              cx: 7500000,
              cy: 3600000,
            ),
          ),
        ],
      ),
    ],
  );
}

/// Fluent builder: cover, section, KPI, table, charts, quote, media, close.
Uint8List builderDeck() {
  final Uint8List card = PngBytes.studioCard(width: 480, height: 240);
  return (PptxDeckBuilder(
          showSlideNumber: true,
          footerBar: 'Quds Office Engine',
        )
        ..addCoverSlide(
          kicker: 'GALLERY',
          title: 'Nine layout recipes',
          subtitle: 'Cover, section, KPI, table, charts, quote, media',
          accentRail: true,
          notes: 'Start on the kicker, then the title.',
        )
        ..addSectionSlide(
          kicker: '01',
          title: 'Product',
          notes: 'Section break',
        )
        ..addKpiSlide(
          title: 'This run',
          cards: <({String label, String value})>[
            (label: 'Word files', value: '3'),
            (label: 'Workbooks', value: '3'),
            (label: 'Decks', value: '3'),
          ],
          notes: 'Each count is a file plus its PDF.',
        )
        ..addTitleBodySlide(
          title: 'Why a gallery',
          bullets: <String>[
            'Builders write real OPC parts',
            'Engine models keep formulas and visuals',
            'PDF is compiled, not captured',
          ],
          notes: 'Do not demo a screenshot workflow.',
        )
        ..addTableSlide(
          title: 'Export map',
          rows: <List<String>>[
            <String>['App', 'Builder', 'PDF'],
            <String>['Word', 'DocxDocumentBuilder', 'fromBytes / fromWord'],
            <String>['Excel', 'XlsxWorkbookBuilder', 'fromWorkbook'],
            <String>['Slides', 'PptxDeckBuilder', 'slides or notesPages'],
          ],
        )
        ..addBarChartSlide(
          title: 'Files in this folder',
          series: const <ChartPoint>[
            ChartPoint(label: 'DOCX', value: 3, color: '2B579A'),
            ChartPoint(label: 'XLSX', value: 3, color: '217346'),
            ChartPoint(label: 'PPTX', value: 3, color: 'B7472A'),
          ],
        )
        ..addPieChartSlide(
          title: 'PDF twins',
          series: const <ChartPoint>[
            ChartPoint(label: 'Print', value: 9, color: '2B579A'),
            ChartPoint(label: 'Notes', value: 1, color: 'ED7D31'),
          ],
        )
        ..addLineChartSlide(
          title: 'Compile steps',
          series: const <ChartSeries>[
            ChartSeries(
              name: 'Parts',
              points: <ChartPoint>[
                ChartPoint(label: 'Model', value: 1),
                ChartPoint(label: 'OPC', value: 2),
                ChartPoint(label: 'Layout', value: 3),
                ChartPoint(label: 'PDF', value: 4),
              ],
            ),
          ],
        )
        ..addQuoteSlide(
          title: 'Note',
          quote:
              'One code path for bytes you can open in Office and for print.',
          attribution: 'Quds Office Engine',
        )
        ..addImageSlide(
          title: 'Generated media',
          pngBytes: card,
          caption: 'PngBytes.studioCard — no dart:ui',
        )
        ..addTwoColumnTextSlide(
          title: 'Open vs print',
          leftTitle: 'Office',
          rightTitle: 'PDF',
          left: <String>['Edit in Word / Excel / PowerPoint', 'Keep OPC parts'],
          right: <String>['Paginated print', 'Notes pages optional'],
        )
        ..addClosingSlide(
          title: 'Next',
          notes: 'Open the RTL deck after this one.',
        ))
      .build();
}

/// Arabic RTL deck — third PowerPoint shape.
Uint8List rtlDeck() {
  return (PptxDeckBuilder(
          rtl: true,
          showSlideNumber: true,
          footerBar: 'قدس أوفيس',
          theme: OfficeDocumentTheme.light(rtl: true),
        )
        ..addCoverSlide(
          kicker: 'معرض',
          title: 'شرائح من اليمين لليسار',
          subtitle: 'نفس البنّاء، اتجاه الفقرة عربي',
          accentRail: true,
          notes: 'ابدأ بالعنوان ثم القائمة.',
        )
        ..addTitleBodySlide(
          title: 'ماذا في المجلد',
          bullets: <String>[
            'ثلاثة ملفات وورد مع PDF',
            'ثلاثة مصنفات مع المعادلات أو التنسيق',
            'ثلاثة عروض — وهذا العرض بالعربية',
          ],
        )
        ..addKpiSlide(
          title: 'هذه الدفعة',
          cards: <({String label, String value})>[
            (label: 'مستندات', value: '٣'),
            (label: 'أوراق', value: '٣'),
            (label: 'شرائح', value: '٣'),
          ],
        )
        ..addClosingSlide(title: 'شكراً', notes: 'أغلق المعرض.'))
      .build();
}
