import 'dart:math' as math;
import 'dart:ui';

/// 2D axis-aligned virtualization with an overscan buffer.
class VirtualViewport {
  VirtualViewport({
    this.overscan = 64,
    this.origin = Offset.zero,
    this.extent = Size.zero,
    this.scale = 1,
  });

  double overscan;
  Offset origin;
  Size extent;
  double scale;

  static const double minScale = 0.25;
  static const double maxScale = 4;

  void setScale(double value) {
    scale = value.clamp(minScale, maxScale);
  }

  Rect get visible => Rect.fromLTWH(
        origin.dx - overscan,
        origin.dy - overscan,
        extent.width + overscan * 2,
        extent.height + overscan * 2,
      );

  void pan(Offset delta) {
    origin += delta;
  }

  /// Keeps [origin] inside the document so the user cannot scroll forever.
  void clampTo({required Size content, required Size view, double pad = 0}) {
    final double maxX = math.max(0, content.width - view.width + pad);
    final double maxY = math.max(0, content.height - view.height + pad);
    origin = Offset(
      origin.dx.clamp(-pad, maxX),
      origin.dy.clamp(-pad, maxY),
    );
  }

  void zoomAt(Offset focal, double factor) {
    origin = Offset(
      focal.dx - (focal.dx - origin.dx) * factor,
      focal.dy - (focal.dy - origin.dy) * factor,
    );
  }

  bool intersects(Rect box) => visible.overlaps(box);

  /// Visible integer range along one axis given [sizes] starting at [start].
  (int, int) visibleSpan(List<double> sizes, double start) {
    var cursor = start;
    var first = 0;
    var last = sizes.length;
    for (int i = 0; i < sizes.length; i++) {
      if (cursor + sizes[i] >= visible.top && first == 0 && i > 0) {
        first = i;
      }
      if (cursor > visible.bottom) {
        last = i;
        break;
      }
      cursor += sizes[i];
    }
    return (math.max(0, first), math.min(sizes.length, last));
  }
}
