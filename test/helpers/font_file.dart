import 'dart:io';
import 'dart:typed_data';

/// Just enough of a TrueType/OpenType reader to answer two questions about a
/// bundled font: does it have a glyph for a character (cmap table), and does
/// it offer an OpenType feature such as `tnum` (GSUB table).
class FontFile {
  FontFile._(this._data, this._tables);

  factory FontFile.read(String path) {
    final data = ByteData.sublistView(File(path).readAsBytesSync());
    final tables = <String, int>{};
    final count = data.getUint16(4);
    for (var i = 0; i < count; i++) {
      final record = 12 + 16 * i;
      tables[_tag(data, record)] = data.getUint32(record + 8);
    }
    return FontFile._(data, tables);
  }

  final ByteData _data;
  final Map<String, int> _tables;

  static String _tag(ByteData data, int offset) => String.fromCharCodes([
    for (var i = 0; i < 4; i++) data.getUint8(offset + i),
  ]);

  /// True when the font maps [codePoint] to a real glyph (not glyph 0,
  /// the "missing" box).
  bool hasGlyph(int codePoint) => _glyphId(codePoint) != 0;

  int _glyphId(int codePoint) {
    final cmap = _tables['cmap']!;
    final count = _data.getUint16(cmap + 2);
    int? format4;
    for (var i = 0; i < count; i++) {
      final record = cmap + 4 + 8 * i;
      final platform = _data.getUint16(record);
      final encoding = _data.getUint16(record + 2);
      final subtable = cmap + _data.getUint32(record + 4);
      final format = _data.getUint16(subtable);
      // Windows full Unicode (format 12) covers everything; prefer it.
      if (platform == 3 && encoding == 10 && format == 12) {
        return _lookupFormat12(subtable, codePoint);
      }
      if (format == 4 && (platform == 3 || platform == 0)) format4 ??= subtable;
    }
    return format4 == null ? 0 : _lookupFormat4(format4, codePoint);
  }

  int _lookupFormat12(int table, int codePoint) {
    final groups = _data.getUint32(table + 12);
    for (var i = 0; i < groups; i++) {
      final group = table + 16 + 12 * i;
      final start = _data.getUint32(group);
      final end = _data.getUint32(group + 4);
      if (codePoint >= start && codePoint <= end) {
        return _data.getUint32(group + 8) + codePoint - start;
      }
    }
    return 0;
  }

  int _lookupFormat4(int table, int codePoint) {
    if (codePoint > 0xFFFF) return 0;
    final segments = _data.getUint16(table + 6) ~/ 2;
    final ends = table + 14;
    final starts = ends + 2 * segments + 2;
    final deltas = starts + 2 * segments;
    final rangeOffsets = deltas + 2 * segments;
    for (var i = 0; i < segments; i++) {
      if (codePoint > _data.getUint16(ends + 2 * i)) continue;
      final start = _data.getUint16(starts + 2 * i);
      if (codePoint < start) return 0;
      final delta = _data.getUint16(deltas + 2 * i);
      final rangeOffsetAt = rangeOffsets + 2 * i;
      final rangeOffset = _data.getUint16(rangeOffsetAt);
      if (rangeOffset == 0) return (codePoint + delta) & 0xFFFF;
      final glyph = _data.getUint16(
        rangeOffsetAt + rangeOffset + 2 * (codePoint - start),
      );
      return glyph == 0 ? 0 : (glyph + delta) & 0xFFFF;
    }
    return 0;
  }

  /// OpenType feature tags in the GSUB table, e.g. `tnum`, `liga`.
  Set<String> get substitutionFeatures {
    final gsub = _tables['GSUB'];
    if (gsub == null) return {};
    final list = gsub + _data.getUint16(gsub + 6);
    final count = _data.getUint16(list);
    return {for (var i = 0; i < count; i++) _tag(_data, list + 2 + 6 * i)};
  }
}
