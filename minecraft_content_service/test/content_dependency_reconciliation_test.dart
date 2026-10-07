import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentService dependency reconciliation', () {
    test('classifies install retain replace and removal deterministically', () {
      final contentA = _content('a');
      final contentB = _content('b');
      final contentC = _content('c');
      final contentD = _content('d');
      final contentX = _content('x');

      final aV1 = _version('a:v1', contentA);
      final aV2 = _version('a:v2', contentA);
      final bV1 = _version('b:v1', contentB);
      final cV1 = _version('c:v1', contentC);
      final dV1 = _version('d:v1', contentD);
      final xV1 = _version('x:v1', contentX);

      final current = MtnMinecraftContentDependencyInstalledState(
        versions: <MtnMinecraftContentVersion>[xV1, aV1, cV1, bV1],
      );
      final desired = _desired(
        <MtnMinecraftContentDependencyInstallPlan>[
          _plan(aV2, <MtnMinecraftContentVersion>[aV2, bV1, dV1]),
        ],
      );

      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      expect(reconciliation.current, same(current));
      expect(reconciliation.desired, same(desired));
      expect(reconciliation.installs.map((item) => item.version), <MtnMinecraftContentVersion>[dV1]);
      expect(reconciliation.retains.map((item) => item.version), <MtnMinecraftContentVersion>[bV1]);
      expect(reconciliation.replacements, hasLength(1));
      expect(reconciliation.replacements.single.current, same(aV1));
      expect(reconciliation.replacements.single.desired.version, same(aV2));
      expect(reconciliation.removals, <MtnMinecraftContentVersion>[xV1, cV1]);
      expect(reconciliation.changesRequired, isTrue);
    });

    test('treats downgrade as replacement without generic version ordering', () {
      final contentA = _content('a');
      final aV2 = _version('a:v2', contentA);
      final aV1 = _version('a:v1', contentA);
      final current = MtnMinecraftContentDependencyInstalledState(versions: <MtnMinecraftContentVersion>[aV2]);
      final desired = _desired(<MtnMinecraftContentDependencyInstallPlan>[_plan(aV1, <MtnMinecraftContentVersion>[aV1])]);

      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      expect(reconciliation.replacements, hasLength(1));
      expect(reconciliation.replacements.single.current, same(aV2));
      expect(reconciliation.replacements.single.desired.version, same(aV1));
      expect(reconciliation.installs, isEmpty);
      expect(reconciliation.retains, isEmpty);
      expect(reconciliation.removals, isEmpty);
    });

    test('retains the same version when desired ownership changes to direct', () {
      final contentA = _content('a');
      final installed = _version('a:v1', contentA, direct: false);
      final desiredRoot = _version('a:v1', contentA, direct: true);
      final current = MtnMinecraftContentDependencyInstalledState(versions: <MtnMinecraftContentVersion>[installed]);
      final desired = _desired(<MtnMinecraftContentDependencyInstallPlan>[_plan(desiredRoot, <MtnMinecraftContentVersion>[desiredRoot])]);

      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      expect(reconciliation.retains, hasLength(1));
      expect(reconciliation.retains.single.version.key, installed.key);
      expect(reconciliation.retains.single.direct, isTrue);
      expect(reconciliation.installs, isEmpty);
      expect(reconciliation.replacements, isEmpty);
      expect(reconciliation.removals, isEmpty);
      expect(reconciliation.changesRequired, isFalse);
      expect(installed.direct, isFalse);
      expect(desiredRoot.direct, isTrue);
    });

    test('installs every desired version when current state is empty', () {
      final root = _version('a:v1', _content('a'));
      final dependency = _version('b:v1', _content('b'));
      final current = MtnMinecraftContentDependencyInstalledState(versions: const <MtnMinecraftContentVersion>[]);
      final desired = _desired(<MtnMinecraftContentDependencyInstallPlan>[_plan(root, <MtnMinecraftContentVersion>[root, dependency])]);

      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      expect(reconciliation.installs.map((item) => item.version), <MtnMinecraftContentVersion>[root, dependency]);
      expect(reconciliation.retains, isEmpty);
      expect(reconciliation.replacements, isEmpty);
      expect(reconciliation.removals, isEmpty);
      expect(reconciliation.changesRequired, isTrue);
    });

    test('removes every managed current version when desired state is empty', () {
      final a = _version('a:v1', _content('a'), direct: true);
      final b = _version('b:v1', _content('b'));
      final current = MtnMinecraftContentDependencyInstalledState(versions: <MtnMinecraftContentVersion>[a, b]);
      final desired = _desired(const <MtnMinecraftContentDependencyInstallPlan>[]);

      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      expect(reconciliation.installs, isEmpty);
      expect(reconciliation.retains, isEmpty);
      expect(reconciliation.replacements, isEmpty);
      expect(reconciliation.removals, <MtnMinecraftContentVersion>[a, b]);
      expect(reconciliation.changesRequired, isTrue);
    });

    test('installed state rejects duplicate version and logical-content identities', () {
      final contentA = _content('a');
      final aV1 = _version('a:v1', contentA);
      final aV2 = _version('a:v2', contentA);
      final otherSameVersionKey = _version('a:v1', _content('other'));

      expect(
        () => MtnMinecraftContentDependencyInstalledState(versions: <MtnMinecraftContentVersion>[aV1, aV2]),
        throwsArgumentError,
      );
      expect(
        () => MtnMinecraftContentDependencyInstalledState(versions: <MtnMinecraftContentVersion>[aV1, otherSameVersionKey]),
        throwsArgumentError,
      );
    });

    test('rejects reconciliation when desired state is not installable', () {
      final root = _version('a:v1', _content('a'));
      final unresolved = _edge(root, MtnMinecraftContentDependencyType.required);
      final blockedPlan = _plan(
        root,
        <MtnMinecraftContentVersion>[root],
        unresolvedInstallEdges: <MtnMinecraftContentDependencyGraphEdge>[unresolved],
      );
      final desired = _desired(<MtnMinecraftContentDependencyInstallPlan>[blockedPlan]);
      final current = MtnMinecraftContentDependencyInstalledState(versions: const <MtnMinecraftContentVersion>[]);

      expect(desired.installable, isFalse);
      expect(
        () => MtnMinecraftContentService().reconcileDependencyState(current, desired),
        throwsStateError,
      );
    });

    test('rejects the same version key identifying different content across states', () {
      final currentVersion = _version('shared:v1', _content('current-content'));
      final desiredVersion = _version('shared:v1', _content('desired-content'));
      final current = MtnMinecraftContentDependencyInstalledState(versions: <MtnMinecraftContentVersion>[currentVersion]);
      final desired = _desired(<MtnMinecraftContentDependencyInstallPlan>[_plan(desiredVersion, <MtnMinecraftContentVersion>[desiredVersion])]);

      expect(
        () => MtnMinecraftContentService().reconcileDependencyState(current, desired),
        throwsStateError,
      );
    });

    test('rejects a manually corrupted installable desired state with duplicate logical content', () {
      final contentA = _content('a');
      final aV1 = _version('a:v1', contentA);
      final aV2 = _version('a:v2', contentA);
      final plan1 = _plan(aV1, <MtnMinecraftContentVersion>[aV1]);
      final plan2 = _plan(aV2, <MtnMinecraftContentVersion>[aV2]);
      final desired1 = MtnMinecraftContentDependencyDesiredVersion(version: aV1, roots: <MtnMinecraftContentVersion>[aV1]);
      final desired2 = MtnMinecraftContentDependencyDesiredVersion(version: aV2, roots: <MtnMinecraftContentVersion>[aV2]);
      final corrupted = MtnMinecraftContentDependencyDesiredState(
        plans: <MtnMinecraftContentDependencyInstallPlan>[plan1, plan2],
        directVersions: <MtnMinecraftContentVersion>[aV1, aV2],
        versions: <MtnMinecraftContentDependencyDesiredVersion>[desired1, desired2],
        conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
      );
      final current = MtnMinecraftContentDependencyInstalledState(versions: const <MtnMinecraftContentVersion>[]);

      expect(corrupted.installable, isTrue);
      expect(
        () => MtnMinecraftContentService().reconcileDependencyState(current, corrupted),
        throwsStateError,
      );
    });

    test('copies installed input and keeps reconciliation collections immutable', () {
      final root = _version('a:v1', _content('a'));
      final versions = <MtnMinecraftContentVersion>[root];
      final current = MtnMinecraftContentDependencyInstalledState(versions: versions);
      versions.clear();
      final desired = _desired(<MtnMinecraftContentDependencyInstallPlan>[_plan(root, <MtnMinecraftContentVersion>[root])]);

      final reconciliation = MtnMinecraftContentService().reconcileDependencyState(current, desired);

      expect(current.versions, <MtnMinecraftContentVersion>[root]);
      expect(() => current.versions.clear(), throwsUnsupportedError);
      expect(() => reconciliation.installs.clear(), throwsUnsupportedError);
      expect(() => reconciliation.retains.clear(), throwsUnsupportedError);
      expect(() => reconciliation.replacements.clear(), throwsUnsupportedError);
      expect(() => reconciliation.removals.clear(), throwsUnsupportedError);
    });

    test('replacement requires the same logical content and a different version key', () {
      final contentA = _content('a');
      final aV1 = _version('a:v1', contentA);
      final aV2 = _version('a:v2', contentA);
      final bV1 = _version('b:v1', _content('b'));
      final desiredA1 = MtnMinecraftContentDependencyDesiredVersion(version: aV1, roots: <MtnMinecraftContentVersion>[aV1]);
      final desiredA2 = MtnMinecraftContentDependencyDesiredVersion(version: aV2, roots: <MtnMinecraftContentVersion>[aV2]);

      expect(
        () => MtnMinecraftContentDependencyReconciliationReplacement(current: aV1, desired: desiredA1),
        throwsArgumentError,
      );
      expect(
        () => MtnMinecraftContentDependencyReconciliationReplacement(current: bV1, desired: desiredA2),
        throwsArgumentError,
      );
    });
  });
}

