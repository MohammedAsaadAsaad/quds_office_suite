/// Office Math (OMML) tree used by Word equations.
///
/// Nodes map to the `m:` namespace structures: `oMath`, `f`, `sSub`/`sSup`,
/// `rad`, `nary`, `d`, `m`, `acc`, `func`, and `limLow`.
enum OmmlDisplay { inline, display }

enum OmmlView { professional, linear }

enum OmmlFracType { bar, noBar, skewed, linear }

enum OmmlScriptKind { sub, sup, subSup, preSubSup }

sealed class OmmlNode {
  OmmlNode();

  OmmlNode copy();
}

class OmmlSeq extends OmmlNode {
  OmmlSeq({List<OmmlNode>? children}) : children = children ?? <OmmlNode>[];

  List<OmmlNode> children;

  bool get isEmpty => children.isEmpty;

  @override
  OmmlSeq copy() =>
      OmmlSeq(children: <OmmlNode>[for (final OmmlNode n in children) n.copy()]);
}

class OmmlText extends OmmlNode {
  OmmlText({
    this.text = '',
    this.italic = true,
    this.bold = false,
    this.normal = false,
  });

  String text;
  bool italic;
  bool bold;
  bool normal;

  @override
  OmmlText copy() =>
      OmmlText(text: text, italic: italic, bold: bold, normal: normal);
}

class OmmlFrac extends OmmlNode {
  OmmlFrac({
    OmmlSeq? num,
    OmmlSeq? den,
    this.type = OmmlFracType.bar,
  })  : num = num ?? OmmlSeq(),
        den = den ?? OmmlSeq();

  OmmlSeq num;
  OmmlSeq den;
  OmmlFracType type;

  @override
  OmmlFrac copy() => OmmlFrac(num: num.copy(), den: den.copy(), type: type);
}

class OmmlScript extends OmmlNode {
  OmmlScript({
    OmmlSeq? base,
    OmmlSeq? sub,
    OmmlSeq? sup,
    this.kind = OmmlScriptKind.sup,
  })  : base = base ?? OmmlSeq(),
        sub = sub,
        sup = sup;

  OmmlSeq base;
  OmmlSeq? sub;
  OmmlSeq? sup;
  OmmlScriptKind kind;

  @override
  OmmlScript copy() => OmmlScript(
        base: base.copy(),
        sub: sub?.copy(),
        sup: sup?.copy(),
        kind: kind,
      );
}

class OmmlRad extends OmmlNode {
  OmmlRad({OmmlSeq? deg, OmmlSeq? e})
      : deg = deg,
        e = e ?? OmmlSeq();

  OmmlSeq? deg;
  OmmlSeq e;

  @override
  OmmlRad copy() => OmmlRad(deg: deg?.copy(), e: e.copy());
}

class OmmlNary extends OmmlNode {
  OmmlNary({
    this.chr = '∫',
    OmmlSeq? sub,
    OmmlSeq? sup,
    OmmlSeq? e,
    this.hideSub = false,
    this.hideSup = false,
  })  : sub = sub,
        sup = sup,
        e = e ?? OmmlSeq();

  String chr;
  OmmlSeq? sub;
  OmmlSeq? sup;
  OmmlSeq e;
  bool hideSub;
  bool hideSup;

  @override
  OmmlNary copy() => OmmlNary(
        chr: chr,
        sub: sub?.copy(),
        sup: sup?.copy(),
        e: e.copy(),
        hideSub: hideSub,
        hideSup: hideSup,
      );
}

class OmmlDelim extends OmmlNode {
  OmmlDelim({
    this.begChr = '(',
    this.endChr = ')',
    this.sepChr = '',
    OmmlSeq? e,
  }) : e = e ?? OmmlSeq();

  String begChr;
  String endChr;
  String sepChr;
  OmmlSeq e;

  @override
  OmmlDelim copy() => OmmlDelim(
        begChr: begChr,
        endChr: endChr,
        sepChr: sepChr,
        e: e.copy(),
      );
}

class OmmlMatrix extends OmmlNode {
  OmmlMatrix({List<List<OmmlSeq>>? rows})
      : rows = rows ??
            <List<OmmlSeq>>[
              <OmmlSeq>[OmmlSeq(), OmmlSeq()],
              <OmmlSeq>[OmmlSeq(), OmmlSeq()],
            ];

  List<List<OmmlSeq>> rows;

  @override
  OmmlMatrix copy() => OmmlMatrix(
        rows: <List<OmmlSeq>>[
          for (final List<OmmlSeq> row in rows)
            <OmmlSeq>[for (final OmmlSeq cell in row) cell.copy()],
        ],
      );
}

class OmmlAcc extends OmmlNode {
  OmmlAcc({this.chr = 'ˆ', OmmlSeq? e}) : e = e ?? OmmlSeq();

  String chr;
  OmmlSeq e;

  @override
  OmmlAcc copy() => OmmlAcc(chr: chr, e: e.copy());
}

class OmmlFunc extends OmmlNode {
  OmmlFunc({this.name = 'sin', OmmlSeq? e}) : e = e ?? OmmlSeq();

  String name;
  OmmlSeq e;

  @override
  OmmlFunc copy() => OmmlFunc(name: name, e: e.copy());
}

class OmmlLimLow extends OmmlNode {
  OmmlLimLow({OmmlSeq? e, OmmlSeq? lim})
      : e = e ?? OmmlSeq(children: <OmmlNode>[OmmlText(text: 'lim', italic: false, normal: true)]),
        lim = lim ?? OmmlSeq();

  OmmlSeq e;
  OmmlSeq lim;

  @override
  OmmlLimLow copy() => OmmlLimLow(e: e.copy(), lim: lim.copy());
}

class OmmlBar extends OmmlNode {
  OmmlBar({OmmlSeq? e, this.posTop = true}) : e = e ?? OmmlSeq();

  OmmlSeq e;
  bool posTop;

  @override
  OmmlBar copy() => OmmlBar(e: e.copy(), posTop: posTop);
}

class OmmlEquation {
  OmmlEquation({
    OmmlSeq? root,
    this.display = OmmlDisplay.display,
    this.view = OmmlView.professional,
    this.linearText = '',
  }) : root = root ?? OmmlSeq();

  OmmlSeq root;
  OmmlDisplay display;
  OmmlView view;
  String linearText;

  factory OmmlEquation.empty() => OmmlEquation();

  OmmlEquation copy() => OmmlEquation(
        root: root.copy(),
        display: display,
        view: view,
        linearText: linearText,
      );
}
