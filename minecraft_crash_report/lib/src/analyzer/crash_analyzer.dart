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
    if (findings.isEmpty) {
      findings.add(MtnMinecraftCrashFinding(type: MtnMinecraftCrashType.unknown, confidence: MtnMinecraftCrashConfidence.low,
        evidence: [
          if (exitCode != null) MtnMinecraftCrashEvidence(source: MtnMinecraftCrashSource.exitCode, text: exitCode.toString()),
        ],
        recommendations: const [MtnMinecraftCrashRecommendation(MtnMinecraftCrashRecommendationType.inspectLogs)]));
    }
    return MtnMinecraftCrashAnalysis(findings: findings, exitCode: exitCode);
  }
}