MtnMinecraftContentMod _content(String key) {
  return MtnMinecraftContentMod(key: key, name: key);
}

MtnMinecraftContentVersion _version(
  String key,
  MtnMinecraftContent content, {
  bool direct = false,
}) {
  return MtnMinecraftContentVersion(
    key: key,
    content: content,
    name: key,
    version: key,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    direct: direct,
  );
}

MtnMinecraftContentDependencyDesiredState _desired(
  List<MtnMinecraftContentDependencyInstallPlan> plans,
) {
  return MtnMinecraftContentService().composeDependencyInstallPlans(plans);
}

MtnMinecraftContentDependencyInstallPlan _plan(
  MtnMinecraftContentVersion root,
  List<MtnMinecraftContentVersion> installVersions, {
  List<MtnMinecraftContentDependencyGraphEdge>? unresolvedInstallEdges,
}) {
  return MtnMinecraftContentDependencyInstallPlan(
    root: root,
    installVersions: installVersions,
    installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    incompatibleEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    unresolvedInstallEdges: unresolvedInstallEdges ?? const <MtnMinecraftContentDependencyGraphEdge>[],
    conflicts: const <MtnMinecraftContentDependencyInstallConflict>[],
  );
}

MtnMinecraftContentDependencyGraphEdge _edge(
  MtnMinecraftContentVersion source,
  MtnMinecraftContentDependencyType type,
) {
  final dependency = MtnMinecraftContentDependency(type: type);
  return MtnMinecraftContentDependencyGraphEdge(
    source: source,
    dependency: dependency,
    resolution: MtnMinecraftContentDependencyResolution(dependency: dependency),
    target: null,
    cyclic: false,
  );
}
