import 'dart:typed_data';

import 'package:quds_office_engine/pdf_templates.dart' as tpl;
import 'package:quds_office_engine/pdf_widgets.dart' as pw;
import 'package:quds_office_engine/quds_office_engine.dart';

import 'sample_library.dart';
import 'studio_files.dart';
import 'studio_pdf_face_samples.dart';
import 'studio_pdf_flutter_samples.dart';
import 'studio_pdf_rich_samples.dart';
import 'studio_pdf_showcase.dart';
import 'studio_pdf_template_samples.dart';
import 'studio_pdf_toc_samples.dart';
import 'studio_sample_pdf.dart';

/// How a gallery sample is produced.
enum StudioPdfSampleKind {
  /// OOXML (Word / Excel / PowerPoint) compiled through [OfficePdfExport].
  officeToPdf,

  /// Direct [PdfDocument] / [PdfReportBuilder] writer.
  pdfEngine,

  /// Constraint-layout [pw.Document] (`pdf_widgets`).
  pdfWidgets,

  /// Classified report templates (`pdf_templates`).
  templates,

  /// Bilingual showcase: gradients, charts, and tables that span pages.
  showcase,
}

/// One selectable PDF sample for the studio gallery.
class StudioPdfSample {
  /// StudioPdfSample API.
  const StudioPdfSample({
    required this.id,
    required this.kind,
    required this.titleEn,
    required this.titleAr,
    required this.blurbEn,
    required this.blurbAr,
    required this.fileName,
    required this.build,
    this.group = '',
  });

  /// Stable id.
  final String id;

  /// kind API.
  final StudioPdfSampleKind kind;

  /// titleEn API.
  final String titleEn;

  /// titleAr API.
  final String titleAr;

  /// blurbEn API.
  final String blurbEn;

  /// blurbAr API.
  final String blurbAr;

  /// Suggested file name (also used under system temp).
  final String fileName;

  /// Sub-group inside a kind. Template samples use the catalog category name.
  final String group;

  /// Builds PDF bytes (may use [font] / [fonts] when embedding text).
  final Uint8List Function({SfntFont? font, OfficeFontSet? fonts}) build;

  /// Localized title.
  String title(bool arabic) => arabic ? titleAr : titleEn;

  /// Localized blurb.
  String blurb(bool arabic) => arabic ? blurbAr : blurbEn;
}

/// Experimental PDF sample catalog for the studio viewer.
abstract final class StudioPdfGallery {
  /// All samples, grouped by [StudioPdfSampleKind] order.
  static List<StudioPdfSample> get all => <StudioPdfSample>[
        ...officeSamples,
        ...engineSamples,
        ...widgetSamples,
        ...templateSamples,
        ...showcaseSamples,
      ];

