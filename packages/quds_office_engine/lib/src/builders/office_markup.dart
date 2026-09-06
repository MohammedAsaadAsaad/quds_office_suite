import '../xml/xml_reader.dart';

/// Shared OOXML text helpers used by the document builders.
abstract final class OfficeMarkup {
  static String escape(String text) => encodeXmlText(text);

  static String escapeAttr(String text) => encodeXmlAttribute(text);

  static String rgb(String hex) {
    final String h = hex.replaceAll('#', '').toUpperCase();
    if (h.length == 8) {
      return h;
    }
    if (h.length == 6) {
      return 'FF$h';
    }
    if (h.length == 3) {
      return 'FF${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
    }
    return 'FF000000';
  }

  static String srgb(String hex) {
    final String full = rgb(hex);
    return full.length == 8 ? full.substring(2) : full;
  }

  static String colName(int zeroBased) {
    var n = zeroBased;
    final List<int> chars = <int>[];
    while (n >= 0) {
      chars.add(65 + (n % 26));
      n = (n ~/ 26) - 1;
    }
    return String.fromCharCodes(chars.reversed);
  }

  static String sheetName(String name, int fallbackId) {
    var n = name.replaceAll(RegExp(r'[\\/*?:\[\]]'), '_').trim();
    if (n.isEmpty) {
      n = 'Sheet$fallbackId';
    }
    if (n.length > 31) {
      n = n.substring(0, 31);
    }
    return n;
  }
}

class ChartPoint {
  const ChartPoint({
    required this.label,
    required this.value,
    this.color = '4472C4',
  });

  final String label;
  final double value;
  final String color;

  ChartPoint copyWith({String? label, double? value, String? color}) {
    return ChartPoint(
      label: label ?? this.label,
      value: value ?? this.value,
      color: color ?? this.color,
    );
  }
}

/// Named series used by multi-series line / area / stacked charts.
class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.points,
    this.color,
  });

  final String name;
  final List<ChartPoint> points;
  final String? color;
}
