import '../../model/crash_analysis.dart';
import '../crash_rule.dart';

/// JVM exception signatures establish the category, not mod ownership.
final class MtnMinecraftCrashRuleJava extends MtnMinecraftCrashRuleAbs {
  const MtnMinecraftCrashRuleJava();

  static final List<({RegExp pattern, MtnMinecraftCrashType type, MtnMinecraftCrashRecommendationType recommendation})> _signatures = [
    (pattern: RegExp(r'\bUnsupportedClassVersionError\b|class file version .* only recognizes class file versions', caseSensitive: false),
      type: MtnMinecraftCrashType.javaVersionMismatch, recommendation: MtnMinecraftCrashRecommendationType.checkJavaVersion),
    (pattern: RegExp(r'\bOutOfMemoryError\b|There is insufficient memory for the Java Runtime Environment', caseSensitive: false),
      type: MtnMinecraftCrashType.outOfMemory, recommendation: MtnMinecraftCrashRecommendationType.checkMemory),
    (pattern: RegExp(r'\bNoSuchMethodError\b'), type: MtnMinecraftCrashType.noSuchMethod,
      recommendation: MtnMinecraftCrashRecommendationType.checkModCompatibility),
    (pattern: RegExp(r'\b(?:NoClassDefFoundError|ClassNotFoundException)\b'), type: MtnMinecraftCrashType.noClassDefFound,
      recommendation: MtnMinecraftCrashRecommendationType.checkRequiredDependencies),
  ];

  @override
  Iterable<MtnMinecraftCrashFinding> evaluate(MtnMinecraftCrashRuleContext context) sync* {
    for (final signature in _signatures) {
      for (final MtnMinecraftCrashEvidence line in context.diagnosticLines) {
        if (line.text.trimLeft().startsWith('at ') || !signature.pattern.hasMatch(line.text)) continue;
        yield MtnMinecraftCrashFinding(type: signature.type, confidence: MtnMinecraftCrashConfidence.high,
          evidence: context.diagnosticBlock(line),
          recommendations: [MtnMinecraftCrashRecommendation(signature.recommendation)]);
        break;
      }
    }
  }
}
