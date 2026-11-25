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
        final bool exception = context.hasException(line, signature.pattern);
        final bool explicitDiagnostic = (signature.type == MtnMinecraftCrashType.outOfMemory &&
            line.text.contains('There is insufficient memory for the Java Runtime Environment')) ||
            (signature.type == MtnMinecraftCrashType.javaVersionMismatch &&
                signature.pattern.hasMatch(context.diagnosticText(line)) &&
                context.diagnosticText(line).startsWith('class file version'));
        if (!exception && !explicitDiagnostic) continue;
        final List<MtnMinecraftCrashEvidence> evidence = context.diagnosticBlock(line);
        final List<MtnMinecraftCrashModFinding> suspected = [];
        final List<MtnMinecraftCrashModFinding> related = [];
        final String diagnostic = context.diagnosticText(line);
        final bool initializationFailure = diagnostic.contains('Could not initialize class');
        if (signature.type == MtnMinecraftCrashType.noSuchMethod || signature.type == MtnMinecraftCrashType.noClassDefFound) {
          // The first call site is useful only with a caller-supplied exact class owner.
          final MtnMinecraftCrashEvidence? frame = context.firstStackFrame(line);
          final String? symbol = frame == null ? null : RegExp(r'^\s*at\s+([^\s(]+)\(').firstMatch(frame.text)?.group(1);
          final int methodSeparator = symbol?.lastIndexOf('.') ?? -1;
          String? callerId;
          if (frame != null && symbol != null && methodSeparator > 0) {
            final String owner = symbol.substring(0, methodSeparator);
            callerId = context.ownerForClass(owner.substring(owner.lastIndexOf('/') + 1));
            if (callerId != null) {
              evidence.add(frame);
              suspected.add(context.attribution(callerId, MtnMinecraftCrashConfidence.medium, [line, frame]));
            }
          }
          final String? targetClass = signature.type == MtnMinecraftCrashType.noSuchMethod
              ? RegExp(r'([A-Za-z_$][\w.$/]+)\.[A-Za-z_$][\w$<>]*\(').firstMatch(diagnostic)?.group(1)
              : RegExp(r'(?:NoClassDefFoundError|ClassNotFoundException):\s*(?:Could not initialize class\s+)?([A-Za-z_$][\w.$/]+)').firstMatch(diagnostic)?.group(1);
          final String? targetId = targetClass == null ? null : context.ownerForClass(targetClass);
          if (targetId != null && targetId != callerId) {
            related.add(context.attribution(targetId, MtnMinecraftCrashConfidence.medium, [line]));
          }
        }
        MtnMinecraftCrashMemoryKind? memoryKind;
        if (signature.type == MtnMinecraftCrashType.outOfMemory) {
          final String text = evidence.map((item) => item.text).join(' ').toLowerCase();
          memoryKind = text.contains('java heap space') || text.contains('gc overhead limit exceeded')
              ? MtnMinecraftCrashMemoryKind.heap
              : text.contains('metaspace') || text.contains('compressed class space')
                  ? MtnMinecraftCrashMemoryKind.metaspace
                  : text.contains('native thread') || text.contains('native memory') || text.contains('direct buffer memory') ||
                        text.contains('insufficient memory for the java runtime environment')
                      ? MtnMinecraftCrashMemoryKind.native
                      : MtnMinecraftCrashMemoryKind.unknown;
        }
        yield MtnMinecraftCrashFinding(type: signature.type, confidence: MtnMinecraftCrashConfidence.high,
          evidence: evidence, suspectedMods: suspected, relatedMods: related, memoryKind: memoryKind,
          recommendations: [MtnMinecraftCrashRecommendation(initializationFailure
              ? MtnMinecraftCrashRecommendationType.checkModCompatibility : signature.recommendation)]);
        break;
      }
    }
  }
}
