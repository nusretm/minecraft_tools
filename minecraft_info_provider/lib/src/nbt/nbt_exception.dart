enum MtnMinecraftNbtError {
  invalidTypeId(8001),
  invalidRoot(8002),
  unexpectedEndOfData(8003),
  invalidLength(8004),
  invalidString(8005),
  invalidValue(8006),
  trailingData(8007);

  const MtnMinecraftNbtError(this.code);

  final int code;
}

final class MtnMinecraftNbtException implements Exception {
  const MtnMinecraftNbtException(
    this.error, {
    this.offset,
  });

  final MtnMinecraftNbtError error;
  final int? offset;

  @override
  String toString() {
    final int? value = offset;
    if (value == null) {
      return 'MtnMinecraftNbtException(${error.name})';
    }
    return 'MtnMinecraftNbtException(${error.name}, offset: $value)';
  }
}
