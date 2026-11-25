/// Original report coordinates use one-based physical text line numbers.
final class MtnMinecraftCrashSection {
  MtnMinecraftCrashSection({required this.title, required this.lineNumber, required Iterable<String> lines})
      : lines = List<String>.unmodifiable(lines);

  final String title;
  final int lineNumber;
  final List<String> lines;
}

final class MtnMinecraftCrashStackFrame {
  const MtnMinecraftCrashStackFrame({required this.symbol, required this.location, required this.lineNumber});

  final String symbol;
  final String location;
  final int lineNumber;

  String get className {
    final int end = symbol.lastIndexOf('.');
    if (end < 0) return symbol;
    final String owner = symbol.substring(0, end);
    return owner.substring(owner.lastIndexOf('/') + 1);
  }
}

enum MtnMinecraftCrashExceptionRelation { root, causedBy, suppressed }

final class MtnMinecraftCrashException {
  MtnMinecraftCrashException({
    required this.type,
    required this.message,
    required this.lineNumber,
    required this.relation,
    required Iterable<MtnMinecraftCrashStackFrame> frames,
  }) : frames = List<MtnMinecraftCrashStackFrame>.unmodifiable(frames);

  final String type;
  final String message;
  final int lineNumber;
  final MtnMinecraftCrashExceptionRelation relation;
  final List<MtnMinecraftCrashStackFrame> frames;
}

/// Fabric runtime identity, not a provider project ID. Nested IDs are retained.
final class MtnMinecraftCrashMod {
  const MtnMinecraftCrashMod({required this.id, this.name, this.version, this.parentId, this.lineNumber});

  final String id;
  final String? name;
  final String? version;
  final String? parentId;
  final int? lineNumber;
}

final class MtnMinecraftCrashReport {
  MtnMinecraftCrashReport({
    required this.rawText,
    required this.time,
    required this.description,
    required Iterable<MtnMinecraftCrashSection> sections,
    required Iterable<MtnMinecraftCrashException> exceptions,
    required Iterable<MtnMinecraftCrashMod> mods,
    required Map<String, String> systemDetails,
  }) : sections = List<MtnMinecraftCrashSection>.unmodifiable(sections),
       exceptions = List<MtnMinecraftCrashException>.unmodifiable(exceptions),
       mods = List<MtnMinecraftCrashMod>.unmodifiable(mods),
       systemDetails = Map<String, String>.unmodifiable(systemDetails);

  final String rawText;
  // Preserve Minecraft's local timestamp text; do not invent a time zone.
  final String? time;
  final String? description;
  final List<MtnMinecraftCrashSection> sections;
  final List<MtnMinecraftCrashException> exceptions;
  final List<MtnMinecraftCrashMod> mods;
  final Map<String, String> systemDetails;

  String? get minecraftVersion => systemDetails['Minecraft Version'] ?? _modVersion('minecraft');
  String? get javaVersion => systemDetails['Java Version'] ?? _modVersion('java');
  String? get fabricLoaderVersion => _modVersion('fabricloader');

  String? _modVersion(String id) {
    for (final MtnMinecraftCrashMod mod in mods) {
      if (mod.id == id) return mod.version;
    }
    return null;
  }
}
