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
    required this.exitCode,
  }) : mods = Map<String, MtnMinecraftCrashMod>.unmodifiable({
         for (final MtnMinecraftCrashMod mod in installedMods) mod.id: mod,
         for (final MtnMinecraftCrashMod mod in report?.mods ?? const <MtnMinecraftCrashMod>[]) mod.id: mod,
       }),
       sources = Map<MtnMinecraftCrashSource, List<String>>.unmodifiable({
         if (report != null) MtnMinecraftCrashSource.crashReport: List<String>.unmodifiable(const LineSplitter().convert(report.rawText)),
         if (gameLog != null) MtnMinecraftCrashSource.gameLog: List<String>.unmodifiable(const LineSplitter().convert(gameLog)),
         if (nativeLog != null) MtnMinecraftCrashSource.nativeLog: List<String>.unmodifiable(const LineSplitter().convert(nativeLog)),
       });

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

  /// Bounded continuation of one diagnostic, never crossing another cause or section.
  List<MtnMinecraftCrashEvidence> diagnosticBlock(MtnMinecraftCrashEvidence anchor) {
    final List<String> lines = sources[anchor.source]!;
    final int start = anchor.lineNumber! - 1;
    final List<MtnMinecraftCrashEvidence> result = [anchor];
    for (int i = start + 1; i < lines.length && i <= start + 12; i++) {
      final String trimmed = lines[i].trim();
      if (trimmed.startsWith('Caused by:') || trimmed.startsWith('Suppressed:') ||
          trimmed.startsWith('at ') || trimmed.startsWith('-- ') || trimmed.startsWith('---- ') ||
          trimmed == 'Fabric Mods:' || RegExp(r'^\[\d{2}:\d{2}:\d{2}').hasMatch(trimmed)) break;
      if (trimmed.isNotEmpty) {
        result.add(MtnMinecraftCrashEvidence(source: anchor.source, lineNumber: i + 1, text: lines[i]));
      }
    }
    return result;
  }

  MtnMinecraftCrashModFinding attribution(String id, MtnMinecraftCrashConfidence confidence, Iterable<MtnMinecraftCrashEvidence> evidence) =>
      MtnMinecraftCrashModFinding(mod: mods[id] ?? MtnMinecraftCrashMod(id: id), confidence: confidence, evidence: evidence);
}

abstract class MtnMinecraftCrashRuleAbs {
  const MtnMinecraftCrashRuleAbs();

  Iterable<MtnMinecraftCrashFinding> evaluate(MtnMinecraftCrashRuleContext context);
}
