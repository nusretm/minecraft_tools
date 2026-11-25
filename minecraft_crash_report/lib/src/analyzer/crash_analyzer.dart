import '../model/crash_analysis.dart';
import '../model/crash_report.dart';
import 'crash_rule.dart';
import 'rules/crash_rule_environment.dart';
import 'rules/crash_rule_java.dart';
import 'rules/crash_rule_mixin.dart';

/// Deterministic analysis of caller-associated diagnostic text. No I/O or AI.
final class MtnMinecraftCrashAnalyzer {
  const MtnMinecraftCrashAnalyzer();

  static const List<MtnMinecraftCrashRuleAbs> _rules = [
    MtnMinecraftCrashRuleMixin(),
    MtnMinecraftCrashRuleJava(),
    MtnMinecraftCrashRuleEnvironment(),
  ];

  MtnMinecraftCrashAnalysis analyze({
    MtnMinecraftCrashReport? report,
    String? gameLog,
    String? nativeLog,
    int? exitCode,
    Iterable<MtnMinecraftCrashMod> installedMods = const [],
  }) {
    final MtnMinecraftCrashRuleContext context = MtnMinecraftCrashRuleContext(report: report, gameLog: gameLog,
      nativeLog: nativeLog, installedMods: installedMods, exitCode: exitCode);
    final List<MtnMinecraftCrashFinding> findings = [
      for (final MtnMinecraftCrashRuleAbs rule in _rules) ...rule.evaluate(context),
    ];
    // Prefer the concrete injection failure over an outer Mixin transformer wrapper.
    // At the same specificity prefer a finding with explicit owner evidence.
    final List<MtnMinecraftCrashFinding> ordered = [
      for (final finding in findings.where((item) => item.type == MtnMinecraftCrashType.mixinInjection && item.suspectedMods.isNotEmpty)) finding,
      for (final finding in findings.where((item) => item.type == MtnMinecraftCrashType.mixinInjection && item.suspectedMods.isEmpty)) finding,
      for (final finding in findings.where((item) => item.type != MtnMinecraftCrashType.mixinInjection && item.type != MtnMinecraftCrashType.mixinApply)) finding,
      for (final finding in findings.where((item) => item.type == MtnMinecraftCrashType.mixinApply)) finding,
    ];
    if (ordered.isEmpty) {
      ordered.add(MtnMinecraftCrashFinding(type: MtnMinecraftCrashType.unknown, confidence: MtnMinecraftCrashConfidence.low,
        evidence: [
          if (exitCode != null) MtnMinecraftCrashEvidence(source: MtnMinecraftCrashSource.exitCode, text: exitCode.toString()),
        ],
        recommendations: const [MtnMinecraftCrashRecommendation(MtnMinecraftCrashRecommendationType.inspectLogs)]));
    }
    return MtnMinecraftCrashAnalysis(findings: ordered, exitCode: exitCode);
  }
}
