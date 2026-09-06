import '../word/model/wml_document.dart';
import '../word/properties/wml_properties.dart';

/// Shared typeface names, sizes, and script helpers for Word and PDF.
abstract final class OfficeTypeface {
  static const List<String> families = <String>[
    'Calibri',
    'Arial',
    'Times New Roman',
    'Noto Naskh Arabic',
    'Noto Sans Arabic',
    'Tajawal',
    'Tahoma',
    'Georgia',
    'Courier New',
    'Liberation Sans',
    'Liberation Serif',
  ];

  static const List<int> sizesPt = <int>[
    8,
    9,
    10,
    11,
    12,
    14,
    16,
    18,
    20,
    22,
    24,
    26,
    28,
    36,
    48,
    72,
  ];

  static const String arabicTheme = 'Noto Naskh Arabic';
  static const String latinTheme = 'Calibri';

  static bool isArabicFamily(String family) {
    final String lower = family.toLowerCase();
    return lower.contains('arabic') ||
        lower.contains('naskh') ||
        lower.contains('kufi') ||
        lower.contains('tajawal') ||
        lower.contains('amiri') ||
        lower.contains('scheherazade');
  }

  /// Default OOXML faces that Word paints with the document theme instead.
  static bool isThemePlaceholder(String family) {
    final String lower = family.toLowerCase();
    return lower == 'calibri' ||
        lower == 'arial' ||
        lower == 'carlito' ||
        lower.isEmpty;
  }

  static bool isRtlText(String text) {
    for (final int cp in text.runes) {
      if (isRtlCodePoint(cp)) {
        return true;
      }
    }
    return false;
  }

  static bool isRtlCodePoint(int cp) {
    return (cp >= 0x0590 && cp <= 0x08FF) ||
        (cp >= 0xFB1D && cp <= 0xFDFF) ||
        (cp >= 0xFE70 && cp <= 0xFEFF);
  }

  static String paintFamily({
    required String text,
    String? runFamily,
    String? themeFamily,
  }) {
    if (runFamily != null &&
        runFamily.isNotEmpty &&
        !(isRtlText(text) && isThemePlaceholder(runFamily))) {
      return runFamily;
    }
    if (isRtlText(text)) {
      return themeFamily ?? arabicTheme;
    }
    if (runFamily != null && runFamily.isNotEmpty) {
      return runFamily;
    }
    return latinTheme;
  }

  static String familyForRun(WmlRunProps props, int codePoint) {
    return isRtlCodePoint(codePoint) ? props.csFont : props.asciiFont;
  }

  static bool documentHasRtl(WmlDocument document) {
    for (final WmlParagraph paragraph in document.paragraphs) {
      if (isRtlText(paragraph.text)) {
        return true;
      }
    }
    return false;
  }

  static String preferredExportFamily(
    WmlDocument document, {
    String? themeFamily,
  }) {
    String? chosen;
    var hasRtl = false;
    for (final WmlParagraph paragraph in document.paragraphs) {
      if (isRtlText(paragraph.text)) {
        hasRtl = true;
      }
      for (final WmlInline inline in paragraph.inlines) {
        if (inline is! WmlRun) {
          continue;
        }
        final WmlRunProps props = inline.properties;
        if (isRtlText(inline.text)) {
          hasRtl = true;
          final String face =
              !isThemePlaceholder(props.csFont) ? props.csFont : props.asciiFont;
          if (face.isNotEmpty &&
              (isArabicFamily(face) || !isThemePlaceholder(face))) {
            chosen ??= face;
          }
        } else if (!isThemePlaceholder(props.asciiFont)) {
          chosen ??= props.asciiFont;
        }
      }
    }
    if (chosen != null && chosen.isNotEmpty) {
      return chosen;
    }
    return hasRtl ? (themeFamily ?? arabicTheme) : latinTheme;
  }
}
