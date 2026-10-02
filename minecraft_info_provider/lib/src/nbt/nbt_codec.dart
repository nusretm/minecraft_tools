import 'dart:typed_data';

import 'nbt_document.dart';
import 'nbt_exception.dart';
import 'nbt_type.dart';
import 'nbt_value.dart';

final class MtnMinecraftNbtCodec {
  const MtnMinecraftNbtCodec();

  MtnMinecraftNbtDocument decode(List<int> source) {
    final Uint8List bytes = Uint8List.fromList(source);
    final _NbtReader reader = _NbtReader(bytes);
    final MtnMinecraftNbtType type = reader.readType();
    if (type == MtnMinecraftNbtType.end) {
      throw MtnMinecraftNbtException(
        MtnMinecraftNbtError.invalidRoot,
        offset: 0,
      );
    }
    final String name = reader.readString();
    final MtnMinecraftNbtValue root = reader.readPayload(type);
    if (!reader.isAtEnd) {
      throw MtnMinecraftNbtException(
        MtnMinecraftNbtError.trailingData,
        offset: reader.offset,
      );
    }
    return MtnMinecraftNbtDocument(name: name, root: root);
  }

  Uint8List encode(MtnMinecraftNbtDocument document) {
    final _NbtWriter writer = _NbtWriter();
    writer.writeByte(document.root.type.id);
    writer.writeString(document.name);
    writer.writePayload(document.root);
    return writer.takeBytes();
  }
}

final class _NbtReader {
  _NbtReader(this.bytes) : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  int offset = 0;

  bool get isAtEnd => offset == bytes.length;

  MtnMinecraftNbtType readType() {
    final int typeOffset = offset;
    final int id = readUnsignedByte();
    final MtnMinecraftNbtType? type = MtnMinecraftNbtType.tryFromId(id);
    if (type == null) {
      throw MtnMinecraftNbtException(
        MtnMinecraftNbtError.invalidTypeId,
        offset: typeOffset,
      );
    }
    return type;
  }

  MtnMinecraftNbtValue readPayload(MtnMinecraftNbtType type) {
    return switch (type) {
      MtnMinecraftNbtType.end => throw MtnMinecraftNbtException(
          MtnMinecraftNbtError.invalidValue,
          offset: offset,
        ),
      MtnMinecraftNbtType.byte => MtnMinecraftNbtValue.byte(readInt8()),
      MtnMinecraftNbtType.short => MtnMinecraftNbtValue.short(readInt16()),
      MtnMinecraftNbtType.intValue =>
        MtnMinecraftNbtValue.intValue(readInt32()),
      MtnMinecraftNbtType.long => MtnMinecraftNbtValue.long(readInt64()),
      MtnMinecraftNbtType.float => MtnMinecraftNbtValue.float(readFloat32()),
      MtnMinecraftNbtType.doubleValue =>
        MtnMinecraftNbtValue.doubleValue(readFloat64()),
      MtnMinecraftNbtType.byteArray =>
        MtnMinecraftNbtValue.byteArray(readByteArray()),
      MtnMinecraftNbtType.string =>
        MtnMinecraftNbtValue.string(readString()),
      MtnMinecraftNbtType.list => MtnMinecraftNbtValue.list(readList()),
      MtnMinecraftNbtType.compound =>
        MtnMinecraftNbtValue.compound(readCompound()),
      MtnMinecraftNbtType.intArray =>
        MtnMinecraftNbtValue.intArray(readIntArray()),
      MtnMinecraftNbtType.longArray =>
        MtnMinecraftNbtValue.longArray(readLongArray()),
    };
  }

  int readUnsignedByte() {
    _require(1);
    return bytes[offset++];
  }

  int readInt8() {
    _require(1);
    final int value = _data.getInt8(offset);
    offset += 1;
    return value;
  }

  int readInt16() {
    _require(2);
    final int value = _data.getInt16(offset, Endian.big);
    offset += 2;
    return value;
  }

  int readUnsignedInt16() {
    _require(2);
    final int value = _data.getUint16(offset, Endian.big);
    offset += 2;
    return value;
  }

  int readInt32() {
    _require(4);
    final int value = _data.getInt32(offset, Endian.big);
    offset += 4;
    return value;
  }

  int readInt64() {
    _require(8);
    final int value = _data.getInt64(offset, Endian.big);
    offset += 8;
    return value;
  }

  double readFloat32() {
    _require(4);
    final double value = _data.getFloat32(offset, Endian.big);
    offset += 4;
    return value;
  }

