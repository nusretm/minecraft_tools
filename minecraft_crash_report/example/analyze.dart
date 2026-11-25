import 'dart:io';

import 'package:minecraft_crash_report/minecraft_crash_report.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln('Usage: dart run example/analyze.dart <crash-report.txt> [game-log.txt]');
    exitCode = 64;
    return;
  }
  final report = const MtnMinecraftCrashReportParser().parse(await File(args.first).readAsString());
  final analysis = const MtnMinecraftCrashAnalyzer().analyze(
    report: report, gameLog: args.length == 2 ? await File(args[1]).readAsString() : null);
  stdout.writeln('Description: ' + (report.description ?? 'unknown'));
  stdout.writeln('Fabric mods: ' + report.mods.length.toString());
  for (final finding in analysis.findings) {
    stdout.writeln('Finding: ' + finding.type.name + ' (' + finding.confidence.name + ')');
    for (final item in finding.suspectedMods) {
      stdout.writeln('  Suspected: ' + (item.mod.name ?? item.mod.id) + ' [' + item.mod.id + '] ' +
        (item.mod.version ?? '') + ' confidence=' + item.confidence.name);
    }
    for (final item in finding.relatedMods) {
      stdout.writeln('  Related: ' + (item.mod.name ?? item.mod.id) + ' [' + item.mod.id + '] ' +
        (item.mod.version ?? '') + ' confidence=' + item.confidence.name);
    }
    for (final evidence in finding.evidence) {
      stdout.writeln('  ' + evidence.source.name + ':' + (evidence.lineNumber?.toString() ?? '-') + ': ' + evidence.text);
    }
    for (final recommendation in finding.recommendations) {
      stdout.writeln('  Recommend: ' + recommendation.type.name + ' ' + (recommendation.modId ?? ''));
    }
  }
}
