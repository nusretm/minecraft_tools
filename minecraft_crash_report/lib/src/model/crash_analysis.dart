import 'crash_report.dart';

enum MtnMinecraftCrashType {
  mixinInjection,
  mixinApply,
  noSuchMethodError,
  noClassDefFound,
  dependencyIncompatible,
  javaVersionMismatch,
  outOfMemory,
  nativeCrash,
  unknown,
}

enum MtnMinecraftCrashConfidence { low, medium, high }
enum MtnMinecraftCrashMemoryKind { heap, metaspace, native, unknown }
enum MtnMinecraftCrashSource { crashReport, gameLog, nativeLog, exitCode }

enum MtnMinecraftCrashRecommendationType {
  disableModAndRetry,
  checkModCompatibility,
  checkRequiredDependencies,
  checkJavaVersion,
  checkMemory,
  inspectNativeLog,
  inspectLogs,
}

final class MtnMinecraftCrashEvidence {
  const MtnMinecraftCrashEvidence({required this.source, this.lineNumber, required this.text});

  final MtnMinecraftCrashSource source;
  final int? lineNumber;
  final String text;
}

final class MtnMinecraftCrashModFinding {
  MtnMinecraftCrashModFinding({required this.mod, required this.confidence, required Iterable<MtnMinecraftCrashEvidence> evidence})
      : evidence = List<MtnMinecraftCrashEvidence>.unmodifiable(evidence);

  final MtnMinecraftCrashMod mod;
  final MtnMinecraftCrashConfidence confidence;
  final List<MtnMinecraftCrashEvidence> evidence;
}

/// Recommendations are advisory codes; consumers localize them and obtain approval.
final class MtnMinecraftCrashRecommendation {
  const MtnMinecraftCrashRecommendation(this.type, {this.modId});

  final MtnMinecraftCrashRecommendationType type;
  final String? modId;
}

final class MtnMinecraftCrashFinding {
  MtnMinecraftCrashFinding({
    required this.type,
    required this.confidence,
    required Iterable<MtnMinecraftCrashEvidence> evidence,
    this.memoryKind,
    Iterable<MtnMinecraftCrashModFinding> suspectedMods = const [],
    Iterable<MtnMinecraftCrashModFinding> relatedMods = const [],
    Iterable<MtnMinecraftCrashRecommendation> recommendations = const [],
  }) : evidence = List<MtnMinecraftCrashEvidence>.unmodifiable(evidence),
       suspectedMods = List<MtnMinecraftCrashModFinding>.unmodifiable(suspectedMods),
       relatedMods = List<MtnMinecraftCrashModFinding>.unmodifiable(relatedMods),
       recommendations = List<MtnMinecraftCrashRecommendation>.unmodifiable(recommendations);

  final MtnMinecraftCrashType type;
  final MtnMinecraftCrashMemoryKind? memoryKind;
  final MtnMinecraftCrashConfidence confidence;
  final List<MtnMinecraftCrashEvidence> evidence;
  final List<MtnMinecraftCrashModFinding> suspectedMods;
  final List<MtnMinecraftCrashModFinding> relatedMods;
  final List<MtnMinecraftCrashRecommendation> recommendations;
}

final class MtnMinecraftCrashAnalysis {
  MtnMinecraftCrashAnalysis({required Iterable<MtnMinecraftCrashFinding> findings, this.exitCode})
      : findings = List<MtnMinecraftCrashFinding>.unmodifiable(findings);

  final List<MtnMinecraftCrashFinding> findings;
  final int? exitCode;
  MtnMinecraftCrashFinding? get primaryFinding => findings.isEmpty ? null : findings.first;
}
