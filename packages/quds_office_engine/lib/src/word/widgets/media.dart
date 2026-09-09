part of 'widgets.dart';

/// Image bytes provider. Same role as `pw.ImageProvider`.
class ImageProvider {
  /// ImageProvider API.
  const ImageProvider(this.bytes);

  /// bytes API.
  final Uint8List bytes;
}

/// In-memory image. Same constructor as `pw.MemoryImage`.
class MemoryImage extends ImageProvider {
  /// MemoryImage API.
  const MemoryImage(super.bytes);
}

/// Inline picture. Same constructor as `pw.Image`.
class Image extends Widget {
  /// Image API.
  const Image(this.image, {this.width, this.height, this.dpi});

  /// image API.
  final ImageProvider image;

  /// width API.
  final double? width;

  /// height API.
  final double? height;

  /// dpi API.
  final double? dpi;
}

/// Lightweight chart (Word `OfficeVisual`).
class Chart extends Widget {
  /// Chart API.
  const Chart({
    this.kind = OfficeVisualKind.chartColumn,
    this.points = const <ChartPoint>[],
    this.title = '',
    this.width = 360,
    this.height = 180,
  });

  /// kind API.
  final OfficeVisualKind kind;

  /// points API.
  final List<ChartPoint> points;

  /// title API.
  final String title;

  /// width API.
  final double width;

  /// height API.
  final double height;
}
