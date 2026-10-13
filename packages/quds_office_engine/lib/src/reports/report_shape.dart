/// Region outlines for a shape map: a bundled world atlas, an imported
/// shapefile or GeoJSON, and the compact form saved in a `.qrep`.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'report_data.dart';
import 'world_countries.dart';

/// Thrown when shape bytes are not a shapefile, GeoJSON, or a shape layer.
class ReportShapeException implements Exception {
  /// ReportShapeException API.
  const ReportShapeException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'ReportShapeException: $message';
}

/// One closed ring. A [hole] is drawn in the ocean color.
class ReportShapeRing {
  /// ReportShapeRing API.
  ReportShapeRing({required this.hole, required this.lonLat});

  /// Interior ring.
  final bool hole;

  /// Interleaved longitude, latitude in degrees.
  final Float64List lonLat;

  /// Vertices.
  int get length => lonLat.length ~/ 2;

  /// Signed area in square degrees (positive is counter-clockwise).
  double get signedArea {
    if (length < 3) {
      return 0;
    }
    var sum = 0.0;
    for (int i = 0; i < length; i++) {
      final int j = (i + 1) % length;
      sum += lonLat[i * 2] * lonLat[j * 2 + 1];
      sum -= lonLat[j * 2] * lonLat[i * 2 + 1];
    }
    return sum / 2;
  }
}

/// One named region (a country, a district, a custom polygon).
class ReportShapeFeature {
  /// ReportShapeFeature API.
  ReportShapeFeature({
    required this.key,
    required this.label,
    List<String>? aliases,
    List<ReportShapeRing>? rings,
  }) : aliases = aliases ?? <String>[],
       rings = rings ?? <ReportShapeRing>[];

  /// Value the report data matches (`LY`, `LBY`, a district code).
  final String key;

  /// Name drawn on a wide region.
  final String label;

  /// Other spellings that match this region (`Libya`, `ليبيا`).
  final List<String> aliases;

  /// Outer rings and holes.
  final List<ReportShapeRing> rings;
}

/// A shape file read for a report: the layer to embed, and the attribute
/// whose values are the region keys (null for a `.qmap`, which already
/// stores them).
class ReportShapeFile {
  /// ReportShapeFile API.
  const ReportShapeFile({required this.layer, this.keyField});

  /// Regions to store under `shapes/` in the `.qrep`.
  final ReportShapeLayer layer;

  /// Shapefile or GeoJSON attribute that supplied [ReportShapeFeature.key].
  final String? keyField;
}

/// A set of regions drawn as one map.
class ReportShapeLayer {
  /// ReportShapeLayer API.
  ReportShapeLayer(List<ReportShapeFeature> features)
    : features = List<ReportShapeFeature>.unmodifiable(features);

  /// features API.
  final List<ReportShapeFeature> features;

  Map<String, int>? _index;

  /// Feature whose key or alias equals [raw] (case and surrounding space
  /// ignored), or null.
  ReportShapeFeature? find(String raw) {
    final int? i = indexOf(raw);
    return i == null ? null : features[i];
  }

  /// Index of [find], or null.
  int? indexOf(String raw) {
    final Map<String, int> index = _index ??= _build();
    return index[_norm(raw)];
  }

  Map<String, int> _build() {
    final Map<String, int> out = <String, int>{};
    for (int i = 0; i < features.length; i++) {
      final ReportShapeFeature f = features[i];
      out.putIfAbsent(_norm(f.key), () => i);
      out.putIfAbsent(_norm(f.label), () => i);
      for (final String a in f.aliases) {
        out.putIfAbsent(_norm(a), () => i);
      }
    }
    return out;
  }

