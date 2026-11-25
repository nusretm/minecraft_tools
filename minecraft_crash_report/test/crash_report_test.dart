import 'package:minecraft_crash_report/minecraft_crash_report.dart';
import 'package:test/test.dart';

// Synthetic report structure around the operator-provided real exception excerpt.
// The full original report is not available in this repository.
const String reportText = '''---- Minecraft Crash Report ----
Time: 2026-11-25 18:00:00
Description: Initializing game

java.lang.RuntimeException: Game initialization failed
    at net.minecraft.client.Main.main(Main.java:42)
Caused by: org.spongepowered.asm.mixin.transformer.throwables.MixinTransformerError: Unexpected error
Caused by:
org.spongepowered.asm.mixin.injection.throwables.InjectionError

Critical injection failure:
Callback method removeRestartRequiredMessage

fullscreenfix.client.mixins.json:
sodium.SodiumConfigBuilderMixin

from mod fullscreenfix

(0/1) succeeded. Scanned 0 target(s).
    at org.spongepowered.asm.mixin.injection.struct.InjectionInfo.postInject(InjectionInfo.java:99)

-- Head --
Thread: Render thread

-- Unknown future section --
Keep this value

-- System Details --
    Minecraft Version: 26.1.2
    Java Version: 25.0.1, Example VM
    Fabric Mods:
        fabricloader: Fabric Loader 0.20.1
        fullscreenfix: Borderless Fullscreen 2.4.1_01
        sodium: Sodium 0.9.4-beta.1+mc26.1.2
        fabric-api: Fabric API 1.0
            fabric-base: Fabric Base 1.0
    Launched Version: Example
''';

