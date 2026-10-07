import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentService file selection', () {
    test('selects only install and replacement targets in desired-state order', () {
      final contentA = _content('a');
      final contentB = _content('b');
      final contentC = _content('c');
      final contentD = _content('d');
      final contentX = _content('x');

      final aCurrent = _version('a:v1', contentA, files: <MtnMinecraftContentFile>[_file('a-old.jar')]);
      final aDesired = _version('a:v2', contentA, files: <MtnMinecraftContentFile>[_file('a-new.jar')]);
      final b = _version('b:v1', contentB, files: <MtnMinecraftContentFile>[_file('b.jar')]);
      final c = _version('c:v1', contentC, files: <MtnMinecraftContentFile>[_file('c.jar')]);
      final dCurrent = _version('d:v1', contentD, files: <MtnMinecraftContentFile>[_file('d-old.jar')]);
      final dDesired = _version('d:v2', contentD, files: <MtnMinecraftContentFile>[_file('d-new.jar')]);
      final x = _version('x:v1', contentX, files: <MtnMinecraftContentFile>[_file('x.jar')]);

      final desired = _desired(
        <MtnMinecraftContentDependencyInstallPlan>[
          _plan(aDesired, <MtnMinecraftContentVersion>[aDesired, b, c, dDesired]),
        ],
      );
      final current = MtnMinecraftContentDependencyInstalledState(
        versions: <MtnMinecraftContentVersion>[x, aCurrent, b, dCurrent],
      );
      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      expect(reconciliation.replacements.map((item) => item.desired.version), <MtnMinecraftContentVersion>[aDesired, dDesired]);
      expect(reconciliation.retains.map((item) => item.version), <MtnMinecraftContentVersion>[b]);
      expect(reconciliation.installs.map((item) => item.version), <MtnMinecraftContentVersion>[c]);
      expect(reconciliation.removals, <MtnMinecraftContentVersion>[x]);

      final selectionPlan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(selectionPlan.reconciliation, same(reconciliation));
      expect(selectionPlan.selections.map((item) => item.desired.version), <MtnMinecraftContentVersion>[aDesired, c, dDesired]);
      expect(selectionPlan.selections.map((item) => item.file.fileName), <String>['a-new.jar', 'c.jar', 'd-new.jar']);
      expect(selectionPlan.issues, isEmpty);
      expect(selectionPlan.selectable, isTrue);
    });

    test('selects a single file even when it is not primary and availability is unknown', () {
      final file = _file('single.jar', primary: false, available: null, downloadUrl: null);
      final reconciliation = _installReconciliation(_version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[file]));

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(plan.selections, hasLength(1));
      expect(plan.selections.single.file, same(file));
      expect(plan.issues, isEmpty);
      expect(plan.selectable, isTrue);
    });

    test('selects the only primary file from multiple files', () {
      final secondary = _file('secondary.jar');
      final primary = _file('primary.jar', primary: true);
      final another = _file('another.jar');
      final reconciliation = _installReconciliation(
        _version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[secondary, primary, another]),
      );

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(plan.selections, hasLength(1));
      expect(plan.selections.single.file, same(primary));
      expect(plan.issues, isEmpty);
    });

    test('reports no-files issue instead of throwing', () {
      final reconciliation = _installReconciliation(_version('a:v1', _content('a')));

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(plan.selections, isEmpty);
      expect(plan.issues, hasLength(1));
      expect(plan.issues.single, isA<MtnMinecraftContentFileSelectionIssueNoFiles>());
      expect(plan.issues.single.desired.version.key, 'a:v1');
      expect(plan.selectable, isFalse);
    });

    test('reports ambiguity when multiple files have no primary', () {
      final first = _file('first.jar');
      final second = _file('second.jar');
      final reconciliation = _installReconciliation(
        _version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[first, second]),
      );

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(plan.selections, isEmpty);
      expect(plan.issues, hasLength(1));
      final issue = plan.issues.single as MtnMinecraftContentFileSelectionIssueAmbiguous;
      expect(issue.candidates, <MtnMinecraftContentFile>[first, second]);
      expect(plan.selectable, isFalse);
    });

    test('reports ambiguity when multiple files are primary', () {
      final first = _file('first.jar', primary: true);
      final second = _file('second.jar', primary: true);
      final reconciliation = _installReconciliation(
        _version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[first, second]),
      );

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(plan.selections, isEmpty);
      expect(plan.issues.single, isA<MtnMinecraftContentFileSelectionIssueAmbiguous>());
      expect(plan.selectable, isFalse);
    });

    test('reports unavailable for a single unavailable file', () {
      final file = _file('unavailable.jar', available: false);
      final reconciliation = _installReconciliation(
        _version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[file]),
      );

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(plan.selections, isEmpty);
      final issue = plan.issues.single as MtnMinecraftContentFileSelectionIssueUnavailable;
      expect(issue.file, same(file));
      expect(plan.selectable, isFalse);
    });

    test('does not fall back from an unavailable primary to a non-primary file', () {
      final primary = _file('primary.jar', primary: true, available: false);
      final secondary = _file('secondary.jar', available: true);
      final reconciliation = _installReconciliation(
        _version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[primary, secondary]),
      );

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(plan.selections, isEmpty);
      final issue = plan.issues.single as MtnMinecraftContentFileSelectionIssueUnavailable;
      expect(issue.file, same(primary));
    });

    test('download URL hashes and sizes are not file-selection requirements', () {
      final file = MtnMinecraftContentFile(
        fileName: 'metadata-light.jar',
        primary: true,
        available: true,
      );
      final reconciliation = _installReconciliation(
        _version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[file]),
      );

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(file.downloadUrl, isNull);
      expect(file.hashes, isEmpty);
      expect(file.size, isNull);
      expect(file.sizeOnDisk, isNull);
      expect(plan.selections.single.file, same(file));
      expect(plan.selectable, isTrue);
    });

    test('retain-only and removal-only reconciliation needs no file selection', () {
      final contentA = _content('a');
      final contentX = _content('x');
      final a = _version('a:v1', contentA, files: <MtnMinecraftContentFile>[_file('a.jar')]);
      final x = _version('x:v1', contentX, files: <MtnMinecraftContentFile>[_file('x.jar')]);
      final desired = _desired(<MtnMinecraftContentDependencyInstallPlan>[_plan(a, <MtnMinecraftContentVersion>[a])]);
      final current = MtnMinecraftContentDependencyInstalledState(versions: <MtnMinecraftContentVersion>[a, x]);
      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(reconciliation.retains.map((item) => item.version), <MtnMinecraftContentVersion>[a]);
      expect(reconciliation.removals, <MtnMinecraftContentVersion>[x]);
      expect(plan.selections, isEmpty);
      expect(plan.issues, isEmpty);
      expect(plan.selectable, isTrue);
    });

    test('selection and issue result collections are immutable', () {
      final good = _version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[_file('a.jar')]);
      final bad = _version('b:v1', _content('b'));
      final desired = _desired(<MtnMinecraftContentDependencyInstallPlan>[_plan(good, <MtnMinecraftContentVersion>[good, bad])]);
      final current = MtnMinecraftContentDependencyInstalledState(versions: const <MtnMinecraftContentVersion>[]);
      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);

      expect(plan.selections, hasLength(1));
      expect(plan.issues, hasLength(1));
      expect(() => plan.selections.clear(), throwsUnsupportedError);
      expect(() => plan.issues.clear(), throwsUnsupportedError);
    });

    test('ambiguous issue copies candidate files', () {
      final first = _file('first.jar');
      final second = _file('second.jar');
      final version = _version('a:v1', _content('a'), files: <MtnMinecraftContentFile>[first, second]);
      final reconciliation = _installReconciliation(version);

      final plan = MtnMinecraftContentService().selectReconciliationFiles(reconciliation);
      final issue = plan.issues.single as MtnMinecraftContentFileSelectionIssueAmbiguous;

      expect(() => issue.candidates.clear(), throwsUnsupportedError);
    });
  });
}

