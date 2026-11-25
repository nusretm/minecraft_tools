# minecraft_crash_report

Pure Dart, deterministic Minecraft crash report parser and analyzer. No network,
Flutter, native runtime or content service dependencies. Accepts complete reports
and excerpts; optionally accepts caller-associated game/native logs, exit code
and known installed runtime mod identities.

```dart
import 'package:minecraft_crash_report/minecraft_crash_report.dart';

final report = const MtnMinecraftCrashReportParser().parse(reportText);
final analysis = const MtnMinecraftCrashAnalyzer().analyze(
  report: report,
  gameLog: gameLogText,
  exitCode: -1,
);
final finding = analysis.primaryFinding;
```

Report preserves raw text, local timestamp text, description, named sections,
Java exception sequence (root/cause/suppressed), stack frames, system details
and nested Fabric runtime mod IDs. Findings provide typed categories, qualitative
confidence, one-based source line evidence, individual suspected/related mod
attributions and advisory recommendation codes. The caller owns localization,
file/session association, I/O and all user-approved content actions.

Supported signatures: Mixin injection/apply errors, NoSuchMethodError,
NoClassDefFoundError/ClassNotFoundException, explicit loader incompatibility,
Java class version mismatch, OutOfMemoryError and JVM fatal signals.
Unknown input yields low-confidence unknown, not a guessed mod. Explicit Mixin
owner is evidence of failure ownership, not proof of sole root cause. Related
mixin namespace matching requires a known runtime mod ID (report or
installedMods); confidence is medium. Linkage signatures do not blame mods from
stack presence alone. Optional caller-verified `classOwners` maps exact Java
classes to known installed mod IDs; linkage can then identify a possible caller
and related target with medium confidence. Memory findings distinguish heap,
metaspace, native memory and unknown when explicit text is available. A nonzero
exit code alone does not prove native crash.
Initial parser is Fabric-oriented; arbitrary Java/loader formats are best effort,
not a universal stacktrace grammar. No automated modification or version changes.

## Windows validation

```powershell
dart pub get
dart analyze
dart test
dart run example/analyze.dart <report-path>
```

The test report contains the operator-provided InjectionError excerpt surrounded
by synthetic report structure and inventory; full original report validation is
separate. CLI accepts optional second argument for a session-associated game log.
