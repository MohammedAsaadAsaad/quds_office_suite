import 'dart:typed_data';

import '../opc/zip/deflate_codec.dart';

/// FlateDecode wrapper for PDF content and font streams.
abstract final class PdfFlate {
  /// compress API.
  static Uint8List compress(List<int> data) {
    final Uint8List raw = RawDeflate.deflate(data);
    // Wrap raw DEFLATE in a zlib container (CMF/FLG + Adler-32).
    return _zlibWrap(raw, data);
  }

  /// Inflates a zlib-wrapped content stream produced by [compress].
  static Uint8List decompress(Uint8List zlib) {
    if (zlib.length < 6) {
      throw const FormatException('Truncated zlib stream');
    }
    return RawDeflate.inflate(Uint8List.sublistView(zlib, 2, zlib.length - 4));
  }

  static Uint8List _zlibWrap(Uint8List rawDeflate, List<int> original) {
    final Uint8List out = Uint8List(rawDeflate.length + 6);
    out[0] = 0x78; // CMF: deflate, 32k window
    out[1] = 0x9C; // FLG: default check bits
    out.setRange(2, 2 + rawDeflate.length, rawDeflate);
    final int adler = _adler32(original);
    final int tail = out.length - 4;
    out[tail] = (adler >> 24) & 0xFF;
    out[tail + 1] = (adler >> 16) & 0xFF;
    out[tail + 2] = (adler >> 8) & 0xFF;
    out[tail + 3] = adler & 0xFF;
    return out;
  }

  static int _adler32(List<int> data) {
    var a = 1;
    var b = 0;
    for (final int byte in data) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
    }
    return ((b << 16) | a) & 0xFFFFFFFF;
  }
}
