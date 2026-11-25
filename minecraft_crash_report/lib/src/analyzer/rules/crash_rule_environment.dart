import '../../model/crash_analysis.dart';
import '../crash_rule.dart';

final class MtnMinecraftCrashRuleEnvironment extends MtnMinecraftCrashRuleAbs {
  const MtnMinecraftCrashRuleEnvironment();

  static final RegExp _dependency = RegExp(r'\bIncompatible mods found\b|\bMod resolution encountered an incompatible mod set\b|\bModResolutionException\b|\bSome of your mods are incompatible\b', caseSensitive: false);
  static final RegExp _requirement = RegExp(r"\bMod\s+['\x22][^'\x22]+['\x22]\s+\(([a-z][a-z0-9_-]*)\).*?\brequires\b", caseSensitive: false);
  static final RegExp _requiredId = RegExp(r"\brequires\b.*?\bof mod\s+['\x22][^'\x22]+['\x22]\s+\(([a-z][a-z0-9_-]*)\)", caseSensitive: false);
  static final RegExp _native = RegExp(r'A fatal error has been detected by the Java Runtime Environment|EXCEPTION_ACCESS_VIOLATION|\bSIGSEGV\b|\bSIGBUS\b|\bSIGILL\b', caseSensitive: false);

  @override
  Iterable<MtnMinecraftCrashFinding> evaluate(MtnMinecraftCrashRuleContext context) sync* {
    final List<MtnMinecraftCrashEvidence> dependency = [];
    final Map<String, MtnMinecraftCrashModFinding> suspected = {};
    final Map<String, MtnMinecraftCrashModFinding> related = {};
    MtnMinecraftCrashEvidence? native;
    final Set<MtnMinecraftCrashSource> incompatibleSources = {
      for (final line in context.diagnosticLines)
        if (_dependency.hasMatch(line.text)) line.source,
    };
    for (final MtnMinecraftCrashEvidence line in context.diagnosticLines) {
      if (line.text.trimLeft().startsWith('at ')) continue;
      final RegExpMatch? requirement = _requirement.firstMatch(line.text);
      final bool failedRequirement = requirement != null && (incompatibleSources.contains(line.source) ||
          RegExp(r'\b(?:which is missing|not installed|but .* (?:present|installed)|wrong version)\b', caseSensitive: false).hasMatch(line.text));
      if (_dependency.hasMatch(line.text) || failedRequirement) {
        dependency.add(line);
        if (requirement != null) {
          final String id = requirement.group(1)!;
          suspected[id] = context.attribution(id, MtnMinecraftCrashConfidence.medium, [line]);
          final String? target = _requiredId.firstMatch(line.text)?.group(1);
          if (target != null && target != id) {
            related[target] = context.attribution(target, MtnMinecraftCrashConfidence.high, [line]);
          }
        }
      }
      final String diagnostic = context.diagnosticText(line).replaceFirst(RegExp(r'^#\s*'), '');
      if (_native.hasMatch(diagnostic) && RegExp(r'^(?:A fatal error has been detected|EXCEPTION_ACCESS_VIOLATION|SIGSEGV|SIGBUS|SIGILL)', caseSensitive: false).hasMatch(diagnostic)) {
        native ??= line;
      }
    }
    if (dependency.isNotEmpty) {
      yield MtnMinecraftCrashFinding(type: MtnMinecraftCrashType.dependencyIncompatible,
        confidence: MtnMinecraftCrashConfidence.high, evidence: dependency,
        suspectedMods: suspected.values, relatedMods: related.values,
        recommendations: const [MtnMinecraftCrashRecommendation(MtnMinecraftCrashRecommendationType.checkRequiredDependencies)]);
    }
    if (native != null) {
      yield MtnMinecraftCrashFinding(type: MtnMinecraftCrashType.nativeCrash, confidence: MtnMinecraftCrashConfidence.high,
        evidence: context.diagnosticBlock(native),
        recommendations: const [MtnMinecraftCrashRecommendation(MtnMinecraftCrashRecommendationType.inspectNativeLog)]);
    }
  }
}
