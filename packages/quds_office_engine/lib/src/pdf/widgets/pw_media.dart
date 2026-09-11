/// Images, charts, links, watermark, and table of contents.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../builders/office_markup.dart';
import '../../pdf/pdf_canvas.dart';
import '../../pdf/pdf_document.dart';
import '../../pdf/pdf_image.dart';
import 'pw_box.dart';
import 'pw_core.dart';
import 'pw_layout.dart';
import 'pw_paint.dart';
import 'pw_style.dart';
import 'pw_text.dart';
import 'pw_types.dart';

/// Image bytes provider.
class ImageProvider {
  /// ImageProvider API.
  const ImageProvider(this.bytes);

  /// bytes API.
  final Uint8List bytes;
}

/// In-memory PNG / JPEG.
class MemoryImage extends ImageProvider {
  /// MemoryImage API.
  const MemoryImage(super.bytes);
}

/// Inline picture.
class Image extends Widget {
  /// Image API.
  const Image(
    this.image, {
    this.width,
    this.height,
    this.dpi,
    this.fit = BoxFit.contain,
  });

  /// image API.
  final ImageProvider image;

  /// width API.
  final double? width;

  /// height API.
  final double? height;

  /// dpi API.
  final double? dpi;

  /// fit API.
  final BoxFit fit;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    final PdfRaster? raster = PdfImageCodec.decode(image.bytes);
    final double iw = raster == null
        ? (width ?? 120)
        : (dpi != null
              ? raster.width * 72 / dpi!
              : width ?? raster.width.toDouble());
    final double ih = raster == null
        ? (height ?? 80)
        : (dpi != null
              ? raster.height * 72 / dpi!
              : height ??
                    (width != null && raster.width > 0
                        ? width! * raster.height / raster.width
                        : raster.height.toDouble()));
    final PwSize size = constraints.constrain(PwSize(iw, ih));
    return _ImageBox(size, image.bytes, raster);
  }
}

class _ImageBox extends PwBox {
  _ImageBox(super.size, this.bytes, this.raster);

  final Uint8List bytes;
  final PdfRaster? raster;

  @override
  void paint(Context context, PwOffset offset) {
    final PdfCanvas? canvas = context.canvas;
    if (canvas == null) {
      return;
    }
    final PdfRaster? decoded = raster ?? PdfImageCodec.decode(bytes);
    if (decoded == null) {
      canvas.fillRect(offset.dx, offset.dy, size.width, size.height, 'ECEFF1');
      return;
    }
    final String name = context.nextImageName();
    context.images.add(
      PdfEmbeddedImage(
        name: name,
        width: decoded.width,
        height: decoded.height,
        bytes: decoded.jpegBytes ?? decoded.rgb,
        jpeg: decoded.isJpeg,
        maskBytes: decoded.alpha,
      ),
    );
    canvas.drawImage(name, offset.dx, offset.dy, size.width, size.height);
  }
}

/// Chart kind drawn with [PdfCanvas] paths.
enum ChartType { bar, line, pie }

/// Vector chart (no Flutter).
class Chart extends Widget {
  /// Chart API.
  const Chart({
    this.type = ChartType.bar,
    this.points = const <ChartPoint>[],
    this.title = '',
    this.width = 360,
    this.height = 180,
  });

  /// type API.
  final ChartType type;

  /// points API.
  final List<ChartPoint> points;

  /// title API.
  final String title;

  /// width API.
  final double width;

  /// height API.
  final double height;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    context.useText(title);
    for (final ChartPoint p in points) {
      context.useText(p.label);
    }
    return _ChartBox(
      constraints.constrain(PwSize(width, height)),
      type,
      points,
      title,
    );
  }
}

class _ChartBox extends PwBox {
  _ChartBox(super.size, this.type, this.points, this.title);

  final ChartType type;
  final List<ChartPoint> points;
  final String title;

