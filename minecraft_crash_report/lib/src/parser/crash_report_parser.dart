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
    int? fabricIndent;
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
        fabricIndent = null;
        continue;
      }
      if (title != null) sectionLines.add(line);
      if (title == null) {
        if (line.startsWith('Time:')) time ??= line.substring(5).trim();
        if (line.startsWith('Description:')) description ??= line.substring(12).trim();
      }
      if (title == 'System Details') {
        final String trimmed = line.trimLeft();
        if (trimmed.isEmpty) continue;
        final int indent = line.substring(0, line.length - trimmed.length).replaceAll('\t', '    ').length;
        if (trimmed.trimRight() == 'Fabric Mods:') {
          fabricIndent = indent;
          continue;
        }
        if (fabricIndent != null && indent > fabricIndent) continue;
        fabricIndent = null;
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
