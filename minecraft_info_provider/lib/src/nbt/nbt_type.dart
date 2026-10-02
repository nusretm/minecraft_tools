enum MtnMinecraftNbtType {
  end(0),
  byte(1),
  short(2),
  intValue(3),
  long(4),
  float(5),
  doubleValue(6),
  byteArray(7),
  string(8),
  list(9),
  compound(10),
  intArray(11),
  longArray(12);

  const MtnMinecraftNbtType(this.id);

  final int id;

  static MtnMinecraftNbtType? tryFromId(int id) => switch (id) {
        0 => MtnMinecraftNbtType.end,
        1 => MtnMinecraftNbtType.byte,
        2 => MtnMinecraftNbtType.short,
        3 => MtnMinecraftNbtType.intValue,
        4 => MtnMinecraftNbtType.long,
        5 => MtnMinecraftNbtType.float,
        6 => MtnMinecraftNbtType.doubleValue,
        7 => MtnMinecraftNbtType.byteArray,
        8 => MtnMinecraftNbtType.string,
        9 => MtnMinecraftNbtType.list,
        10 => MtnMinecraftNbtType.compound,
        11 => MtnMinecraftNbtType.intArray,
        12 => MtnMinecraftNbtType.longArray,
        _ => null,
      };
}