  static String _norm(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Compact bytes (`QMAP`) stored under `shapes/` in a `.qrep`.
  Uint8List encode() {
    final BytesBuilder b = BytesBuilder();
    b.add(<int>[0x51, 0x4D, 0x41, 0x50, 1]);
    _u16(b, features.length);
    for (final ReportShapeFeature f in features) {
      _str(b, f.key);
      _str(b, f.label);
      final List<String> aliases = <String>[
        for (final String a in f.aliases)
          if (a.trim().isNotEmpty) a.trim(),
      ];
      b.addByte(math.min(aliases.length, 255));
      for (int i = 0; i < aliases.length && i < 255; i++) {
        _str(b, aliases[i]);
      }
      _u16(b, f.rings.length);
      for (final ReportShapeRing ring in f.rings) {
        _u16(b, ring.length);
        b.addByte(ring.hole ? 1 : 0);
        for (int i = 0; i < ring.length; i++) {
          _i16(b, _q(ring.lonLat[i * 2], 180));
          _i16(b, _q(ring.lonLat[i * 2 + 1], 90));
        }
      }
    }
    return b.takeBytes();
  }

  /// Reads [encode].
  static ReportShapeLayer decode(Uint8List bytes) {
    if (bytes.length < 7 ||
        bytes[0] != 0x51 ||
        bytes[1] != 0x4D ||
        bytes[2] != 0x41 ||
        bytes[3] != 0x50) {
      throw const ReportShapeException('Not a shape layer');
    }
    if (bytes[4] != 1) {
      throw ReportShapeException('Unknown shape layer version ${bytes[4]}');
    }
    final ByteData data = ByteData.sublistView(bytes);
    var o = 5;
    final int count = _readU16(data, o);
    o += 2;
    final List<ReportShapeFeature> features = <ReportShapeFeature>[];
    for (int i = 0; i < count; i++) {
      final (String key, int k) = _readStr(bytes, o);
      o = k;
      final (String label, int l) = _readStr(bytes, o);
      o = l;
      if (o >= bytes.length) {
        throw const ReportShapeException('Truncated shape layer');
      }
      final int aliases = bytes[o];
      o++;
      final List<String> names = <String>[];
      for (int a = 0; a < aliases; a++) {
        final (String name, int n) = _readStr(bytes, o);
        o = n;
        names.add(name);
      }
      final int rings = _readU16(data, o);
      o += 2;
      final List<ReportShapeRing> parts = <ReportShapeRing>[];
      for (int r = 0; r < rings; r++) {
        final int n = _readU16(data, o);
        o += 2;
        if (o >= bytes.length) {
          throw const ReportShapeException('Truncated shape layer');
        }
        final bool hole = bytes[o] == 1;
        o++;
        final Float64List lonLat = Float64List(n * 2);
        for (int p = 0; p < n; p++) {
          lonLat[p * 2] = _readI16(data, o) / 100;
          o += 2;
          lonLat[p * 2 + 1] = _readI16(data, o) / 100;
          o += 2;
        }
        if (n >= 3) {
          parts.add(ReportShapeRing(hole: hole, lonLat: lonLat));
        }
      }
      features.add(
        ReportShapeFeature(
          key: key,
          label: label.isEmpty ? key : label,
          aliases: names,
          rings: parts,
        ),
      );
    }
    return ReportShapeLayer(features);
  }

  /// Shapefile (`.shp`), GeoJSON, or [encode] bytes. [attributes] is the
  /// `.dbf` beside a shapefile. [keyField] names the attribute used as
  /// [ReportShapeFeature.key]; without it a code or name column is chosen.
  static ReportShapeLayer parse(
    Uint8List bytes, {
    Uint8List? attributes,
    String? keyField,
    String? nameField,
  }) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x51 &&
        bytes[1] == 0x4D &&
        bytes[2] == 0x41 &&
        bytes[3] == 0x50) {
      return decode(bytes);
    }
    if (bytes.length >= 4 &&
        ByteData.sublistView(bytes).getInt32(0, Endian.big) == 9994) {
      return parseShapefile(
        bytes,
        attributes: attributes,
        keyField: keyField,
        nameField: nameField,
      );
    }
    return parseGeoJson(
      utf8.decode(bytes, allowMalformed: true),
      keyField: keyField,
      nameField: nameField,
    );
  }

  /// Reads a shape file and names the attribute that became each region's key.
  ///
  /// A `.qmap` already has its keys, so [ReportShapeFile.keyField] is null.
  static ReportShapeFile read(
    Uint8List bytes, {
    Uint8List? attributes,
    String? keyField,
    String? nameField,
  }) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x51 &&
        bytes[1] == 0x4D &&
        bytes[2] == 0x41 &&
        bytes[3] == 0x50) {
      return ReportShapeFile(layer: decode(bytes));
    }
    if (bytes.length >= 4 &&
        ByteData.sublistView(bytes).getInt32(0, Endian.big) == 9994) {
      return ReportShapeFile(
        layer: parseShapefile(
          bytes,
          attributes: attributes,
          keyField: keyField,
          nameField: nameField,
        ),
        keyField: _dbfKeyName(attributes, keyField),
      );
    }
    final String text = utf8.decode(bytes, allowMalformed: true);
    return ReportShapeFile(
      layer: parseGeoJson(text, keyField: keyField, nameField: nameField),
      keyField: _geoKeyName(text, keyField),
    );
  }

  /// ESRI polygon shapefile. [attributes] supplies the region key.
  static ReportShapeLayer parseShapefile(
    Uint8List shp, {
    Uint8List? attributes,
    String? keyField,
    String? nameField,
  }) {
    if (shp.length < 100 ||
        ByteData.sublistView(shp).getInt32(0, Endian.big) != 9994) {
      throw const ReportShapeException('Not a shapefile');
    }
    final _Dbf? dbf = attributes == null ? null : _Dbf.parse(attributes);
    final int namedKey = dbf?.column(keyField) ?? -1;
    final int keyCol = namedKey >= 0 ? namedKey : (dbf?.preferredKey() ?? -1);
    final int nameCol = dbf?.column(nameField) ?? -1;
    final ByteData data = ByteData.sublistView(shp);
    final List<ReportShapeFeature> features = <ReportShapeFeature>[];
    var offset = 100;
    var row = 0;
    while (offset + 8 <= shp.length) {
      final int words = data.getInt32(offset + 4, Endian.big);
      final int content = words * 2;
      if (content < 4 || offset + 8 + content > shp.length) {
        break;
      }
      final int type = data.getInt32(offset + 8, Endian.little);
      final List<String> record = dbf == null || row >= dbf.rows.length
          ? const <String>[]
          : dbf.rows[row];
      row++;
      if (type == 5 || type == 15 || type == 25) {
        final List<ReportShapeRing> rings = _shpRings(
          data,
          offset + 12,
          offset + 8 + content,
        );
        if (rings.isNotEmpty) {
          final String key = keyCol >= 0 && keyCol < record.length
              ? record[keyCol].trim()
              : '$row';
          final String named = nameCol >= 0 && nameCol < record.length
              ? record[nameCol].trim()
              : '';
          features.add(
            ReportShapeFeature(
              key: key.isEmpty ? '$row' : key,
              label: named.isEmpty ? (key.isEmpty ? '$row' : key) : named,
              aliases: named.isEmpty || named == key
                  ? const <String>[]
                  : <String>[named],
              rings: rings,
            ),
          );
        }
      }
      offset += 8 + content;
    }
    if (features.isEmpty) {
      throw const ReportShapeException('The shapefile has no polygons');
    }
    return ReportShapeLayer(features);
  }

  /// GeoJSON `FeatureCollection`, `Feature`, or `Polygon`.
  static ReportShapeLayer parseGeoJson(
    String text, {
    String? keyField,
    String? nameField,
  }) {
    final Object? decoded;
    try {
      decoded = ReportData.fromJsonValue(jsonDecode(text));
    } on FormatException catch (e) {
      throw ReportShapeException('Invalid GeoJSON: $e');
    }
    if (decoded is! Map<String, Object?>) {
      throw const ReportShapeException('GeoJSON must be an object');
    }
    final List<Map<String, Object?>> features = <Map<String, Object?>>[];
    final String? type = decoded['type'] as String?;
    if (type == 'FeatureCollection') {
      final Object? list = decoded['features'];
      if (list is List<Object?>) {
        for (final Object? item in list) {
          if (item is Map<String, Object?>) {
            features.add(item);
          }
        }
      }
    } else if (type == 'Feature') {
      features.add(decoded);
    } else if (type == 'Polygon' || type == 'MultiPolygon') {
      features.add(<String, Object?>{
        'type': 'Feature',
        'geometry': decoded,
        'properties': <String, Object?>{},
      });
    }
    final List<ReportShapeFeature> out = <ReportShapeFeature>[];
    for (int i = 0; i < features.length; i++) {
      final Map<String, Object?> feature = features[i];
      final Object? geometry = feature['geometry'];
      if (geometry is! Map<String, Object?>) {
        continue;
      }
      final List<ReportShapeRing> rings = _geoRings(geometry);
      if (rings.isEmpty) {
        continue;
      }
      final Map<String, Object?> props =
          feature['properties'] is Map<String, Object?>
          ? feature['properties']! as Map<String, Object?>
          : const <String, Object?>{};
      final String key =
          _prop(props, keyField) ?? _autoKey(props) ?? '${i + 1}';
      final String label =
          _prop(props, nameField) ??
          _prop(props, 'NAME') ??
          _prop(props, 'name') ??
          key;
      out.add(
        ReportShapeFeature(
          key: key,
          label: label,
          aliases: _aliases(props, key, label),
          rings: rings,
        ),
      );
    }
    if (out.isEmpty) {
      throw const ReportShapeException('The GeoJSON has no polygons');
    }
    return ReportShapeLayer(out);
  }

  static List<ReportShapeRing> _shpRings(ByteData data, int start, int end) {
    if (start + 40 > end) {
      return const <ReportShapeRing>[];
    }
    final int parts = data.getInt32(start + 32, Endian.little);
    final int points = data.getInt32(start + 36, Endian.little);
    if (parts <= 0 || points < 3) {
      return const <ReportShapeRing>[];
    }
    final int partsAt = start + 40;
    final int pointsAt = partsAt + parts * 4;
    if (pointsAt + points * 16 > end + 1) {
      return const <ReportShapeRing>[];
    }
    final List<int> index = <int>[
      for (int i = 0; i < parts; i++)
        data.getInt32(partsAt + i * 4, Endian.little),
    ];
    final List<ReportShapeRing> rings = <ReportShapeRing>[];
    for (int p = 0; p < parts; p++) {
      final int from = index[p];
      final int to = p + 1 < parts ? index[p + 1] : points;
      if (to - from < 3) {
        continue;
      }
      final Float64List lonLat = Float64List((to - from) * 2);
      var n = 0;
      for (int i = from; i < to; i++) {
        final double lon = data.getFloat64(pointsAt + i * 16, Endian.little);
        final double lat = data.getFloat64(
          pointsAt + i * 16 + 8,
          Endian.little,
        );
        if (n > 0 &&
            lonLat[(n - 1) * 2] == lon &&
            lonLat[(n - 1) * 2 + 1] == lat) {
          continue;
        }
        lonLat[n * 2] = lon;
        lonLat[n * 2 + 1] = lat;
        n++;
      }
      if (n >= 2 &&
          lonLat[0] == lonLat[(n - 1) * 2] &&
          lonLat[1] == lonLat[(n - 1) * 2 + 1]) {
        n--;
      }
      if (n >= 3) {
        rings.add(ReportShapeRing(hole: false, lonLat: _copy(lonLat, n)));
      }
    }
    if (rings.length > 1) {
      var main = 0;
      var biggest = 0.0;
      final List<double> areas = <double>[
        for (final ReportShapeRing r in rings) r.signedArea,
      ];
      for (int i = 0; i < areas.length; i++) {
        final double a = areas[i].abs();
        if (a > biggest) {
          biggest = a;
          main = i;
        }
      }
      final double sign = areas[main];
      return <ReportShapeRing>[
        for (int i = 0; i < rings.length; i++)
          ReportShapeRing(
            hole: i != main && areas[i] * sign < 0,
            lonLat: rings[i].lonLat,
          ),
      ];
    }
    return rings;
  }

  static List<ReportShapeRing> _geoRings(Map<String, Object?> geometry) {
    final String? type = geometry['type'] as String?;
    final Object? coords = geometry['coordinates'];
    if (type == 'Polygon') {
      return _polygon(coords);
    }
    if (type == 'MultiPolygon' && coords is List<Object?>) {
      return <ReportShapeRing>[
        for (final Object? polygon in coords) ..._polygon(polygon),
      ];
    }
    if (type == 'GeometryCollection') {
      final Object? list = geometry['geometries'];
      if (list is List<Object?>) {
        return <ReportShapeRing>[
          for (final Object? g in list)
            if (g is Map<String, Object?>) ..._geoRings(g),
        ];
      }
    }
    return const <ReportShapeRing>[];
  }

  static List<ReportShapeRing> _polygon(Object? coords) {
    if (coords is! List<Object?>) {
      return const <ReportShapeRing>[];
    }
    final List<ReportShapeRing> rings = <ReportShapeRing>[];
    for (int i = 0; i < coords.length; i++) {
      final Float64List? lonLat = _positions(coords[i]);
      if (lonLat != null) {
        rings.add(ReportShapeRing(hole: i > 0, lonLat: lonLat));
      }
    }
    return rings;
  }

  static Float64List? _positions(Object? ring) {
    if (ring is! List<Object?>) {
      return null;
    }
    final Float64List lonLat = Float64List(ring.length * 2);
    var n = 0;
    for (final Object? point in ring) {
      if (point is! List<Object?> || point.length < 2) {
        continue;
      }
      final Object? lon = point[0];
      final Object? lat = point[1];
      if (lon is! num || lat is! num) {
        continue;
      }
      if (n > 0 &&
          lonLat[(n - 1) * 2] == lon.toDouble() &&
          lonLat[(n - 1) * 2 + 1] == lat.toDouble()) {
        continue;
      }
      lonLat[n * 2] = lon.toDouble();
      lonLat[n * 2 + 1] = lat.toDouble();
      n++;
    }
    if (n >= 2 &&
        lonLat[0] == lonLat[(n - 1) * 2] &&
        lonLat[1] == lonLat[(n - 1) * 2 + 1]) {
      n--;
    }
    if (n < 3) {
      return null;
    }
    return _copy(lonLat, n);
  }

  static Float64List _copy(Float64List source, int vertices) {
    if (source.length == vertices * 2) {
      return source;
    }
    final Float64List out = Float64List(vertices * 2);
    out.setRange(0, vertices * 2, source);
    return out;
  }

  static String? _prop(Map<String, Object?> props, String? name) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    final String want = name.trim().toLowerCase();
    for (final MapEntry<String, Object?> e in props.entries) {
      if (e.key.toLowerCase() == want && e.value != null) {
        final String text = '${e.value}'.trim();
        if (text.isNotEmpty && text != '-99' && text != 'None') {
          return text;
        }
      }
    }
    return null;
  }

  static String? _dbfKeyName(Uint8List? attributes, String? requested) {
    if (attributes == null) {
      return null;
    }
    final _Dbf dbf = _Dbf.parse(attributes);
    final int named = dbf.column(requested);
    final int col = named >= 0 ? named : dbf.preferredKey();
    if (col < 0 || col >= dbf.fields.length) {
      return null;
    }
    final String name = dbf.fields[col].trim();
    return name.isEmpty ? null : name;
  }

  static String? _geoKeyName(String text, String? requested) {
    final Object? decoded;
    try {
      decoded = ReportData.fromJsonValue(jsonDecode(text));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    Map<String, Object?>? props;
    final String? type = decoded['type'] as String?;
    if (type == 'Feature') {
      final Object? p = decoded['properties'];
      if (p is Map<String, Object?>) {
        props = p;
      }
    } else if (type == 'FeatureCollection') {
      final Object? list = decoded['features'];
      if (list is List<Object?>) {
        for (final Object? item in list) {
          if (item is Map<String, Object?>) {
            final Object? p = item['properties'];
            if (p is Map<String, Object?> && p.isNotEmpty) {
              props = p;
              break;
            }
          }
        }
      }
    }
    if (props == null) {
      return null;
    }
    String? match(String name) {
      final String want = name.trim().toLowerCase();
      for (final MapEntry<String, Object?> e in props!.entries) {
        if (e.key.toLowerCase() == want && _prop(props, e.key) != null) {
          return e.key;
        }
      }
      return null;
    }

    if (requested != null && requested.trim().isNotEmpty) {
      return match(requested);
    }
    for (final String name in const <String>[
      'ISO_A2',
      'iso_a2',
      'ISO_A3',
      'ADM0_A3',
      'code',
      'CODE',
      'id',
      'ID',
      'NAME',
      'name',
    ]) {
      final String? found = match(name);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  static String? _autoKey(Map<String, Object?> props) {
    for (final String name in const <String>[
      'ISO_A2',
      'iso_a2',
      'ISO_A3',
      'ADM0_A3',
      'code',
      'CODE',
      'id',
      'ID',
      'NAME',
      'name',
    ]) {
      final String? v = _prop(props, name);
      if (v != null) {
        return v;
      }
    }
    return null;
  }

  static List<String> _aliases(
    Map<String, Object?> props,
    String key,
    String label,
  ) {
    final List<String> out = <String>[];
    void add(String? v) {
      if (v == null) {
        return;
      }
      final String t = v.trim();
      if (t.isEmpty || t == key || t == label || out.contains(t)) {
        return;
      }
      if (out.length < 12) {
        out.add(t);
      }
    }

    for (final String name in const <String>[
      'ISO_A2',
      'ISO_A3',
      'ADM0_A3',
      'NAME',
      'ADMIN',
      'NAME_EN',
      'NAME_AR',
      'NAME_FR',
    ]) {
      add(_prop(props, name));
    }
    return out;
  }

  static int _q(double degrees, double limit) {
    final double c = degrees.clamp(-limit, limit).toDouble();
    return (c * 100).round().clamp(-32767, 32767);
  }

  static void _u16(BytesBuilder b, int v) {
    final ByteData d = ByteData(2)..setUint16(0, v, Endian.little);
    b.add(d.buffer.asUint8List());
  }

  static void _i16(BytesBuilder b, int v) {
    final ByteData d = ByteData(2)..setInt16(0, v, Endian.little);
    b.add(d.buffer.asUint8List());
  }

  static void _str(BytesBuilder b, String text) {
    final List<int> bytes = utf8.encode(text);
    final int n = math.min(bytes.length, 255);
    b.addByte(n);
    b.add(bytes.sublist(0, n));
  }

  static int _readU16(ByteData data, int o) {
    if (o + 2 > data.lengthInBytes) {
      throw const ReportShapeException('Truncated shape layer');
    }
    return data.getUint16(o, Endian.little);
  }

  static int _readI16(ByteData data, int o) {
    if (o + 2 > data.lengthInBytes) {
      throw const ReportShapeException('Truncated shape layer');
    }
    return data.getInt16(o, Endian.little);
  }

  static (String, int) _readStr(Uint8List bytes, int o) {
    if (o >= bytes.length) {
      throw const ReportShapeException('Truncated shape layer');
    }
    final int n = bytes[o];
    final int end = o + 1 + n;
    if (end > bytes.length) {
      throw const ReportShapeException('Truncated shape layer');
    }
    return (utf8.decode(bytes.sublist(o + 1, end), allowMalformed: true), end);
  }
}

/// Bundled admin-0 countries, keyed by ISO code and by English, Arabic,
/// and French names.
abstract final class WorldCountries {
  static ReportShapeLayer? _layer;

  /// Decoded world atlas.
  static ReportShapeLayer get layer =>
      _layer ??= ReportShapeLayer.decode(worldCountriesAtlas);
}

/// `world` and `countries` are the bundled atlas. Anything else is an
/// embedded shape layer.
abstract final class ReportShapes {
  /// Name of the bundled atlas.
  static const String world = 'world';

  /// Whether [name] selects [WorldCountries].
  static bool isWorld(String name) {
    final String n = name.trim().toLowerCase();
    return n.isEmpty || n == 'world' || n == 'countries';
  }

  /// Layer for a chart `shape` attribute.
  static ReportShapeLayer? resolve(
    String name,
    Map<String, Uint8List> embedded,
  ) {
    if (isWorld(name)) {
      return WorldCountries.layer;
    }
    final Uint8List? bytes = embedded[name];
    if (bytes == null) {
      return null;
    }
    try {
      return ReportShapeLayer.decode(bytes);
    } on ReportShapeException {
      return null;
    }
  }
}

class _Dbf {
  _Dbf(this.fields, this.rows);

  final List<String> fields;
  final List<List<String>> rows;

  static _Dbf parse(Uint8List bytes) {
    if (bytes.length < 32) {
      throw const ReportShapeException('The .dbf file is too small');
    }
    final ByteData data = ByteData.sublistView(bytes);
    final int records = data.getUint32(4, Endian.little);
    final int header = data.getUint16(8, Endian.little);
    final int record = data.getUint16(10, Endian.little);
    final List<(String, int, int)> fields = <(String, int, int)>[];
    var at = 32;
    var width = 1;
    while (at + 32 <= header && bytes[at] != 0x0D) {
      final String name = latin1
          .decode(bytes.sublist(at, at + 11))
          .replaceAll('\u0000', '')
          .trim();
      final int length = bytes[at + 16];
      fields.add((name, width, length));
      width += length;
      at += 32;
    }
    final List<List<String>> rows = <List<String>>[];
    for (int r = 0; r < records; r++) {
      final int start = header + r * record;
      if (start + record > bytes.length) {
        break;
      }
      rows.add(<String>[
        for (final (String, int, int) f in fields)
          _cell(bytes.sublist(start + f.$2, start + f.$2 + f.$3)),
      ]);
    }
    return _Dbf(<String>[
      for (final (String, int, int) f in fields) f.$1,
    ], rows);
  }

  int column(String? name) {
    if (name == null || name.trim().isEmpty) {
      return -1;
    }
    final String want = name.trim().toLowerCase();
    for (int i = 0; i < fields.length; i++) {
      if (fields[i].toLowerCase() == want) {
        return i;
      }
    }
    return -1;
  }

  int preferredKey() {
    for (final String name in const <String>[
      'iso_a2',
      'iso_a3',
      'adm0_a3',
      'code',
      'id',
      'name',
    ]) {
      final int i = column(name);
      if (i >= 0) {
        return i;
      }
    }
    return fields.isEmpty ? -1 : 0;
  }

  static String _cell(List<int> bytes) {
    try {
      return utf8.decode(bytes).trim();
    } on FormatException {
      return latin1.decode(bytes).trim();
    }
  }
}