  /// Office → PDF samples.
  static final List<StudioPdfSample> officeSamples = <StudioPdfSample>[
    StudioPdfSample(
      id: 'office-tahreer-word',
      kind: StudioPdfSampleKind.officeToPdf,
      titleEn: 'Al Tahreer Word briefing',
      titleAr: 'إحاطة ورد — التحرير',
      blurbEn: 'Rich DOCX (tables, images, bilingual) exported to PDF.',
      blurbAr: 'مستند ورد غني (جداول وصور وثنائي اللغة) يُصدَّر إلى PDF.',
      fileName: 'office_tahreer_briefing.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => OfficePdfExport.word(
        SampleLibrary.wordBriefing(),
        font: font,
        fonts: fonts,
        title: 'Al Tahreer Neighbourhood Profile',
      ),
    ),
    StudioPdfSample(
      id: 'office-builder-report',
      kind: StudioPdfSampleKind.officeToPdf,
      titleEn: 'Docx builder situation report',
      titleAr: 'تقرير موقف من منشئ Docx',
      blurbEn: 'Fluent DocxDocumentBuilder → PDF.',
      blurbAr: 'DocxDocumentBuilder سلس → PDF.',
      fileName: 'office_builder_report.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => OfficePdfExport.fromBytes(
        _docxSituationReport(),
        font: font,
        fonts: fonts,
        title: 'Situation report',
      ),
    ),
    StudioPdfSample(
      id: 'office-rtl-letter',
      kind: StudioPdfSampleKind.officeToPdf,
      titleEn: 'RTL formal letter',
      titleAr: 'رسالة رسمية RTL',
      blurbEn: 'Right-to-left letterhead DOCX compiled to PDF.',
      blurbAr: 'رسالة بترويسة من اليمين لليسار تُترجم إلى PDF.',
      fileName: 'office_rtl_letter.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => OfficePdfExport.fromBytes(
        _rtlFormalLetter(),
        font: font,
        fonts: fonts,
        title: 'RTL letter',
      ),
    ),
    StudioPdfSample(
      id: 'office-excel-budget',
      kind: StudioPdfSampleKind.officeToPdf,
      titleEn: 'Excel budget workbook',
      titleAr: 'دفتر ميزانية Excel',
      blurbEn: 'Studio budget + roster sheets printed landscape.',
      blurbAr: 'ميزانية الاستوديو تُطبع أفقياً.',
      fileName: 'office_excel_budget.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => OfficePdfExport.workbook(
        SampleLibrary.excelBudget(),
        font: font,
        fonts: fonts,
        title: 'Studio Budget',
        options: PdfSheetPrintOptions.a4Landscape(),
      ),
    ),
    StudioPdfSample(
      id: 'office-xlsx-ops',
      kind: StudioPdfSampleKind.officeToPdf,
      titleEn: 'Ops scorecard workbook',
      titleAr: 'دفتر بطاقة أداء',
      blurbEn: 'XlsxWorkbookBuilder scorecard → PDF.',
      blurbAr: 'بطاقة أداء من XlsxWorkbookBuilder → PDF.',
      fileName: 'office_ops_scorecard.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => OfficePdfExport.fromBytes(
        _xlsxOpsScorecard(),
        font: font,
        fonts: fonts,
        title: 'Ops scorecard',
      ),
    ),
    StudioPdfSample(
      id: 'office-slide-deck',
      kind: StudioPdfSampleKind.officeToPdf,
      titleEn: 'Studio slide deck',
      titleAr: 'عرض شرائح الاستوديو',
      blurbEn: 'PowerPoint sample → PDF pages.',
      blurbAr: 'شرائح عينة → صفحات PDF.',
      fileName: 'office_slide_deck.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => OfficePdfExport.presentation(
        SampleLibrary.slideDeck(),
        font: font,
        fonts: fonts,
        title: 'Studio Deck',
      ),
    ),
    StudioPdfSample(
      id: 'office-pptx-builder',
      kind: StudioPdfSampleKind.officeToPdf,
      titleEn: 'Builder pitch deck',
      titleAr: 'عرض من منشئ الشرائح',
      blurbEn: 'PptxDeckBuilder cover + content slides → PDF.',
      blurbAr: 'شرائح من PptxDeckBuilder → PDF.',
      fileName: 'office_pitch_deck.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => OfficePdfExport.fromBytes(
        _pptxPitchDeck(),
        font: font,
        fonts: fonts,
        title: 'Pitch deck',
      ),
    ),
    StudioPdfSample(
      id: 'office-notes-pages',
      kind: StudioPdfSampleKind.officeToPdf,
      titleEn: 'Two slides per page',
      titleAr: 'شريحتان في كل صفحة',
      blurbEn: 'Every two slides export onto one A4 page.',
      blurbAr: 'كل شريحتين تُصدَّران في صفحة واحدة.',
      fileName: 'office_notes_pages.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => OfficePdfExport.presentation(
        SampleLibrary.slideDeck(),
        font: font,
        fonts: fonts,
        title: 'Two slides per page',
        mode: PdfSlideExportMode.notesPages,
        slidesPerPage: 2,
      ),
    ),
  ];

  /// Raw PDF engine / report builder samples.
  static final List<StudioPdfSample> engineSamples = <StudioPdfSample>[
    StudioPdfSample(
      id: 'engine-studio-gallery',
      kind: StudioPdfSampleKind.pdfEngine,
      titleEn: 'Studio PDF gallery (12 pages)',
      titleAr: 'معرض PDF الاستوديو (12 صفحة)',
      blurbEn: 'Cover, Arabic, charts, tables, links — PdfDocument.',
      blurbAr: 'غلاف وعربية ورسوم وجداول وروابط — PdfDocument.',
      fileName: 'engine_studio_gallery.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => studioSamplePdf(),
    ),
    StudioPdfSample(
      id: 'engine-kpi-report',
      kind: StudioPdfSampleKind.pdfEngine,
      titleEn: 'KPI operations report',
      titleAr: 'تقرير مؤشرات تشغيل',
      blurbEn: 'PdfReportBuilder: KPIs, table, bar chart.',
      blurbAr: 'PdfReportBuilder: مؤشرات وجدول ورسم بياني.',
      fileName: 'engine_kpi_report.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _kpiReport(font),
    ),
    StudioPdfSample(
      id: 'engine-memo',
      kind: StudioPdfSampleKind.pdfEngine,
      titleEn: 'Executive memo',
      titleAr: 'مذكرة تنفيذية',
      blurbEn: 'Single-page letterhead via PdfCanvas.',
      blurbAr: 'مذكرة بترويسة عبر PdfCanvas.',
      fileName: 'engine_executive_memo.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _executiveMemo(font),
    ),
    StudioPdfSample(
      id: 'engine-certificate',
      kind: StudioPdfSampleKind.pdfEngine,
      titleEn: 'Landscape certificate',
      titleAr: 'شهادة أفقية',
      blurbEn: 'Landscape PdfDocument with ornamental frame.',
      blurbAr: 'PdfDocument أفقي بإطار زخرفي.',
      fileName: 'engine_certificate.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _certificate(font),
    ),
    StudioPdfSample(
      id: 'engine-timeline',
      kind: StudioPdfSampleKind.pdfEngine,
      titleEn: 'Programme timeline',
      titleAr: 'الجدول الزمني للبرنامج',
      blurbEn: 'Multi-band timeline from the low-level writer.',
      blurbAr: 'جدول زمني من الكاتب المنخفض المستوى.',
      fileName: 'engine_timeline.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _timelinePoster(font),
    ),
  ];

  /// pdf_widgets constraint-layout samples.
  static final List<StudioPdfSample> widgetSamples = <StudioPdfSample>[
    StudioPdfSample(
      id: 'widgets-invoice',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Commercial invoice',
      titleAr: 'فاتورة تجارية',
      blurbEn: 'MultiPage invoice with table and totals.',
      blurbAr: 'فاتورة MultiPage مع جدول ومجاميع.',
      fileName: 'widgets_invoice.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _invoice(font),
    ),
    StudioPdfSample(
      id: 'widgets-proposal',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Project proposal',
      titleAr: 'مقترح مشروع',
      blurbEn: 'Long-form MultiPage proposal.',
      blurbAr: 'مقترح مطوّل MultiPage.',
      fileName: 'widgets_proposal.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _proposal(font),
    ),
    StudioPdfSample(
      id: 'widgets-quarterly',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Quarterly briefing',
      titleAr: 'إحاطة ربع سنوية',
      blurbEn: 'KPIs and narrative via pdf_widgets.',
      blurbAr: 'مؤشرات وسرد عبر pdf_widgets.',
      fileName: 'widgets_quarterly.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _quarterly(font),
    ),
    StudioPdfSample(
      id: 'widgets-agenda',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Board meeting agenda',
      titleAr: 'جدول أعمال اجتماع',
      blurbEn: 'Timed agenda with attendees block.',
      blurbAr: 'جدول أعمال موقوت مع حضور.',
      fileName: 'widgets_meeting_agenda.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _meetingAgenda(font),
    ),
    StudioPdfSample(
      id: 'widgets-dossier',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Neighbourhood dossier card',
      titleAr: 'بطاقة ملف حيّ',
      blurbEn: 'Two-column dossier (facts + narrative).',
      blurbAr: 'ملف عمودين (حقائق + سرد).',
      fileName: 'widgets_dossier.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => _dossierCard(font),
    ),
    StudioPdfSample(
      id: 'widgets-cairo-quarterly',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Cairo — quarterly report',
      titleAr: 'Cairo — تقرير ربع سنوي',
      blurbEn:
          'Arabic title, heading, and body in Cairo, with an English LTR panel.',
      blurbAr: 'عنوان وفقرة عربية بخط Cairo مع لوحة إنجليزية LTR.',
      fileName: 'widgets_cairo_quarterly.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) =>
          studioCairoQuarterlyPdf(),
    ),
    StudioPdfSample(
      id: 'widgets-tajawal-briefing',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Tajawal — bilingual briefing',
      titleAr: 'Tajawal — إحاطة ثنائية اللغة',
      blurbEn:
          'English title, heading, and body in Tajawal, with an Arabic RTL panel.',
      blurbAr: 'عنوان وفقرة إنجليزية بخط Tajawal مع لوحة عربية RTL.',
      fileName: 'widgets_tajawal_briefing.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) =>
          studioTajawalBriefingPdf(),
    ),
    StudioPdfSample(
      id: 'widgets-atlas',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Widget atlas',
      titleAr: 'أطلس الأدوات',
      blurbEn: 'Charts, table, checklist, chips, watermark, and an Arabic page.',
      blurbAr: 'رسوم وجدول وقائمة وشرائح وعلامة مائية وصفحة عربية.',
      fileName: 'widgets_atlas.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => studioWidgetAtlasPdf(),
    ),
    StudioPdfSample(
      id: 'widgets-field-clinic',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Field clinic day sheet',
      titleAr: 'كشف عيادة ميدانية',
      blurbEn: 'Arabic Cairo clinic roster, chart, and pharmacy checklist.',
      blurbAr: 'كشف عيادة بالقاهرة مع رسم بياني وقائمة صيدلية.',
      fileName: 'widgets_field_clinic.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => studioFieldClinicPdf(),
    ),
    StudioPdfSample(
      id: 'widgets-board-packet',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Board packet',
      titleAr: 'حزمة مجلس الإدارة',
      blurbEn: 'Agenda, decisions, budget table, spend chart, Arabic minutes.',
      blurbAr: 'جدول أعمال وقرارات وميزانية ورسم إنفاق ومحضر عربي.',
      fileName: 'widgets_board_packet.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => studioBoardPacketPdf(),
    ),
    StudioPdfSample(
      id: 'widgets-recovery-brief',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Recovery corridor',
      titleAr: 'ممر التعافي',
      blurbEn: 'Neighbourhood cards, access chart, and an Arabic note.',
      blurbAr: 'بطاقات أحياء ورسم وصول إلى المياه وملاحظة عربية.',
      fileName: 'widgets_recovery_brief.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) =>
          studioRecoveryBriefPdf(),
    ),
    StudioPdfSample(
      id: 'widgets-contents-guide',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Contents guide',
      titleAr: 'دليل المحتويات',
      blurbEn: 'Table of contents. Hover a row to preview the landing page.',
      blurbAr: 'فهرس. مرّر فوق البند لترى الصفحة التي يفتحها.',
      fileName: 'widgets_contents_guide.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) =>
          studioContentsGuidePdf(),
    ),
    StudioPdfSample(
      id: 'widgets-arabic-contents',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Arabic contents',
      titleAr: 'فهرس عربي',
      blurbEn: 'Arabic table of contents with links into later pages.',
      blurbAr: 'فهرس عربي وروابطه تفتح الصفحات التالية.',
      fileName: 'widgets_arabic_contents.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) =>
          studioArabicContentsPdf(),
    ),
    StudioPdfSample(
      id: 'widgets-flutter-twins',
      kind: StudioPdfSampleKind.pdfWidgets,
      titleEn: 'Flutter twins',
      titleAr: 'توائم Flutter',
      blurbEn:
          'Transform, clip, slots, ellipsis, and a right-to-left pin page.',
      blurbAr: 'تدوير وقص وفتحات وقطع، ثم صفحة تثبيت من اليمين.',
      fileName: 'widgets_flutter_twins.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) =>
          studioFlutterTwinsPdf(),
    ),
  ];

  /// One bilingual sample per catalog template. Page 1 English, page 2 Arabic.
  static List<StudioPdfSample> get templateSamples => <StudioPdfSample>[
        for (final tpl.TemplateRef ref in tpl.TemplateCatalog.all)
          StudioPdfSample(
            id: 'templates-${ref.id}',
            kind: StudioPdfSampleKind.templates,
            group: ref.category.name,
            titleEn: ref.nameEn,
            titleAr: ref.nameAr,
            blurbEn: 'English page, then Arabic. ${ref.blurbEn}',
            blurbAr: 'صفحة إنجليزية ثم عربية. ${ref.blurbAr}',
            fileName: 'templates_${ref.id.replaceAll('.', '_')}.pdf',
            build: ({SfntFont? font, OfficeFontSet? fonts}) =>
                studioTemplatePair(ref.id),
          ),
      ];

  /// Sub-tabs under the templates section, in catalog order.
  static const List<String> templateGroups = <String>[
    'commerce',
    'finance',
    'people',
    'operations',
    'narrative',
    'data',
    'education',
    'property',
    'logistics',
    'programs',
  ];

  /// Localized name for a template sub-tab.
  static String templateGroupTitle(String group, bool arabic) {
    return switch (group) {
      'commerce' => arabic ? 'تجارة' : 'Commerce',
      'finance' => arabic ? 'مال' : 'Finance',
      'people' => arabic ? 'أشخاص' : 'People',
      'operations' => arabic ? 'تشغيل' : 'Operations',
      'narrative' => arabic ? 'سرد' : 'Narrative',
      'data' => arabic ? 'بيانات' : 'Data',
      'education' => arabic ? 'تعليم' : 'Education',
      'property' => arabic ? 'عقار' : 'Property',
      'logistics' => arabic ? 'شحن' : 'Logistics',
      'programs' => arabic ? 'برامج' : 'Programs',
      _ => group,
    };
  }

  /// Distinct bilingual documents for the gallery's first tab.
  static final List<StudioPdfSample> showcaseSamples = <StudioPdfSample>[
    StudioPdfSample(
      id: 'showcase-harbour-close',
      kind: StudioPdfSampleKind.showcase,
      titleEn: 'Harbour close',
      titleAr: 'إغلاق الميناء',
      blurbEn:
          'English night ledger: gradient, charts, and a table that spans pages.',
      blurbAr: 'دفتر إنجليزي: تدرج ورسوم وجدول يمتد عبر الصفحات.',
      fileName: 'showcase_harbour_close.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => studioHarbourClosePdf(),
    ),
    StudioPdfSample(
      id: 'showcase-layl-al-qamar',
      kind: StudioPdfSampleKind.showcase,
      titleEn: 'Night of al-Qamar',
      titleAr: 'ليل القمر',
      blurbEn: 'Arabic Tajawal ledger with a repeated header on the next page.',
      blurbAr: 'دفتر عربي بتجوال، وصف العناوين يعود في الصفحة التالية.',
      fileName: 'showcase_layl_al_qamar.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => studioLaylAlQamarPdf(),
    ),
    StudioPdfSample(
      id: 'showcase-two-shores',
      kind: StudioPdfSampleKind.showcase,
      titleEn: 'Two shores',
      titleAr: 'ضفتان',
      blurbEn: 'Landscape sheet: English quay beside an Arabic quay.',
      blurbAr: 'ورقة أفقية: رصيف إنجليزي بجانب رصيف عربي.',
      fileName: 'showcase_two_shores.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => studioTwoShoresPdf(),
    ),
    StudioPdfSample(
      id: 'showcase-cairo-night',
      kind: StudioPdfSampleKind.showcase,
      titleEn: 'Cairo night clinic',
      titleAr: 'ليل عيادة القاهرة',
      blurbEn: 'Arabic Cairo close, then a short English hand-off page.',
      blurbAr: 'إغلاق عربي بخط Cairo ثم صفحة تسليم إنجليزية.',
      fileName: 'showcase_cairo_night.pdf',
      build: ({SfntFont? font, OfficeFontSet? fonts}) => studioCairoNightPdf(),
    ),
  ];

  /// Category label.
  static String kindTitle(StudioPdfSampleKind kind, bool arabic) {
    return switch (kind) {
      StudioPdfSampleKind.officeToPdf =>
        arabic ? 'أوفيس ← PDF' : 'Office → PDF',
      StudioPdfSampleKind.pdfEngine => arabic ? 'محرك PDF' : 'PDF engine',
      StudioPdfSampleKind.pdfWidgets =>
        arabic ? 'pdf_widgets' : 'pdf_widgets',
      StudioPdfSampleKind.templates =>
        arabic ? 'قوالب التقارير' : 'Report templates',
      StudioPdfSampleKind.showcase => arabic ? 'عرض ثنائي' : 'Showcase',
    };
  }

  /// Category subtitle.
  static String kindBlurb(StudioPdfSampleKind kind, bool arabic) {
    return switch (kind) {
      StudioPdfSampleKind.officeToPdf => arabic
          ? 'Word / Excel / PowerPoint تُنشأ ثم تُحوَّل إلى PDF.'
          : 'Build Word / Excel / PowerPoint, then compile to PDF.',
      StudioPdfSampleKind.pdfEngine => arabic
          ? 'PdfDocument و PdfReportBuilder مباشرة.'
          : 'PdfDocument and PdfReportBuilder directly.',
      StudioPdfSampleKind.pdfWidgets => arabic
          ? 'تخطيط قيود شبيه بـ Flutter.'
          : 'Flutter-like constraint layout composer.',
      StudioPdfSampleKind.templates => arabic
          ? 'كل قالب صفحتان: إنجليزية ثم عربية. الشرائح تصنّف المجالات.'
          : 'Each template is two pages: English, then Arabic. Chips classify the domains.',
      StudioPdfSampleKind.showcase => arabic
          ? 'عربي وإنجليزي: تدرج ورسوم وجداول تمتد.'
          : 'Arabic and English: gradients, charts, spanning tables.',
    };
  }
}