MtnMinecraftContentMod _content(String key) {
  return MtnMinecraftContentMod(key: key, name: key);
}

MtnMinecraftContentFile _file(
  String fileName, {
  bool primary = false,
  bool? available = true,
  String? downloadUrl = 'https://example.invalid/file',
}) {
  return MtnMinecraftContentFile(
    fileName: fileName,
    primary: primary,
    available: available,
    downloadUrl: downloadUrl,
  );
}

MtnMinecraftContentVersion _version(
  String key,
  MtnMinecraftContent content, {
  List<MtnMinecraftContentFile>? files,
}) {
  return MtnMinecraftContentVersion(
    key: key,
    content: content,
    name: key,
    version: key,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    files: files,
  );
}

MtnMinecraftContentDependencyReconciliationPlan _installReconciliation(
  MtnMinecraftContentVersion version,
) {
  final desired = _desired(
    <MtnMinecraftContentDependencyInstallPlan>[
      _plan(version, <MtnMinecraftContentVersion>[version]),
    ],
  );
  final current = MtnMinecraftContentDependencyInstalledState(versions: const <MtnMinecraftContentVersion>[]);
  return MtnMinecraftContentService().reconcileDependencyState(current, desired);
}

MtnMinecraftContentDependencyDesiredState _desired(
  List<MtnMinecraftContentDependencyInstallPlan> plans,
) {
  return MtnMinecraftContentService().composeDependencyInstallPlans(plans);
}

MtnMinecraftContentDependencyInstallPlan _plan(
  MtnMinecraftContentVersion root,
  List<MtnMinecraftContentVersion> installVersions,
) {
  return MtnMinecraftContentDependencyInstallPlan(
    root: root,
    installVersions: installVersions,
    installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    incompatibleEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    unresolvedInstallEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
  );
}