  double readFloat64() {
    _require(8);
    final double value = _data.getFloat64(offset, Endian.big);
    offset += 8;
    return value;
  }

  Uint8List readByteArray() {
    final int length = readLength();
    _require(length);
    final Uint8List result =
        Uint8List.fromList(bytes.sublist(offset, offset + length));
    offset += length;
    return result;
  }

  List<int> readIntArray() {
    final int length = readLength();
    final List<int> result = <int>[];
    for (var index = 0; index < length; index++) {
      result.add(readInt32());
    }
    return result;
  }

  List<int> readLongArray() {
    final int length = readLength();
    final List<int> result = <int>[];
    for (var index = 0; index < length; index++) {
      result.add(readInt64());
    }
    return result;
  }

  MtnMinecraftNbtList readList() {
    final MtnMinecraftNbtType elementType = readType();
    final int length = readLength();
    if (length > 0 && elementType == MtnMinecraftNbtType.end) {
      throw MtnMinecraftNbtException(
        MtnMinecraftNbtError.invalidValue,
        offset: offset,
      );
    }
    final List<MtnMinecraftNbtValue> values = <MtnMinecraftNbtValue>[];
    for (var index = 0; index < length; index++) {
      values.add(readPayload(elementType));
    }
    return MtnMinecraftNbtList(
      elementType: elementType,
      values: values,
    );
  }

  Map<String, MtnMinecraftNbtValue> readCompound() {
    final Map<String, MtnMinecraftNbtValue> result =
        <String, MtnMinecraftNbtValue>{};
    while (true) {
      final MtnMinecraftNbtType type = readType();
      if (type == MtnMinecraftNbtType.end) return result;
      final String name = readString();
      result[name] = readPayload(type);
    }
  }

  String readString() {
    final int length = readUnsignedInt16();
    _require(length);
    final int start = offset;
    final int end = offset + length;
    final List<int> codeUnits = <int>[];
    while (offset < end) {
      final int first = bytes[offset++];
      if ((first & 0x80) == 0) {
        if (first == 0) {
          throw MtnMinecraftNbtException(
            MtnMinecraftNbtError.invalidString,
            offset: start,
          );
        }
        codeUnits.add(first);
        continue;
      }
      if ((first & 0xe0) == 0xc0) {
        if (offset >= end) {
          throw MtnMinecraftNbtException(
            MtnMinecraftNbtError.invalidString,
            offset: start,
          );
        }
        final int second = bytes[offset++];
        if ((second & 0xc0) != 0x80) {
          throw MtnMinecraftNbtException(
            MtnMinecraftNbtError.invalidString,
            offset: start,
          );
        }
        final int codeUnit = ((first & 0x1f) << 6) | (second & 0x3f);
        if (codeUnit == 0) {
          if (first != 0xc0 || second != 0x80) {
            throw MtnMinecraftNbtException(
              MtnMinecraftNbtError.invalidString,
              offset: start,
            );
          }
        } else if (codeUnit < 0x80) {
          throw MtnMinecraftNbtException(
            MtnMinecraftNbtError.invalidString,
            offset: start,
          );
        }
        codeUnits.add(codeUnit);
        continue;
      }
      if ((first & 0xf0) == 0xe0) {
        if (offset + 1 >= end) {
          throw MtnMinecraftNbtException(
            MtnMinecraftNbtError.invalidString,
            offset: start,
          );
        }
        final int second = bytes[offset++];
        final int third = bytes[offset++];
        if ((second & 0xc0) != 0x80 || (third & 0xc0) != 0x80) {
          throw MtnMinecraftNbtException(
            MtnMinecraftNbtError.invalidString,
            offset: start,
          );
        }
        final int codeUnit = ((first & 0x0f) << 12) |
            ((second & 0x3f) << 6) |
            (third & 0x3f);
        if (codeUnit < 0x800) {
          throw MtnMinecraftNbtException(
            MtnMinecraftNbtError.invalidString,
            offset: start,
          );
        }
        codeUnits.add(codeUnit);
        continue;
      }
      throw MtnMinecraftNbtException(
        MtnMinecraftNbtError.invalidString,
        offset: start,
      );
    }
    return String.fromCharCodes(codeUnits);
  }

  int readLength() {
    final int lengthOffset = offset;
    final int length = readInt32();
    if (length < 0) {
      throw MtnMinecraftNbtException(
        MtnMinecraftNbtError.invalidLength,
        offset: lengthOffset,
      );
    }
    return length;
  }

  void _require(int count) {
    if (count < 0 || offset + count > bytes.length) {
      throw MtnMinecraftNbtException(
        MtnMinecraftNbtError.unexpectedEndOfData,
        offset: offset,
      );
    }
  }
}

