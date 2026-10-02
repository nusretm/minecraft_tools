import 'dart:typed_data';

import 'nbt_type.dart';

final class MtnMinecraftNbtList {
  MtnMinecraftNbtList({
    required this.elementType,
    required Iterable<MtnMinecraftNbtValue> values,
  }) : values = List<MtnMinecraftNbtValue>.unmodifiable(values) {
    if (this.values.isNotEmpty && elementType == MtnMinecraftNbtType.end) {
      throw ArgumentError.value(
        elementType,
        'elementType',
        'TAG_End cannot be the type of a non-empty TAG_List',
      );
    }
    for (final MtnMinecraftNbtValue value in this.values) {
      if (value.type != elementType) {
        throw ArgumentError.value(
          value.type,
          'values',
          'Every TAG_List value must match elementType',
        );
      }
    }
  }

  final MtnMinecraftNbtType elementType;
  final List<MtnMinecraftNbtValue> values;
}

final class MtnMinecraftNbtValue {
  MtnMinecraftNbtValue._(this.type, this.value);

  factory MtnMinecraftNbtValue.byte(int value) {
    _checkRange(value, -0x80, 0x7f, 'value');
    return MtnMinecraftNbtValue._(MtnMinecraftNbtType.byte, value);
  }

  factory MtnMinecraftNbtValue.short(int value) {
    _checkRange(value, -0x8000, 0x7fff, 'value');
    return MtnMinecraftNbtValue._(MtnMinecraftNbtType.short, value);
  }

  factory MtnMinecraftNbtValue.intValue(int value) {
    _checkRange(value, -0x80000000, 0x7fffffff, 'value');
    return MtnMinecraftNbtValue._(MtnMinecraftNbtType.intValue, value);
  }

  factory MtnMinecraftNbtValue.long(int value) {
    _checkRange(
      value,
      -0x8000000000000000,
      0x7fffffffffffffff,
      'value',
    );
    return MtnMinecraftNbtValue._(MtnMinecraftNbtType.long, value);
  }

  factory MtnMinecraftNbtValue.float(double value) =>
      MtnMinecraftNbtValue._(MtnMinecraftNbtType.float, value);

  factory MtnMinecraftNbtValue.doubleValue(double value) =>
      MtnMinecraftNbtValue._(MtnMinecraftNbtType.doubleValue, value);

  factory MtnMinecraftNbtValue.byteArray(Iterable<int> value) {
    final List<int> snapshot = value.toList(growable: false);
    for (final int byte in snapshot) {
      if (byte < 0 || byte > 0xff) {
        throw ArgumentError.value(
          byte,
          'value',
          'TAG_Byte_Array values must be raw bytes in the range 0..255',
        );
      }
    }
    return MtnMinecraftNbtValue._(
      MtnMinecraftNbtType.byteArray,
      Uint8List.fromList(snapshot),
    );
  }

  factory MtnMinecraftNbtValue.string(String value) =>
      MtnMinecraftNbtValue._(MtnMinecraftNbtType.string, value);

  factory MtnMinecraftNbtValue.list(MtnMinecraftNbtList value) =>
      MtnMinecraftNbtValue._(MtnMinecraftNbtType.list, value);

  factory MtnMinecraftNbtValue.compound(
    Map<String, MtnMinecraftNbtValue> value,
  ) =>
      MtnMinecraftNbtValue._(
        MtnMinecraftNbtType.compound,
        Map<String, MtnMinecraftNbtValue>.unmodifiable(value),
      );

  factory MtnMinecraftNbtValue.intArray(Iterable<int> value) {
    final List<int> snapshot = value.toList(growable: false);
    for (final int item in snapshot) {
      _checkRange(item, -0x80000000, 0x7fffffff, 'value');
    }
    return MtnMinecraftNbtValue._(
      MtnMinecraftNbtType.intArray,
      List<int>.unmodifiable(snapshot),
    );
  }

  factory MtnMinecraftNbtValue.longArray(Iterable<int> value) {
    final List<int> snapshot = value.toList(growable: false);
    for (final int item in snapshot) {
      _checkRange(
        item,
        -0x8000000000000000,
        0x7fffffffffffffff,
        'value',
      );
    }
    return MtnMinecraftNbtValue._(
      MtnMinecraftNbtType.longArray,
      List<int>.unmodifiable(snapshot),
    );
  }

  final MtnMinecraftNbtType type;
  final Object value;

  int get asByte => _typed<int>(MtnMinecraftNbtType.byte);

  int get asShort => _typed<int>(MtnMinecraftNbtType.short);

  int get asInt => _typed<int>(MtnMinecraftNbtType.intValue);

  int get asLong => _typed<int>(MtnMinecraftNbtType.long);

  double get asFloat => _typed<double>(MtnMinecraftNbtType.float);

  double get asDouble => _typed<double>(MtnMinecraftNbtType.doubleValue);

  Uint8List get asByteArray =>
      Uint8List.fromList(_typed<Uint8List>(MtnMinecraftNbtType.byteArray));

  String get asString => _typed<String>(MtnMinecraftNbtType.string);

  MtnMinecraftNbtList get asList =>
      _typed<MtnMinecraftNbtList>(MtnMinecraftNbtType.list);

  Map<String, MtnMinecraftNbtValue> get asCompound =>
      _typed<Map<String, MtnMinecraftNbtValue>>(
        MtnMinecraftNbtType.compound,
      );

  List<int> get asIntArray => _typed<List<int>>(
        MtnMinecraftNbtType.intArray,
      );

  List<int> get asLongArray => _typed<List<int>>(
        MtnMinecraftNbtType.longArray,
      );

  T _typed<T>(MtnMinecraftNbtType expected) {
    if (type != expected) {
      throw StateError(
        'NBT value is ${type.name}, not ${expected.name}',
      );
    }
    return value as T;
  }
}

void _checkRange(int value, int minimum, int maximum, String name) {
  if (value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Value is outside the NBT integer range',
    );
  }
}