Uint8List _docxSituationReport() {
  final DocxDocumentBuilder doc = DocxDocumentBuilder()
    ..heading('Situation report — Zone A')
    ..note('Studio sample  ·  DocxDocumentBuilder  ·  11 Sep 2026')
    ..paragraph(
      'Clearance teams advanced along the primary corridor. '
      'Household registration remains the binding constraint for '
      'rental-subsidy targeting. Partners confirmed equipment for a '
      'two-week surge starting 15 September.',
    )
    ..heading('Priorities', level: 2)
    ..paragraph('1. Finalize surge roster and vendor slots.')
    ..paragraph('2. Release contingency draw-down (cap USD 180k).')
    ..paragraph('3. Schedule joint field verification on 18 Sep.')
    ..heading('Risks', level: 2)
    ..paragraph(
      'Access windows may compress if security advisories escalate. '
      'Cold-chain power at the clinic is intermittent after 18:00.',
    );
  return doc.build();
}

Uint8List _rtlFormalLetter() {
  final DocxDocumentBuilder doc = DocxDocumentBuilder(rtl: true)
    ..heading('مذكرة رسمية')
    ..note('خلية التعافي القائم على المنطقة  ·  ١١ أيلول ٢٠٢٦')
    ..paragraph(
      'نرجو اعتماد خطة التسريع لمدة أسبوعين لفرق إزالة الركام في المنطقة أ، '
      'مصحوبة بدعم إيجار مؤقت لمائتين وأربعين أسرة. التمويل خصّص بند الطوارئ، '
      'والشركاء أكدوا توفر المعدات اعتباراً من ١٥ أيلول.',
    )
    ..heading('القرارات المطلوبة', level: 2)
    ..paragraph('الموافقة على قائمة التسريع.')
    ..paragraph('تحرير السحب من بند الطوارئ.')
    ..paragraph('تحديد موعد التحقق الميداني.');
  return doc.build();
}