  @override
  void paint(Context context, PwOffset offset) {
    final PdfCanvas? canvas = context.canvas;
    if (canvas == null) {
      return;
    }
    canvas.endText();
    canvas.setFillColor('FAFBFC');
    canvas.roundedRect(offset.dx, offset.dy, size.width, size.height, 4);
    canvas.fill();
    canvas.setStrokeColor('CFD8DC');
    canvas.setLineWidth(0.5);
    canvas.roundedRect(offset.dx, offset.dy, size.width, size.height, 4);
    canvas.stroke();
    if (title.isNotEmpty) {
      pwPaintParagraph(
        context,
        title,
        PwOffset(offset.dx + 10, offset.dy + 6),
        size.width - 20,
        const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: '37474F',
        ),
        TextAlign.left,
      );
    }
    final List<ChartPoint> pts = points.isEmpty
        ? const <ChartPoint>[
            ChartPoint(label: 'A', value: 4, color: '1A237E'),
            ChartPoint(label: 'B', value: 7, color: '00897B'),
            ChartPoint(label: 'C', value: 5, color: 'F9A825'),
          ]
        : points;
    var maxV = 1.0;
    for (final ChartPoint p in pts) {
      if (p.value > maxV) {
        maxV = p.value;
      }
    }
    final double plotTop = offset.dy + (title.isEmpty ? 12 : 24);
    final double plotLeft = offset.dx + 12;
    final double plotW = size.width - 24;
    final double plotH = size.height - (title.isEmpty ? 28 : 40);
    switch (type) {
      case ChartType.bar:
        _bars(context, canvas, pts, maxV, plotLeft, plotTop, plotW, plotH);
      case ChartType.line:
        _line(context, canvas, pts, maxV, plotLeft, plotTop, plotW, plotH);
      case ChartType.pie:
        _pie(context, canvas, pts, plotLeft, plotTop, plotW, plotH);
    }
  }

  void _bars(
    Context context,
    PdfCanvas canvas,
    List<ChartPoint> pts,
    double maxV,
    double x,
    double y,
    double w,
    double h,
  ) {
    final double slot = w / pts.length;
    final double barW = slot * 0.55;
    for (int i = 0; i < pts.length; i++) {
      final double bh = (pts[i].value / maxV) * (h - 16);
      final double bx = x + i * slot + (slot - barW) / 2;
      final double by = y + h - 14 - bh;
      canvas.fillRect(bx, by, barW, bh, pts[i].color);
      pwPaintParagraph(
        context,
        pts[i].label,
        PwOffset(x + i * slot, y + h - 12),
        slot,
        const TextStyle(fontSize: 7, color: '546E7A'),
        TextAlign.center,
      );
    }
  }

  void _line(
    Context context,
    PdfCanvas canvas,
    List<ChartPoint> pts,
    double maxV,
    double x,
    double y,
    double w,
    double h,
  ) {
    canvas.setStrokeColor('1A237E');
    canvas.setLineWidth(1.4);
    for (int i = 0; i < pts.length; i++) {
      final double px = x + (pts.length == 1 ? w / 2 : w * i / (pts.length - 1));
      final double py = y + (h - 14) * (1 - pts[i].value / maxV);
      if (i == 0) {
        canvas.moveTo(px, py);
      } else {
        canvas.lineTo(px, py);
      }
    }
    canvas.stroke();
    for (int i = 0; i < pts.length; i++) {
      final double px = x + (pts.length == 1 ? w / 2 : w * i / (pts.length - 1));
      final double py = y + (h - 14) * (1 - pts[i].value / maxV);
      canvas.setFillColor(pts[i].color);
      canvas.ellipse(px - 2.5, py - 2.5, 5, 5);
      canvas.fill();
      pwPaintParagraph(
        context,
        pts[i].label,
        PwOffset(px - 16, y + h - 12),
        32,
        const TextStyle(fontSize: 7, color: '546E7A'),
        TextAlign.center,
      );
    }
  }

  void _pie(
    Context context,
    PdfCanvas canvas,
    List<ChartPoint> pts,
    double x,
    double y,
    double w,
    double h,
  ) {
    var sum = 0.0;
    for (final ChartPoint p in pts) {
      sum += p.value.abs();
    }
    if (sum <= 0) {
      sum = 1;
    }
    final double cx = x + w * 0.38;
    final double cy = y + h / 2;
    final double r = math.min(w, h) * 0.32;
    var angle = -90.0;
    for (final ChartPoint p in pts) {
      final double sweep = 360 * p.value.abs() / sum;
      canvas.setFillColor(p.color);
      canvas.moveTo(cx, cy);
      final int steps = math.max(8, (sweep.abs() / 5).round());
      for (int i = 0; i <= steps; i++) {
        final double a = (angle + sweep * i / steps) * math.pi / 180;
        canvas.lineTo(cx + r * math.cos(a), cy + r * math.sin(a));
      }
      canvas.closePath();
      canvas.fill();
      angle += sweep;
    }
    var ly = y + 8;
    for (final ChartPoint p in pts) {
      canvas.fillRect(x + w * 0.72, ly, 8, 8, p.color);
      pwPaintParagraph(
        context,
        p.label,
        PwOffset(x + w * 0.72 + 12, ly),
        w * 0.26,
        const TextStyle(fontSize: 8, color: '37474F'),
        TextAlign.left,
      );
      ly += 14;
    }
  }
}