void main() {
  const parser = MtnMinecraftCrashReportParser();
  const analyzer = MtnMinecraftCrashAnalyzer();

  test('parses report, causes, stack frames, unknown sections and nested Fabric mods', () {
    final report = parser.parse(reportText.replaceAll('\n', '\r\n'));
    expect(report.description, 'Initializing game');
    expect(report.time, '2026-11-25 18:00:00');
    expect(report.minecraftVersion, '26.1.2');
    expect(report.javaVersion, '25.0.1, Example VM');
    expect(report.fabricLoaderVersion, '0.20.1');
    expect(report.exceptions.map((item) => item.relation), [
      MtnMinecraftCrashExceptionRelation.root,
      MtnMinecraftCrashExceptionRelation.causedBy,
      MtnMinecraftCrashExceptionRelation.causedBy,
    ]);
    expect(report.exceptions.last.type, endsWith('InjectionError'));
    expect(report.exceptions.last.frames.single.className, endsWith('InjectionInfo'));
    expect(report.sections.map((section) => section.title), ['Head', 'Unknown future section', 'System Details']);
    expect(report.mods.singleWhere((mod) => mod.id == 'fabric-base').parentId, 'fabric-api');
    expect(report.mods.singleWhere((mod) => mod.id == 'sodium').version, '0.9.4-beta.1+mc26.1.2');
    expect(report.systemDetails.containsKey('sodium'), isFalse);
    expect(report.systemDetails['Launched Version'], 'Example');
  });

  test('real excerpt identifies fullscreenfix and related sodium, not vice versa', () {
    final report = parser.parse(reportText);
    final finding = analyzer.analyze(report: report, exitCode: -1).primaryFinding!;
    expect(finding.type, MtnMinecraftCrashType.mixinInjection);
    expect(finding.confidence, MtnMinecraftCrashConfidence.high);
    expect(finding.suspectedMods.single.mod.id, 'fullscreenfix');
    expect(finding.suspectedMods.single.mod.name, 'Borderless Fullscreen');
    expect(finding.suspectedMods.single.confidence, MtnMinecraftCrashConfidence.high);
    expect(finding.relatedMods.single.mod.id, 'sodium');
    expect(finding.relatedMods.single.confidence, MtnMinecraftCrashConfidence.medium);
    expect(finding.recommendations.single.type, MtnMinecraftCrashRecommendationType.disableModAndRetry);
    expect(finding.recommendations.single.modId, 'fullscreenfix');
    final lines = reportText.split('\n');
    for (final evidence in finding.evidence) {
      expect(evidence.text, lines[evidence.lineNumber! - 1]);
      expect(evidence.source, MtnMinecraftCrashSource.crashReport);
    }
    expect(finding.evidence.any((e) => e.text.contains('removeRestartRequiredMessage')), isTrue);
  });

  test('excerpt without inventory does not invent target mod identity', () {
    final report = parser.parse('org.spongepowered.asm.mixin.injection.throwables.InjectionError: fullscreenfix.client.mixins.json:sodium.SodiumConfigBuilderMixin from mod fullscreenfix');
    final unknownTarget = analyzer.analyze(report: report).primaryFinding!;
    expect(unknownTarget.suspectedMods.single.mod.id, 'fullscreenfix');
    expect(unknownTarget.relatedMods, isEmpty);
    final knownTarget = analyzer.analyze(report: report, installedMods: const [
      MtnMinecraftCrashMod(id: 'sodium', name: 'Sodium'),
    ]).primaryFinding!;
    expect(knownTarget.relatedMods.single.mod.id, 'sodium');
  });

  test('log-only linkage, Java, memory and native categories', () {
    final cases = <String, MtnMinecraftCrashType>{
      'java.lang.NoSuchMethodError: com.example.Api.call()V': MtnMinecraftCrashType.noSuchMethod,
      'Caused by: java.lang.NoClassDefFoundError: com/example/Missing': MtnMinecraftCrashType.noClassDefFound,
      'java.lang.UnsupportedClassVersionError: class file version 69.0': MtnMinecraftCrashType.javaVersionMismatch,
      '[12:00:00] [Render thread/ERROR]: java.lang.OutOfMemoryError: Java heap space': MtnMinecraftCrashType.outOfMemory,
      '# EXCEPTION_ACCESS_VIOLATION (0xc0000005)': MtnMinecraftCrashType.nativeCrash,
      'org.spongepowered.asm.mixin.throwables.MixinApplyError: failure': MtnMinecraftCrashType.mixinApply,
    };
    for (final entry in cases.entries) {
      final finding = analyzer.analyze(gameLog: entry.key).primaryFinding!;
      expect(finding.type, entry.value, reason: entry.key);
      expect(finding.suspectedMods, isEmpty);
      expect(finding.evidence.first.source, MtnMinecraftCrashSource.gameLog);
    }
  });

  test('Fabric incompatible dependency names and roles are explicit', () {
    final finding = analyzer.analyze(gameLog: '''
Incompatible mods found!
Mod 'Example' (example) 1.0 requires version 2 of mod 'Library' (library), which is missing!
''').primaryFinding!;
    expect(finding.type, MtnMinecraftCrashType.dependencyIncompatible);
    expect(finding.suspectedMods.single.mod.id, 'example');
    expect(finding.relatedMods.single.mod.id, 'library');
    expect(finding.recommendations.single.type, MtnMinecraftCrashRecommendationType.checkRequiredDependencies);
  });

  test('unknown exit code and innocent log mentions never blame an installed mod', () {
    final finding = analyzer.analyze(exitCode: -1, gameLog: '''
[12:00:00] [main/INFO]: Example supports handling NoSuchMethodError.
    at example.SomeClass.run(SomeClass.java:1)
Mod 'Example' (example) 1.0 requires a library.
''', installedMods: const [MtnMinecraftCrashMod(id: 'example')]).primaryFinding!;
    expect(finding.type, MtnMinecraftCrashType.unknown);
    expect(finding.confidence, MtnMinecraftCrashConfidence.low);
    expect(finding.suspectedMods, isEmpty);
    expect(finding.evidence.single.source, MtnMinecraftCrashSource.exitCode);
  });

  test('linkage attribution requires verified class owners and separates caller and target', () {
    final finding = analyzer.analyze(gameLog: '''
java.lang.NoSuchMethodError: 'void library.Api.call()'
    at knot//example.Caller.run(Caller.java:17)
''', installedMods: const [
      MtnMinecraftCrashMod(id: 'example'),
      MtnMinecraftCrashMod(id: 'library'),
    ], classOwners: const {
      'example.Caller': 'example',
      'library.Api': 'library',
    }).primaryFinding!;
    expect(finding.suspectedMods.single.mod.id, 'example');
    expect(finding.relatedMods.single.mod.id, 'library');
    expect(finding.suspectedMods.single.confidence, MtnMinecraftCrashConfidence.medium);
    expect(finding.evidence.last.lineNumber, 2);
    expect(finding.recommendations.single.type, MtnMinecraftCrashRecommendationType.checkModCompatibility);
  });

  test('memory diagnostics distinguish heap, metaspace and native memory', () {
    final cases = <String, MtnMinecraftCrashMemoryKind>{
      'Java heap space': MtnMinecraftCrashMemoryKind.heap,
      'Metaspace': MtnMinecraftCrashMemoryKind.metaspace,
      'unable to create native thread': MtnMinecraftCrashMemoryKind.native,
      '': MtnMinecraftCrashMemoryKind.unknown,
    };
    for (final entry in cases.entries) {
      final finding = analyzer.analyze(gameLog: 'java.lang.OutOfMemoryError: ' + entry.key).primaryFinding!;
      expect(finding.memoryKind, entry.value);
    }
  });

  test('empty or truncated report is accepted without fabricated fields', () {
    final report = parser.parse('Caused by:\n');
    expect(report.exceptions, isEmpty);
    expect(report.time, isNull);
    expect(report.mods, isEmpty);
    expect(analyzer.analyze(report: report).primaryFinding!.type, MtnMinecraftCrashType.unknown);
  });
}