Uint8List _xlsxOpsScorecard() {
  final XlsxWorkbookBuilder book = XlsxWorkbookBuilder();
  final int head = book.style(
    bold: true,
    fillRgb: '1A237E',
    color: 'FFFFFFFF',
    border: true,
  );
  final int cell = book.style(border: true);
  final XlsxSheetBuilder sheet = book.addSheet('Scorecard');
  final List<List<String>> rows = <List<String>>[
    <String>['Cluster', 'Health', 'WASH', 'Shelter', 'Priority'],
    <String>['Al Tahreer', '62', '71', '54', 'High'],
    <String>['Al Amal', '58', '66', '49', 'High'],
    <String>['Zone A', '74', '80', '68', 'Medium'],
    <String>['Khan Younis', '51', '59', '47', 'Critical'],
  ];
  for (int r = 0; r < rows.length; r++) {
    sheet.addRow(rows[r], style: r == 0 ? head : cell);
  }
  sheet.colWidth(0, 16);
  for (int c = 1; c < 5; c++) {
    sheet.colWidth(c, 12);
  }
  return book.build();
}

Uint8List _pptxPitchDeck() {
  final PptxDeckBuilder deck = PptxDeckBuilder()
    ..addCoverSlide(
      title: 'Quds Office Suite',
      kicker: 'PDF SAMPLE LAB',
      subtitle: 'Office export · engine writer · pdf_widgets',
      footer: 'Studio experimental gallery',
      notes: 'Pitch cover for export fidelity.',
    )
    ..addTitleBodySlide(
      title: 'Three composition paths',
      bullets: <String>[
        'Office → PDF via OfficePdfExport',
        'PdfDocument / PdfReportBuilder writer',
        'pdf_widgets constraint layout',
      ],
    );
  return deck.build();
}

