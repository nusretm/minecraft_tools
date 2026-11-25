import '../model/crash_report.dart';

final class MtnMinecraftCrashModListParser {
  const MtnMinecraftCrashModListParser();

  static final RegExp _entry = RegExp(r'^([ \t]+)([a-z][a-z0-9_-]*):[ \t]+(.+)$');
  static final RegExp _version = RegExp(r'^(.*\S)\s+([vV]?\d\S*|\$\{[^}]+\})$');

  int _indent(String text) => text.replaceAll('\t', '    ').length;

  List<MtnMinecraftCrashMod> parse(List<String> lines) {
    final List<MtnMinecraftCrashMod> mods = [];
    final List<({int indent, String id})> parents = [];
    int? headerIndent;
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      if (line.trim() == 'Fabric Mods:') {
        headerIndent = _indent(line.substring(0, line.length - line.trimLeft().length));
        parents.clear();
        continue;
      }
      final int? threshold = headerIndent;
      if (threshold == null || line.trim().isEmpty) continue;
      final RegExpMatch? entry = _entry.firstMatch(line);
      if (entry == null || _indent(entry.group(1)!) <= threshold) {
        headerIndent = null;
        parents.clear();
        continue;
      }
      final int indent = _indent(entry.group(1)!);
      final String id = entry.group(2)!;
      final String label = entry.group(3)!.trim();
      final RegExpMatch? version = _version.firstMatch(label);
      while (parents.isNotEmpty && parents.last.indent >= indent) {
        parents.removeLast();
      }
      mods.add(MtnMinecraftCrashMod(id: id, name: version?.group(1) ?? label,
        version: version?.group(2), parentId: parents.isEmpty ? null : parents.last.id, lineNumber: i + 1));
      parents.add((indent: indent, id: id));
    }
    return mods;
  }
}
