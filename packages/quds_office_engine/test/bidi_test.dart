import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:test/test.dart';

void main() {
  group('UAX #9', () {
    test('detects RTL paragraph from Arabic', () {
      final BidiParagraph p = Uax9Bidi.reorder('مرحبا');
      expect(p.baseLevel, 1);
      expect(p.runs, isNotEmpty);
      expect(p.runs.every((BidiRun r) => r.isRtl), isTrue);
    });

    test('embeds an Arabic run inside English', () {
      final BidiParagraph p = Uax9Bidi.reorder('Hello مرحبا world');
      expect(p.baseLevel, 0);
      expect(p.runs.any((BidiRun r) => r.isRtl), isTrue);
      expect(p.runs.any((BidiRun r) => !r.isRtl), isTrue);
    });

    test('classifies directional categories', () {
      expect(Uax9Bidi.classify(0x0041), BidiClass.l);
      expect(Uax9Bidi.classify(0x0627), BidiClass.al);
      expect(Uax9Bidi.classify(0x05D0), BidiClass.r);
      expect(Uax9Bidi.classify(0x0031), BidiClass.en);
      expect(Uax9Bidi.classify(0x0661), BidiClass.an);
      expect(Uax9Bidi.classify(0x064B), BidiClass.nsm);
    });
  });

  group('Arabic shaping', () {
    test('shapes Beh as initial then final in باب', () {
      final List<ShapedChar> shaped = ArabicShaper.shape('باب');
      expect(shaped.length, 3);
      expect(shaped[0].form, ArabicJoinForm.initial);
      expect(shaped[1].form, ArabicJoinForm.finalForm);
      expect(shaped[2].form, ArabicJoinForm.isolated);
    });

    test('builds obligatory Lam-Alef ligatures', () {
      final List<ShapedChar> la = ArabicShaper.shape('لا');
      expect(la.where((ShapedChar s) => s.advanceFactor > 0).length, 1);
      expect(la.first.codePoint, anyOf(0xFEFB, 0xFEFC));

      expect(ArabicShaper.shape('لآ').first.codePoint, anyOf(0xFEF5, 0xFEF6));
      expect(ArabicShaper.shape('لأ').first.codePoint, anyOf(0xFEF7, 0xFEF8));
      expect(ArabicShaper.shape('لإ').first.codePoint, anyOf(0xFEF9, 0xFEFA));
    });

    test('Lam-Alef in ملاحظة does not also keep a second alef', () {
      final List<BrokenLine> lines = LineBreaker.breakLines(
        text: 'ملاحظة',
        maxWidth: 400,
        widthOf: (int cp) => cp == 0 ? 0 : 8,
        justify: false,
      );
      final List<int> cps = <int>[
        for (final ShapedGlyph g in lines.single.glyphs)
          if (g.advance > 0) g.codePoint,
      ];
      expect(cps, isNot(contains(0x0627)));
      expect(cps, isNot(contains(0x0644)));
      expect(
        cps,
        contains(anyOf(0xFEFB, 0xFEFC)),
      );
      expect(cps.length, 5);
    });

    test('keeps tashkeel at zero advance on the base letter', () {
      final List<ShapedChar> shaped = ArabicShaper.shape('بَ');
      expect(shaped.length, 2);
      expect(shaped[0].advanceFactor, 1);
      expect(shaped[1].advanceFactor, 0);
      expect(shaped[1].codePoint, 0x064E);
    });
  });

  group('Grapheme clusters', () {
    test('groups Arabic letter plus tashkeel', () {
      final List<GraphemeCluster> clusters = GraphemeClusters.segment('بَا');
      expect(clusters.length, 2);
      expect(clusters.first.text, 'بَ');
    });
  });

  group('Line breaker', () {
    test('wraps a long sentence using Knuth-Plass', () {
      const String text =
          'The quick brown fox jumps over the lazy dog again and again';
      final List<BrokenLine> lines = LineBreaker.breakLines(
        text: text,
        maxWidth: 80,
        widthOf: (int cp) => cp == 0x20 ? 3.0 : 7.0,
      );
      expect(lines.length, greaterThan(1));
      for (final BrokenLine line in lines) {
        expect(line.width, lessThanOrEqualTo(81));
      }
    });

    test('reorders Arabic to visual order and applies join forms', () {
      final List<BrokenLine> lines = LineBreaker.breakLines(
        text: 'مرحبا',
        maxWidth: 1000,
        widthOf: (int cp) => 10,
      );
      final List<int> cps = lines.single.glyphs
          .map((ShapedGlyph g) => g.codePoint)
          .toList();
      expect(cps.first, anyOf(0xFE8D, 0xFE8E, 0x0627));
      expect(cps.last, anyOf(0xFEE3, 0xFEE4, 0x0645));
    });

    test('wraps RTL Arabic in logical order so يمكن stays on the first line', () {
      const String text =
          'يمكن إظهار المساطر، وتبديل RTL/LTR، وتكبير الصفحة من شريط العرض '
          'دون مغادرة المستند.';
      final List<BrokenLine> lines = LineBreaker.breakLines(
        text: text,
        maxWidth: 160,
        widthOf: (int cp) => cp == 0x20 ? 4.0 : 8.0,
        baseLevel: 1,
      );
      expect(lines.length, greaterThan(1));
      expect(lines.first.logicalStart, 0);
      expect(text.substring(0, lines.first.logicalEnd), startsWith('يمكن'));
      // Visual paint is left-to-right; the rightmost glyph is the logical start.
      expect(lines.first.glyphs.last.logicalIndex, 0);
      expect(
        lines.skip(1).any((BrokenLine line) => line.logicalStart == 0),
        isFalse,
      );
    });

    test('maps visual X back to a logical index', () {
      final List<BrokenLine> lines = LineBreaker.breakLines(
        text: 'ABCD',
        maxWidth: 1000,
        widthOf: (int cp) => 10,
      );
      expect(visualXToLogical(lines.single, 5), 0);
      expect(visualXToLogical(lines.single, 25), 2);
    });
  });

  group('Ctrl+Shift direction', () {
    test('right Ctrl+Shift is RTL and left Ctrl+Shift is LTR', () {
      expect(
        officeParagraphDirectionFromSides(
          leftCtrl: false,
          rightCtrl: true,
          leftShift: false,
          rightShift: true,
        ),
        isTrue,
      );
      expect(
        officeParagraphDirectionFromSides(
          leftCtrl: true,
          rightCtrl: false,
          leftShift: true,
          rightShift: false,
        ),
        isFalse,
      );
    });

    test('ignores the shortcut when another key is held', () {
      expect(
        officeParagraphDirectionFromSides(
          leftCtrl: false,
          rightCtrl: true,
          leftShift: false,
          rightShift: true,
          extraKeys: true,
        ),
        isNull,
      );
    });

    test(
      'Ctrl plus sided Shift still resolves when logical Ctrl is generic',
      () {
        expect(
          officeParagraphDirectionFromSides(
            leftCtrl: true,
            rightCtrl: false,
            leftShift: false,
            rightShift: true,
          ),
          isTrue,
        );
        expect(
          officeParagraphDirectionFromSides(
            leftCtrl: false,
            rightCtrl: true,
            leftShift: true,
            rightShift: false,
          ),
          isFalse,
        );
      },
    );
  });
}