Uint8List _kpiReport(SfntFont? font) {
  final PdfReportBuilder report = PdfReportBuilder(
    font: font,
    title: 'Operations KPI',
    author: 'Quds Studio',
    header: 'Quds Office  ·  Confidential',
    footer: 'Generated for PDF viewer samples',
  )
    ..titleText('Neighbourhood recovery — Q3 snapshot')
    ..body(
      'Key service indicators for Al Amal and Al Tahreer clusters. '
      'Figures are illustrative studio data for export fidelity checks.',
    )
    ..spacer(height: 10)
    ..kpiRow(<({String label, String value})>[
      (label: 'Households surveyed', value: '4,280'),
      (label: 'Shelters stabilized', value: '61%'),
      (label: 'Water access', value: '73%'),
      (label: 'Open workstreams', value: '18'),
    ])
    ..spacer()
    ..heading('Cluster scorecard')
    ..table(<List<String>>[
      <String>['Cluster', 'Health', 'WASH', 'Shelter', 'Priority'],
      <String>['Al Tahreer', '62', '71', '54', 'High'],
      <String>['Al Amal N.', '58', '66', '49', 'High'],
      <String>['Zone A', '74', '80', '68', 'Medium'],
      <String>['Khan Younis', '51', '59', '47', 'Critical'],
    ])
    ..spacer()
    ..heading('Monthly caseload')
    ..barChart(<ChartPoint>[
      const ChartPoint(label: 'Apr', value: 42),
      const ChartPoint(label: 'May', value: 55),
      const ChartPoint(label: 'Jun', value: 61),
      const ChartPoint(label: 'Jul', value: 70),
      const ChartPoint(label: 'Aug', value: 66),
      const ChartPoint(label: 'Sep', value: 78),
    ])
    ..spacer()
    ..heading('Notes')
    ..body(
      'Shelter scores remain constrained by debris clearance queues. '
      'WASH gains track tanker rotations and repaired network segments.',
    );
  return report.build();
}

