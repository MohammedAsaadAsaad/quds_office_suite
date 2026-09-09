import 'wml_document.dart';
import 'wml_run_edit.dart';

/// Replaces `«Field»` / `MERGEFIELD Field` tokens from a data table.
abstract final class WordMailMerge {
  /// Active merge row for [WordFields] MERGEFIELD evaluation.
  static Map<String, String> activeRecord(WmlDocument document) {
    if (document.mailMergeRecords.isEmpty) {
      return const <String, String>{};
    }
    final int index = document.mailMergePreview.clamp(
      0,
      document.mailMergeRecords.length - 1,
    );
    return document.mailMergeRecords[index];
  }

  /// Lookup helper used by [WordFields] for `MERGEFIELD`.
  static String valueFor(WmlDocument document, String name) {
    if (name.isEmpty) {
      return '';
    }
    return activeRecord(document)[name] ?? '';
  }

  /// Tokens present in [document] (`Name` from `«Name»` or MERGEFIELD).
  static Set<String> fieldsOf(WmlDocument document) {
    final Set<String> names = <String>{};
    final RegExp chevron = RegExp(r'«([^»]+)»');
    final RegExp merge = RegExp(
      r'MERGEFIELD\s+([A-Za-z0-9_]+)',
      caseSensitive: false,
    );
    void scan(Iterable<WmlParagraph> story) {
      for (final WmlParagraph paragraph in story) {
        for (final RegExpMatch match in chevron.allMatches(paragraph.text)) {
          names.add(match.group(1)!.trim());
        }
        final String? instr = paragraph.properties.fieldInstruction;
        if (instr != null) {
          for (final RegExpMatch match in merge.allMatches(instr)) {
            names.add(match.group(1)!);
          }
        }
      }
    }

    scan(document.paragraphs);
    for (final WmlSection section in document.sections) {
      scan(section.header);
      scan(section.footer);
      scan(section.firstHeader);
      scan(section.firstFooter);
      scan(section.evenHeader);
      scan(section.evenFooter);
    }
    return names;
  }

  /// Substitutes merge tokens in place using [record] (first row semantics).
  static void merge(WmlDocument document, Map<String, String> record) {
    void walk(Iterable<WmlParagraph> story) {
      for (final WmlParagraph paragraph in story) {
        var text = paragraph.text;
        record.forEach((String key, String value) {
          text = text.replaceAll('«$key»', value);
          text = text.replaceAll('« $key »', value);
        });
        if (text != paragraph.text) {
          if (paragraph.inlines.whereType<WmlRun>().isEmpty) {
            paragraph.inlines.add(WmlRun(text: text));
          } else {
            WmlRunEdit.replaceRange(paragraph, 0, paragraph.text.length, text);
          }
        }
        final String? instr = paragraph.properties.fieldInstruction;
        if (instr == null) {
          continue;
        }
        final RegExpMatch? match = RegExp(
          r'MERGEFIELD\s+([A-Za-z0-9_]+)',
          caseSensitive: false,
        ).firstMatch(instr);
        if (match == null) {
          continue;
        }
        final String? value = record[match.group(1)!];
        if (value == null) {
          continue;
        }
        if (paragraph.inlines.whereType<WmlRun>().isEmpty) {
          paragraph.inlines.add(WmlRun(text: value));
        } else {
          WmlRunEdit.replaceRange(paragraph, 0, paragraph.text.length, value);
        }
        // Field result is materialised; keep instruction for refresh via
        // WordFields.update when mailMergeRecords are set.
      }
    }

    walk(document.paragraphs);
    for (final WmlSection section in document.sections) {
      walk(section.header);
      walk(section.footer);
      walk(section.firstHeader);
      walk(section.firstFooter);
      walk(section.evenHeader);
      walk(section.evenFooter);
    }
  }

  /// One merged copy per record; the first record updates [document] itself.
  /// preview API.
  static void preview(
    WmlDocument document,
    List<Map<String, String>> records,
    int index,
  ) {
    if (records.isEmpty) {
      return;
    }
    document.mailMergeRecords
      ..clear()
      ..addAll(records);
    document.mailMergePreview = index.clamp(0, records.length - 1);
    merge(document, records[document.mailMergePreview]);
  }

  static List<WmlDocument> mergeAll(
    WmlDocument template,
    List<Map<String, String>> records,
  ) {
    if (records.isEmpty) {
      return <WmlDocument>[template];
    }
    merge(template, records.first);
    final List<WmlDocument> copies = <WmlDocument>[template];
    for (int i = 1; i < records.length; i++) {
      final WmlDocument next = WmlDocument.empty(text: '');
      next.sections
        ..clear()
        ..addAll(template.sections);
      merge(next, records[i]);
      copies.add(next);
    }
    return copies;
  }
}