final class _NbtWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  Uint8List takeBytes() => _builder.takeBytes();

  void writePayload(MtnMinecraftNbtValue value) {
    switch (value.type) {
      case MtnMinecraftNbtType.end:
        throw const MtnMinecraftNbtException(
          MtnMinecraftNbtError.invalidValue,
        );
      case MtnMinecraftNbtType.byte:
        writeInt8(value.asByte);
        return;
      case MtnMinecraftNbtType.short:
        writeInt16(value.asShort);
        return;
      case MtnMinecraftNbtType.intValue:
        writeInt32(value.asInt);
        return;
      case MtnMinecraftNbtType.long:
        writeInt64(value.asLong);
        return;
      case MtnMinecraftNbtType.float:
        writeFloat32(value.asFloat);
        return;
      case MtnMinecraftNbtType.doubleValue:
        writeFloat64(value.asDouble);
        return;
      case MtnMinecraftNbtType.byteArray:
        final Uint8List values = value.asByteArray;
        writeInt32(values.length);
        _builder.add(values);
        return;
      case MtnMinecraftNbtType.string:
        writeString(value.asString);
        return;
      case MtnMinecraftNbtType.list:
        final MtnMinecraftNbtList list = value.asList;
        writeByte(list.elementType.id);
        writeInt32(list.values.length);
        for (final MtnMinecraftNbtValue item in list.values) {
          writePayload(item);
        }
        return;
      case MtnMinecraftNbtType.compound:
        for (final MapEntry<String, MtnMinecraftNbtValue> entry
            in value.asCompound.entries) {
          writeByte(entry.value.type.id);
          writeString(entry.key);
          writePayload(entry.value);
        }
        writeByte(MtnMinecraftNbtType.end.id);
        return;
      case MtnMinecraftNbtType.intArray:
        final List<int> values = value.asIntArray;
        writeInt32(values.length);
        for (final int item in values) {
          writeInt32(item);
        }
        return;
      case MtnMinecraftNbtType.longArray:
        final List<int> values = value.asLongArray;
        writeInt32(values.length);
        for (final int item in values) {
          writeInt64(item);
        }
        return;
    }
  }

  void writeByte(int value) => _builder.add(<int>[value & 0xff]);

  void writeInt8(int value) => writeByte(value);

  void writeInt16(int value) {
    final ByteData data = ByteData(2)..setInt16(0, value, Endian.big);
    _builder.add(data.buffer.asUint8List());
  }

  void writeInt32(int value) {
    final ByteData data = ByteData(4)..setInt32(0, value, Endian.big);
    _builder.add(data.buffer.asUint8List());
  }

  void writeInt64(int value) {
    final ByteData data = ByteData(8)..setInt64(0, value, Endian.big);
    _builder.add(data.buffer.asUint8List());
  }

  void writeFloat32(double value) {
    final ByteData data = ByteData(4)..setFloat32(0, value, Endian.big);
    _builder.add(data.buffer.asUint8List());
  }

  void writeFloat64(double value) {
    final ByteData data = ByteData(8)..setFloat64(0, value, Endian.big);
    _builder.add(data.buffer.asUint8List());
  }

  void writeString(String value) {
    final Uint8List encoded = _encodeModifiedUtf8(value);
    if (encoded.length > 0xffff) {
      throw const MtnMinecraftNbtException(
        MtnMinecraftNbtError.invalidValue,
      );
    }
    final ByteData length = ByteData(2)
      ..setUint16(0, encoded.length, Endian.big);
    _builder.add(length.buffer.asUint8List());
    _builder.add(encoded);
  }
}

Uint8List _encodeModifiedUtf8(String value) {
  final BytesBuilder builder = BytesBuilder(copy: false);
  for (var index = 0; index < value.length; index++) {
    final int codeUnit = value.codeUnitAt(index);
    if (codeUnit >= 0x0001 && codeUnit <= 0x007f) {
      builder.addByte(codeUnit);
    } else if (codeUnit <= 0x07ff) {
      builder
        ..addByte(0xc0 | ((codeUnit >> 6) & 0x1f))
        ..addByte(0x80 | (codeUnit & 0x3f));
    } else {
      builder
        ..addByte(0xe0 | ((codeUnit >> 12) & 0x0f))
        ..addByte(0x80 | ((codeUnit >> 6) & 0x3f))
        ..addByte(0x80 | (codeUnit & 0x3f));
    }
  }
  return builder.takeBytes();
}