Uint8List _executiveMemo(SfntFont? font) {
  // PdfCanvas uses top-left document space (Y grows downward).
  final PdfDocument doc = PdfDocument(
    title: 'Executive memo',
    author: 'Quds Studio',
  );
  final PdfCanvas c = PdfCanvas(595.28, 841.89)
    ..setFillColor('1B3A4B')
    ..rect(0, 0, 595.28, 62)
    ..fill()
    ..showLatin(
      x: 48,
      y: 38,
      fontSize: 16,
      text: 'QUDS OFFICE  ·  EXECUTIVE MEMO',
      color: 'FFFFFF',
    )
    ..showLatin(
      x: 48,
      y: 96,
      fontSize: 11,
      text: 'To: Programme board',
      color: '263238',
    )
    ..showLatin(
      x: 48,
      y: 112,
      fontSize: 11,
      text: 'From: Area-based recovery cell',
      color: '263238',
    )
    ..showLatin(
      x: 48,
      y: 128,
      fontSize: 11,
      text: 'Date: 11 Sep 2026   ·   Ref: ABR-MEMO-0911',
      color: '263238',
    )
    ..setStrokeColor('C0392B')
    ..setLineWidth(1.2)
    ..moveTo(48, 148)
    ..lineTo(547, 148)
    ..stroke()
    ..showLatin(
      x: 48,
      y: 178,
      fontSize: 14,
      text: 'Subject: Accelerating debris-to-shelter pathways',
      color: '1B3A4B',
    );
  const String body =
      'Please endorse the two-week surge plan for Zone A clearance teams, '
      'paired with temporary rental subsidies for 240 households. '
      'Finance has ring-fenced the contingency line; partners confirmed '
      'equipment availability from 15 Sep.';
  _wrapLatin(c, body, 48, 208, 500, 11, '37474F');
  c
    ..showLatin(
      x: 48,
      y: 320,
      fontSize: 11,
      text: 'Requested decision',
      color: '1B3A4B',
    )
    ..showLatin(
      x: 48,
      y: 342,
      fontSize: 11,
      text: '1. Approve surge roster (Annex A)',
      color: '455A64',
    )
    ..showLatin(
      x: 48,
      y: 360,
      fontSize: 11,
      text: '2. Release contingency draw-down (max USD 180k)',
      color: '455A64',
    )
    ..showLatin(
      x: 48,
      y: 378,
      fontSize: 11,
      text: '3. Schedule field verification on 18 Sep',
      color: '455A64',
    )
    ..showLatin(
      x: 48,
      y: 800,
      fontSize: 9,
      text: 'Quds Studio sample  ·  PdfCanvas letterhead',
      color: '90A4AE',
    );
  doc.addPage(
    PdfPage(width: 595.28, height: 841.89, content: c.toStream()),
  );
  return doc.save(font: font);
}

Uint8List _certificate(SfntFont? font) {
  const double w = 842;
  const double h = 595;
  final PdfDocument doc = PdfDocument(
    title: 'Certificate of participation',
    author: 'Quds Studio',
  );
  final PdfCanvas c = PdfCanvas(w, h)
    ..setStrokeColor('1A237E')
    ..setLineWidth(3)
    ..rect(28, 28, w - 56, h - 56)
    ..stroke()
    ..setStrokeColor('C9A227')
    ..setLineWidth(1)
    ..rect(36, 36, w - 72, h - 72)
    ..stroke()
    ..showLatin(
      x: 80,
      y: 100,
      fontSize: 12,
      text: 'QUDS OFFICE SUITE  ·  LEARNING LAB',
      color: '5C6BC0',
    )
    ..showLatin(
      x: 80,
      y: 160,
      fontSize: 28,
      text: 'Certificate of Participation',
      color: '1A237E',
    )
    ..showLatin(
      x: 80,
      y: 210,
      fontSize: 12,
      text: 'This certifies that',
      color: '607D8B',
    )
    ..showLatin(
      x: 80,
      y: 250,
      fontSize: 22,
      text: 'Neighbourhood Profile Fellows — Cohort 2026',
      color: '263238',
    )
    ..showLatin(
      x: 80,
      y: 300,
      fontSize: 12,
      text:
          'completed the studio workshop on PDF composition, Office export,',
      color: '455A64',
    )
    ..showLatin(
      x: 80,
      y: 318,
      fontSize: 12,
      text: 'and interactive viewing with Quds Office Suite.',
      color: '455A64',
    )
    ..showLatin(
      x: 80,
      y: 480,
      fontSize: 11,
      text: 'Director, Learning Lab',
      color: '78909C',
    )
    ..showLatin(
      x: 420,
      y: 480,
      fontSize: 11,
      text: '11 September 2026',
      color: '78909C',
    );
  doc.addPage(PdfPage(width: w, height: h, content: c.toStream()));
  return doc.save(font: font);
}

Uint8List _timelinePoster(SfntFont? font) {
  final PdfDocument doc = PdfDocument(
    title: 'Programme timeline',
    author: 'Quds Studio',
  );
  final PdfCanvas c = PdfCanvas(595.28, 841.89)
    ..setFillColor('0D47A1')
    ..rect(0, 0, 595.28, 82)
    ..fill()
    ..showLatin(
      x: 40,
      y: 36,
      fontSize: 18,
      text: 'Area-based recovery roadmap',
      color: 'FFFFFF',
    )
    ..showLatin(
      x: 40,
      y: 58,
      fontSize: 10,
      text: 'Al Tahreer  ·  18-month horizon  ·  studio sample',
      color: 'BBDEFB',
    );
  final List<({String t, String d, String hex})> phases =
      <({String t, String d, String hex})>[
    (t: '0-3 mo', d: 'Debris surge · household registry', hex: 'E53935'),
    (t: '3-6 mo', d: 'WASH repairs · rental support', hex: 'FB8C00'),
    (t: '6-12 mo', d: 'Shelter kits · livelihood grants', hex: '43A047'),
    (t: '12-18 mo', d: 'Public realm · exit to municipal', hex: '1E88E5'),
  ];
  var y = 140.0;
  for (final ({String t, String d, String hex}) phase in phases) {
    c
      ..setFillColor(phase.hex)
      ..rect(40, y - 2, 12, 12)
      ..fill()
      ..showLatin(x: 64, y: y + 8, fontSize: 13, text: phase.t, color: '212121')
      ..showLatin(x: 150, y: y + 8, fontSize: 12, text: phase.d, color: '546E7A');
    if (phase != phases.last) {
      c
        ..setStrokeColor('B0BEC5')
        ..setLineWidth(2)
        ..moveTo(46, y + 14)
        ..lineTo(46, y + 48)
        ..stroke();
    }
    y += 56;
  }
  c
    ..showLatin(
      x: 40,
      y: y + 24,
      fontSize: 12,
      text: 'Cross-cutting tracks',
      color: '0D47A1',
    )
    ..showLatin(
      x: 40,
      y: y + 48,
      fontSize: 11,
      text: '- Protection mainstreaming across all phases',
      color: '455A64',
    )
    ..showLatin(
      x: 40,
      y: y + 66,
      fontSize: 11,
      text: '- Partner coordination cell (weekly)',
      color: '455A64',
    )
    ..showLatin(
      x: 40,
      y: y + 84,
      fontSize: 11,
      text: '- Evidence updates to the neighbourhood profile',
      color: '455A64',
    );
  doc.addPage(
    PdfPage(width: 595.28, height: 841.89, content: c.toStream()),
  );
  return doc.save(font: font);
}

