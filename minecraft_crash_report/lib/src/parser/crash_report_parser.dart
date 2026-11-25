import 'dart:convert';

import '../model/crash_report.dart';
import 'crash_exception_parser.dart';
import 'crash_mod_list_parser.dart';

/// Accepts full reports, excerpts and incomplete reports without fabricating fields.
final class MtnMinecraftCrashReportParser {
  const MtnMinecraftCrashReportParser();

  static final RegExp _section = RegExp(r'^--\s+(.+?)\s+--$');
  static final RegExp _detail = RegExp(r'^\s*([^:]+):\s*(.+)$');

  MtnMinecraftCrashReport parse(String text) {
    final List<String> lines = const LineSplitter().convert(text);
    final List<MtnMinecraftCrashSection> sections = [];
    final Map<String, String> details = {};
    String? time;
    String? description;
    String? title;
    int start = 0;
    final List<String> sectionLines = [];
    bool inFabricMods = false;
    void finish() {
      final String? current = title;
      if (current != null) {
        sections.add(MtnMinecraftCrashSection(title: current, lineNumber: start, lines: sectionLines));
      }
      sectionLines.clear();
    }
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final RegExpMatch? heading = _section.firstMatch(line.trim());
      if (heading != null) {
        finish();
        title = heading.group(1)!;
        start = i + 1;
        inFabricMods = false;
        continue;
      }
      if (title != null) sectionLines.add(line);
      if (title == null) {
        if (line.startsWith('Time:')) time ??= line.substring(5).trim();
        if (line.startsWith('Description:')) description ??= line.substring(12).trim();
      }
      if (title == 'System Details') {
        if (line.trim() == 'Fabric Mods:') {
          inFabricMods = true;
          continue;
        }
        // System detail rows have a single indent; nested mod rows do not.
        final String trimmed = line.trimLeft();
        if (line.startsWith('\t\t') || line.startsWith('        ')) continue;
        if (trimmed.isEmpty) continue;
        if (inFabricMods) inFabricMods = false;
        final RegExpMatch? field = _detail.firstMatch(line);
        if (field != null) details[field.group(1)!.trim()] = field.group(2)!.trim();
      }
    }
    finish();
    return MtnMinecraftCrashReport(rawText: text, time: time, description: description,
      sections: sections, exceptions: const MtnMinecraftCrashExceptionParser().parse(lines),
      mods: const MtnMinecraftCrashModListParser().parse(lines), systemDetails: details);
  }
}
