import 'dart:convert';

import '../model/crash_analysis.dart';
import '../model/crash_report.dart';

/// Shared immutable inputs. Rules cannot read files or mutate installed content.
final class MtnMinecraftCrashRuleContext {
  MtnMinecraftCrashRuleContext({
    required MtnMinecraftCrashReport? report,
    required String? gameLog,
    required String? nativeLog,
    required Iterable<MtnMinecraftCrashMod> installedMods,
    required Map<String, String> classOwners,
    required this.exitCode,
  }) : classOwners = Map<String, String>.unmodifiable(classOwners.map((name, id) => MapEntry(name.replaceAll('/', '.'), id))),
       mods = Map<String, MtnMinecraftCrashMod>.unmodifiable({
         for (final MtnMinecraftCrashMod mod in installedMods) mod.id: mod,
         for (final MtnMinecraftCrashMod mod in report?.mods ?? const <MtnMinecraftCrashMod>[]) mod.id: mod,
       }),
       sources = Map<MtnMinecraftCrashSource, List<String>>.unmodifiable({
         if (report != null) MtnMinecraftCrashSource.crashReport: List<String>.unmodifiable(const LineSplitter().convert(report.rawText)),
         if (gameLog != null) MtnMinecraftCrashSource.gameLog: List<String>.unmodifiable(const LineSplitter().convert(gameLog)),
         if (nativeLog != null) MtnMinecraftCrashSource.nativeLog: List<String>.unmodifiable(const LineSplitter().convert(nativeLog)),
       });

  final Map<String, String> classOwners;
  final Map<String, MtnMinecraftCrashMod> mods;
  final Map<MtnMinecraftCrashSource, List<String>> sources;
  final int? exitCode;

  /// Report system inventory is not diagnostic evidence by itself.
  Iterable<MtnMinecraftCrashEvidence> get diagnosticLines sync* {
    for (final MapEntry<MtnMinecraftCrashSource, List<String>> source in sources.entries) {
      for (int i = 0; i < source.value.length; i++) {
        final String line = source.value[i];
        if (source.key == MtnMinecraftCrashSource.crashReport && line.trim() == '-- System Details --') break;
        yield MtnMinecraftCrashEvidence(source: source.key, lineNumber: i + 1, text: line);
      }
    }
  }

  /// Strip Minecraft's ordinary log prefix, but not arbitrary message text.
  String diagnosticText(MtnMinecraftCrashEvidence evidence) => evidence.text.trimLeft()
      .replaceFirst(RegExp(r'^\[[^\]]+\]\s+\[[^\]]+\]:\s*'), '');

  bool hasException(MtnMinecraftCrashEvidence evidence, RegExp signature) {
    final String text = diagnosticText(evidence);
    final RegExpMatch? header = RegExp(r'^(?:(?:Caused by:|Suppressed:)\s*|Exception in thread "[^"]+"\s+)?((?:[A-Za-z_$][\w$]*\.)*[A-Za-z_$][\w$]*)(?::|\s*$)').firstMatch(text);
    return header != null && signature.hasMatch(header.group(1)!);
  }

  /// Bounded continuation of one diagnostic, never crossing another cause or section.
  List<MtnMinecraftCrashEvidence> diagnosticBlock(MtnMinecraftCrashEvidence anchor) {
    final List<String> lines = sources[anchor.source]!;
    final int start = anchor.lineNumber! - 1;
    final List<MtnMinecraftCrashEvidence> result = [anchor];
    for (int i = start + 1; i < lines.length && i <= start + 12; i++) {
      final String trimmed = lines[i].trim();
      if (trimmed.startsWith('Caused by:') || trimmed.startsWith('Suppressed:') ||
          trimmed.startsWith('at ') || trimmed.startsWith('-- ') || trimmed.startsWith('---- ') ||
          trimmed == 'Fabric Mods:' || RegExp(r'^\[\d{2}:\d{2}:\d{2}').hasMatch(trimmed)) {
        break;
      }
      if (trimmed.isNotEmpty) {
        result.add(MtnMinecraftCrashEvidence(source: anchor.source, lineNumber: i + 1, text: lines[i]));
      }
    }
    return result;
  }

  String? ownerForClass(String name) {
    final String? id = classOwners[name.replaceAll('/', '.')];
    return id != null && mods.containsKey(id) ? id : null;
  }

  MtnMinecraftCrashEvidence? firstStackFrame(MtnMinecraftCrashEvidence anchor) {
    final List<String> lines = sources[anchor.source]!;
    for (int i = anchor.lineNumber!; i < lines.length && i <= anchor.lineNumber! + 12; i++) {
      final String text = lines[i].trim();
      if (text.startsWith('Caused by:') || text.startsWith('Suppressed:') ||
          text.startsWith('-- ') || text.startsWith('---- ') || text.startsWith('[')) {
        break;
      }
      if (text.startsWith('at ')) {
        return MtnMinecraftCrashEvidence(source: anchor.source, lineNumber: i + 1, text: lines[i]);
      }
    }
    return null;
  }

  MtnMinecraftCrashModFinding attribution(String id, MtnMinecraftCrashConfidence confidence, Iterable<MtnMinecraftCrashEvidence> evidence) =>
      MtnMinecraftCrashModFinding(mod: mods[id] ?? MtnMinecraftCrashMod(id: id), confidence: confidence, evidence: evidence);
}

abstract class MtnMinecraftCrashRuleAbs {
  const MtnMinecraftCrashRuleAbs();

  Iterable<MtnMinecraftCrashFinding> evaluate(MtnMinecraftCrashRuleContext context);
}