Uint8List _invoice(SfntFont? font) {
  final pw.Document doc = pw.Document(
    title: 'Invoice INV-2026-0911',
    author: 'Quds Studio',
    font: font,
    fontBold: StudioFiles.latinExportBoldFont(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
      header: (pw.Context context) => pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              'QUDS OFFICE',
              style: const pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: '1A237E',
                letterSpacing: 1.2,
              ),
            ),
          ),
          pw.Text(
            'INVOICE',
            style: const pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: '1A237E',
            ),
          ),
        ],
      ),
      build: (pw.Context context) => <pw.Widget>[
        pw.SizedBox(height: 12),
        pw.Row(
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                children: <pw.Widget>[
                  pw.Text(
                    'Bill to',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: '78909C',
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Northwind Recovery Desk',
                    style: const pw.TextStyle(fontSize: 10, color: '37474F'),
                  ),
                  pw.Text(
                    'Gaza coordination cell',
                    style: const pw.TextStyle(fontSize: 10, color: '37474F'),
                  ),
                ],
              ),
            ),
            pw.Container(
              width: 200,
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(
                color: 'F3F6FB',
                borderRadius: 4,
              ),
              child: pw.Column(
                children: <pw.Widget>[
                  _meta('Invoice', 'INV-2026-0911'),
                  _meta('Issued', '11 September 2026'),
                  _meta('Due', '25 September 2026'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Table.fromTextArray(
          headers: const <String>['Description', 'Qty', 'Rate', 'Amount'],
          columnWidths: const <double>[3.4, 0.7, 0.9, 1.0],
          headerDecoration: '1A237E',
          cellAlignments: const <int, pw.Alignment>{
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          headerAlignments: const <int, pw.Alignment>{
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          data: const <List<String>>[
            <String>['Platform license — Engine (annual)', '1', '2,400', '2,400'],
            <String>['Editor seats', '8', '180', '1,440'],
            <String>['PDF file stack', '1', '950', '950'],
            <String>['Priority support', '1', '420', '420'],
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Amount due: 5,210.00',
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: '1A237E',
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        const pw.Bullet(text: 'Payable within 14 days. Reference the invoice number.'),
        const pw.Bullet(text: 'Generated with pdf_widgets MultiPage + Table.'),
      ],
    ),
  );
  return doc.save();
}

Uint8List _proposal(SfntFont? font) {
  final pw.Document doc = pw.Document(
    title: 'Recovery proposal',
    author: 'Quds Studio',
    font: font,
    fontBold: StudioFiles.latinExportBoldFont(),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (pw.Context context) => <pw.Widget>[
        pw.Text(
          'PROPOSAL',
          style: const pw.TextStyle(
            fontSize: 11,
            color: 'C0392B',
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Area-based recovery support for Al Tahreer',
          style: const pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: '1B3A4B',
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'A twelve-month partnership to restore shelter corridors, WASH '
          'reliability, and neighbourhood evidence systems.',
          style: const pw.TextStyle(fontSize: 11, color: '546E7A'),
        ),
        pw.SizedBox(height: 18),
        pw.Header(level: 2, text: 'Objectives'),
        const pw.Bullet(text: 'Stabilize 60% of grade 3–4 shelters within six months.'),
        const pw.Bullet(text: 'Restore primary tanker corridors and clinic power.'),
        const pw.Bullet(text: 'Publish quarterly neighbourhood scorecards.'),
        pw.SizedBox(height: 12),
        pw.Header(level: 2, text: 'Workstreams'),
        pw.Paragraph(
          text:
              'Debris-to-shelter sequencing, WASH network repairs, protection '
              'mainstreaming, and municipal hand-over planning. Each workstream '
              'carries a results framework aligned to the neighbourhood dossier.',
        ),
        pw.SizedBox(height: 12),
        pw.Header(level: 2, text: 'Budget envelope'),
        pw.Table.fromTextArray(
          headers: const <String>['Line', 'USD'],
          data: const <List<String>>[
            <String>['Shelter kits & labour', '420,000'],
            <String>['WASH repairs', '210,000'],
            <String>['Evidence & coordination', '85,000'],
            <String>['Contingency (10%)', '71,500'],
          ],
          headerDecoration: '1B3A4B',
          columnWidths: const <double>[3, 1.2],
          cellAlignments: const <int, pw.Alignment>{
            1: pw.Alignment.centerRight,
          },
          headerAlignments: const <int, pw.Alignment>{
            1: pw.Alignment.centerRight,
          },
        ),
      ],
    ),
  );
  return doc.save();
}

Uint8List _quarterly(SfntFont? font) {
  final pw.Document doc = pw.Document(
    title: 'Quarterly briefing',
    author: 'Quds Studio',
    font: font,
    fontBold: StudioFiles.latinExportBoldFont(),
  );
  doc.addPage(
    pw.Page(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Text(
            'Q3 BRIEFING',
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: '1565C0',
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Service access and caseload trends',
            style: const pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: '0D47A1',
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: <pw.Widget>[
              _kpiTile('Households', '4,280'),
              pw.SizedBox(width: 10),
              _kpiTile('Water access', '73%'),
              pw.SizedBox(width: 10),
              _kpiTile('Open cases', '18'),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Narrative',
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: '0D47A1',
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Caseload rose through mid-summer as clearance opened new pockets '
            'of return. WASH tanker rotations offset network outages; shelter '
            'kits trailed debris removal by roughly two weeks.',
            style: const pw.TextStyle(
              fontSize: 10,
              color: '37474F',
              lineSpacing: 1.35,
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _kpiTile(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: 'E3F2FD',
        borderRadius: 4,
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: '0D47A1',
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: '5472A3'),
          ),
        ],
      ),
    ),
  );
}

Uint8List _meetingAgenda(SfntFont? font) {
  final pw.Document doc = pw.Document(
    title: 'Board agenda',
    author: 'Quds Studio',
    font: font,
    fontBold: StudioFiles.latinExportBoldFont(),
  );
  doc.addPage(
    pw.Page(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Text(
            'BOARD MEETING AGENDA',
            style: const pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: '1A237E',
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Area-based recovery  ·  14 Sep 2026  ·  10:00-12:30',
            style: const pw.TextStyle(fontSize: 10, color: '607D8B'),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(
              color: 'E8EAF6',
              borderRadius: 4,
            ),
            child: pw.Text(
              'Attendees: Programme director, WASH lead, Shelter lead, '
              'Finance, Municipal liaison, UN-Habitat (observer).',
              style: const pw.TextStyle(fontSize: 9, color: '283593'),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Table.fromTextArray(
            headers: <String>['Time', 'Item', 'Owner', 'Decision'],
            data: <List<String>>[
              <String>['10:00', 'Opening & conflict check', 'Chair', '-'],
              <String>['10:15', 'Debris surge plan', 'Shelter', 'Endorse'],
              <String>['10:45', 'WASH tanker rotations', 'WASH', 'Note'],
              <String>['11:15', 'Budget contingency', 'Finance', 'Approve'],
              <String>['11:45', 'Municipal hand-over path', 'Liaison', 'Discuss'],
              <String>['12:15', 'AOB & close', 'Chair', '-'],
            ],
            headerDecoration: '1A237E',
            cellStyle: const pw.TextStyle(fontSize: 9, color: '37474F'),
            columnWidths: const <double>[0.9, 2.4, 1.0, 1.0],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Papers circulated',
            style: const pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: '1A237E',
            ),
          ),
          pw.SizedBox(height: 6),
          const pw.Bullet(text: 'Annex A — Surge roster and equipment list'),
          const pw.Bullet(text: 'Annex B — Contingency draw-down memo'),
          const pw.Bullet(text: 'Annex C — Updated neighbourhood scorecard'),
        ],
      ),
    ),
  );
  return doc.save();
}

Uint8List _dossierCard(SfntFont? font) {
  final pw.Document doc = pw.Document(
    title: 'Neighbourhood dossier',
    author: 'Quds Studio',
    font: font,
    fontBold: StudioFiles.latinExportBoldFont(),
  );
  doc.addPage(
    pw.Page(
      pageFormat: pw.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Container(
            color: 'B71C1C',
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: pw.Row(
              children: <pw.Widget>[
                pw.Expanded(
                  child: pw.Text(
                    'AL TAHREER  ·  NEIGHBOURHOOD DOSSIER',
                    style: const pw.TextStyle(
                      color: 'FFFFFF',
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                pw.Text(
                  'CONFIDENTIAL',
                  style: const pw.TextStyle(
                    color: 'FFCDD2',
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: <pw.Widget>[
                    pw.Text(
                      'Context',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: 'B71C1C',
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Al Tahreer sits within Khan Younis municipal boundaries. '
                      'Pre-war density, mixed residential fabric, and disrupted '
                      'networks define the recovery sequence.',
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: '37474F',
                        lineSpacing: 1.35,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Operational priorities',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: 'B71C1C',
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    const pw.Bullet(text: 'Clear primary corridors for tankers'),
                    const pw.Bullet(text: 'Stabilize partially damaged shelters'),
                    const pw.Bullet(text: 'Restore clinic cold-chain power'),
                    const pw.Bullet(text: 'Update household vulnerability registry'),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: 'FFCDD2'),
                    color: 'FAFAFA',
                  ),
                  child: pw.Column(
                    children: <pw.Widget>[
                      pw.Text(
                        'At a glance',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: 'B71C1C',
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _fact('Population (est.)', '28,400'),
                      _fact('Households', '4,280'),
                      _fact('Damage grade 3-4', '39%'),
                      _fact('Water network', 'Partial'),
                      _fact('Primary health', 'Mobile + clinic'),
                      _fact('Education', '2 sites hosting'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _fact(String k, String v) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Text(
            k,
            style: const pw.TextStyle(fontSize: 9, color: '78909C'),
          ),
        ),
        pw.Text(
          v,
          style: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: '263238',
          ),
        ),
      ],
    ),
  );
}

pw.Widget _meta(String k, String v) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      children: <pw.Widget>[
        pw.SizedBox(
          width: 62,
          child: pw.Text(
            k.toUpperCase(),
            style: const pw.TextStyle(fontSize: 8, color: '78909C'),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            v,
            style: const pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: '263238',
            ),
          ),
        ),
      ],
    ),
  );
}

void _wrapLatin(
  PdfCanvas canvas,
  String text,
  double x,
  double y,
  double maxW,
  double size,
  String color,
) {
  final List<String> words = text.split(RegExp(r'\s+'));
  final StringBuffer line = StringBuffer();
  var cy = y;
  double measure(String s) => s.length * size * 0.48;
  for (final String word in words) {
    final String next = line.isEmpty ? word : '$line $word';
    if (measure(next) > maxW && line.isNotEmpty) {
      canvas.showLatin(
        x: x,
        y: cy,
        fontSize: size,
        text: line.toString(),
        color: color,
      );
      line
        ..clear()
        ..write(word);
      cy += size * 1.35;
    } else {
      line
        ..clear()
        ..write(next);
    }
  }
  if (line.isNotEmpty) {
    canvas.showLatin(
      x: x,
      y: cy,
      fontSize: size,
      text: line.toString(),
      color: color,
    );
  }
}
