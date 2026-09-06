import 'dart:math' as math;
import 'dart:ui';

class TransformHandles {
  const TransformHandles(this.bounds, {this.rotation = 0});

  final Rect bounds;
  final double rotation;

  List<Offset> get points => <Offset>[
        bounds.topLeft,
        Offset(bounds.center.dx, bounds.top),
        bounds.topRight,
        Offset(bounds.right, bounds.center.dy),
        bounds.bottomRight,
        Offset(bounds.center.dx, bounds.bottom),
        bounds.bottomLeft,
        Offset(bounds.left, bounds.center.dy),
      ];

  Offset get rotateHandle => Offset(bounds.center.dx, bounds.top - 18);

  int? hit(Offset p, {double radius = 10}) {
    for (int i = 0; i < points.length; i++) {
      if ((points[i] - p).distance <= radius) {
        return i;
      }
    }
    if ((rotateHandle - p).distance <= radius) {
      return 8;
    }
    return null;
  }

  void paint(
    Canvas canvas, {
    Color strokeColor = const Color(0xFF2E75B6),
    Color fillColor = const Color(0xFFFFFFFF),
    bool showKnobs = true,
    bool showRotate = true,
    double knobSize = 7,
  }) {
    final Paint stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (showKnobs) {
      canvas.drawRect(bounds, stroke);
    } else {
      _dashRect(canvas, bounds, stroke);
    }
    if (!showKnobs) {
      return;
    }
    final Paint fill = Paint()..color = fillColor;
    for (final Offset p in points) {
      canvas.drawRect(
        Rect.fromCenter(center: p, width: knobSize, height: knobSize),
        fill,
      );
      canvas.drawRect(
        Rect.fromCenter(center: p, width: knobSize, height: knobSize),
        stroke,
      );
    }
    if (showRotate) {
      canvas.drawLine(Offset(bounds.center.dx, bounds.top), rotateHandle, stroke);
      canvas.drawCircle(rotateHandle, 4, Paint()..color = strokeColor);
    }
  }

  /// Circular-arrow pointer drawn at [hot] (widget coordinates).
  static void paintRotateCursor(
    Canvas canvas,
    Offset hot, {
    Color color = const Color(0xFF1A1A1A),
  }) {
    canvas.save();
    canvas.translate(hot.dx, hot.dy);
    final Paint ring = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final Paint ink = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    const double r = 7.5;
    const double start = -2.15;
    const double sweep = 4.3;
    final Rect oval = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawArc(oval, start, sweep, false, ring);
    canvas.drawArc(oval, start, sweep, false, ink);
    final double tip = start + sweep;
    final Offset end = Offset(r * math.cos(tip), r * math.sin(tip));
    final Offset tangent = Offset(-math.sin(tip), math.cos(tip));
    final Offset normal = Offset(-tangent.dy, tangent.dx);
    final Path head = Path()
      ..moveTo(
        end.dx + tangent.dx * 5.2 + normal.dx * 3.2,
        end.dy + tangent.dy * 5.2 + normal.dy * 3.2,
      )
      ..lineTo(end.dx, end.dy)
      ..lineTo(
        end.dx + tangent.dx * 5.2 - normal.dx * 3.2,
        end.dy + tangent.dy * 5.2 - normal.dy * 3.2,
      );
    canvas.drawPath(
      head,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  static void _dashRect(Canvas canvas, Rect rect, Paint paint) {
    const double dash = 5;
    const double gap = 4;
    _dashLine(canvas, rect.topLeft, rect.topRight, paint, dash, gap);
    _dashLine(canvas, rect.topRight, rect.bottomRight, paint, dash, gap);
    _dashLine(canvas, rect.bottomRight, rect.bottomLeft, paint, dash, gap);
    _dashLine(canvas, rect.bottomLeft, rect.topLeft, paint, dash, gap);
  }

  static void _dashLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double dash,
    double gap,
  ) {
    final Offset delta = b - a;
    final double len = delta.distance;
    if (len <= 0) {
      return;
    }
    final Offset step = delta / len;
    var walked = 0.0;
    while (walked < len) {
      final double end = math.min(walked + dash, len);
      canvas.drawLine(a + step * walked, a + step * end, paint);
      walked = end + gap;
    }
  }
}
