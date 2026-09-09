/// Flutter-like Word document widgets, matching `package:pdf/widgets.dart`.
///
/// ```dart
/// import 'package:quds_office_engine/word_widgets.dart' as ww;
///
/// final doc = ww.Document();
/// doc.addPage(
///   ww.MultiPage(
///     pageFormat: ww.PdfPageFormat.a4,
///     build: (context) => <ww.Widget>[
///       ww.Header(level: 1, text: 'Title'),
///       ww.Paragraph(text: 'Hello'),
///     ],
///   ),
/// );
/// final bytes = await doc.save();
/// ```
library;

export 'src/builders/office_markup.dart' show ChartPoint;
export 'src/visual/office_visual.dart' show OfficeVisualKind;
export 'src/word/widgets/widgets.dart';