/// Tappable URI or internal destination over [child].
class Link extends Widget {
  /// Link API.
  const Link({
    required this.child,
    this.destination,
    this.destPage,
  });

  /// child API.
  final Widget child;

  /// Named anchor (see [Anchor]).
  final String? destination;

  /// 0-based page index.
  final int? destPage;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    final PwBox box = child.layout(context, constraints);
    return _LinkBox(box.size, box, destPage: destPage, destination: destination);
  }
}

/// URI annotation over [child].
class UrlLink extends Widget {
  /// UrlLink API.
  const UrlLink({required this.child, required this.destination});

  /// child API.
  final Widget child;

  /// destination API.
  final String destination;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    final PwBox box = child.layout(context, constraints);
    return _LinkBox(box.size, box, uri: destination);
  }
}

class _LinkBox extends PwBox {
  _LinkBox(
    super.size,
    this.child, {
    this.uri,
    this.destPage,
    this.destination,
  });

  final PwBox child;
  final String? uri;
  final int? destPage;
  final String? destination;

  @override
  void paint(Context context, PwOffset offset) {
    child.paint(context, offset);
    int? page = destPage;
    double? destY;
    final String? name = destination;
    if (page == null && name != null) {
      final PwHeading? hit = context.anchors[name];
      if (hit != null) {
        page = hit.pageNumber - 1;
        destY = hit.destY;
      } else {
        final int? numbered = context.pageOfHeading(name);
        if (numbered != null) {
          page = numbered - 1;
        }
      }
    }
    context.links.add(
      PdfLinkAnnot(
        x: offset.dx,
        y: offset.dy,
        width: size.width,
        height: size.height,
        uri: uri,
        destPage: page,
        destY: destY,
      ),
    );
  }
}

/// Diagonal document stamp, extracted by [MultiPage].
class Watermark extends Widget with PwPageOverlay {
  /// Watermark API.
  const Watermark({required this.child});

  /// text API.
  Watermark.text(String text, {TextStyle? style})
    : child = Text(
        text,
        style:
            style ??
            const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: 'E0E0E0',
            ),
      );

  /// child API.
  final Widget child;

  @override
  Widget get overlayChild => child;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    return child.layout(context, constraints);
  }
}

/// Two-pass TOC from [Header] entries.
class TableOfContent extends Widget {
  /// TableOfContent API.
  const TableOfContent({
    this.title = 'Table of Contents',
    this.minLevel = 1,
    this.maxLevel = 3,
    this.showPageNumbers = true,
  });

  /// title API.
  final String title;

  /// minLevel API.
  final int minLevel;

  /// maxLevel API.
  final int maxLevel;

  /// showPageNumbers API.
  final bool showPageNumbers;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    final List<PwHeading> source = context.frozenHeadings.isNotEmpty
        ? context.frozenHeadings
        : context.headings;
    final List<Widget> rows = <Widget>[
      Header(level: 1, text: title, title: title),
      const SizedBox(height: 6),
    ];
    for (final PwHeading heading in source) {
      if (heading.level < minLevel || heading.level > maxLevel) {
        continue;
      }
      if (heading.title == title) {
        continue;
      }
      final double indent = (heading.level - minLevel) * 14.0;
      rows.add(
        Padding(
          padding: EdgeInsets.only(left: indent, bottom: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  heading.title,
                  style: TextStyle(
                    fontSize: heading.level == 1 ? 11 : 10,
                    color: '37474F',
                  ),
                ),
              ),
              if (showPageNumbers)
                Text(
                  '${heading.pageNumber}',
                  style: const TextStyle(fontSize: 10, color: '546E7A'),
                ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows).layout(context, constraints);
  }
}

/// Bullet / numbered list of widgets.
class Bullet extends Widget {
  /// Bullet API.
  const Bullet({
    required this.text,
    this.style,
    this.bullet = '•',
  });

  /// text API.
  final String text;

  /// style API.
  final TextStyle? style;

  /// bullet API.
  final String bullet;

  @override
  PwBox layout(Context context, BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 14,
            child: Text(bullet, style: style),
          ),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    ).layout(context, constraints);
  }
}
