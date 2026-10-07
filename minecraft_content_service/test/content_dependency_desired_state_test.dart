import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentService dependency desired state', () {
    test('composes deterministic multi-root ownership and canonical shared versions', () {
      final rootA = _version('a:v1', _content('a'));
      final rootX = _version('x:v1', _content('x'));
      final b = _version('b:v1', _content('b'));
      final c = _version('c:v1', _content('c'));
      final sharedContent = _content('d');
      final sharedFirst = _version('d:v1', sharedContent);
      final sharedLater = _version('d:v1', sharedContent);

      final planA = _plan(rootA, <MtnMinecraftContentVersion>[rootA, b, sharedFirst]);
      final planX = _plan(rootX, <MtnMinecraftContentVersion>[rootX, c, sharedLater]);

      final state = MtnMinecraftContentService().composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[planA, planX]);

      expect(state.plans, <MtnMinecraftContentDependencyInstallPlan>[planA, planX]);
      expect(state.directVersions, <MtnMinecraftContentVersion>[rootA, rootX]);
      expect(state.installVersions, <MtnMinecraftContentVersion>[rootA, b, sharedFirst, rootX, c]);
      expect(state.versions.map((item) => item.version), state.installVersions);

      final desiredShared = state.versions.singleWhere((item) => item.version.key == sharedFirst.key);
      expect(desiredShared.version, same(sharedFirst));
      expect(desiredShared.roots, <MtnMinecraftContentVersion>[rootA, rootX]);
      expect(desiredShared.direct, isFalse);

      final desiredA = state.versions.singleWhere((item) => item.version.key == rootA.key);
      expect(desiredA.roots, <MtnMinecraftContentVersion>[rootA]);
      expect(desiredA.direct, isTrue);
      expect(state.conflicts, isEmpty);
      expect(state.installable, isTrue);
    });

    test('promotes a shared dependency to direct without mutating version direct state', () {
      final rootA = _version('a:v1', _content('a'));
      final bContent = _content('b');
      final bFromDependency = _version('b:v1', bContent);
      final bAsRoot = _version('b:v1', bContent);

      final planA = _plan(rootA, <MtnMinecraftContentVersion>[rootA, bFromDependency]);
      final planB = _plan(bAsRoot, <MtnMinecraftContentVersion>[bAsRoot]);

      final state = MtnMinecraftContentService().composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[planA, planB]);

      expect(state.directVersions, <MtnMinecraftContentVersion>[rootA, bFromDependency]);
      final desiredB = state.versions.singleWhere((item) => item.version.key == bFromDependency.key);
      expect(desiredB.version, same(bFromDependency));
      expect(desiredB.roots, <MtnMinecraftContentVersion>[rootA, bFromDependency]);
      expect(desiredB.direct, isTrue);
      expect(bFromDependency.direct, isFalse);
      expect(bAsRoot.direct, isFalse);
      expect(state.installable, isTrue);
    });

    test('rejects duplicate install plans for the same root version key', () {
      final rootFirst = _version('a:v1', _content('a'));
      final rootSecond = _version('a:v1', rootFirst.content);

      expect(
        () => MtnMinecraftContentService().composeDependencyInstallPlans(
          <MtnMinecraftContentDependencyInstallPlan>[
            _plan(rootFirst, <MtnMinecraftContentVersion>[rootFirst]),
            _plan(rootSecond, <MtnMinecraftContentVersion>[rootSecond]),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('reports cross-root multiple-version conflicts without choosing a winner', () {
      final rootA = _version('a:v1', _content('a'));
      final rootX = _version('x:v1', _content('x'));
      final sharedContent = _content('b');
      final bV1 = _version('b:v1', sharedContent);
      final bV2 = _version('b:v2', sharedContent);

      final state = MtnMinecraftContentService().composeDependencyInstallPlans(
        <MtnMinecraftContentDependencyInstallPlan>[
          _plan(rootA, <MtnMinecraftContentVersion>[rootA, bV1]),
          _plan(rootX, <MtnMinecraftContentVersion>[rootX, bV2]),
        ],
      );

      expect(state.installVersions, <MtnMinecraftContentVersion>[rootA, bV1, rootX, bV2]);
      expect(state.conflicts, hasLength(1));
      final conflict = state.conflicts.single as MtnMinecraftContentDependencyInstallConflictMultipleVersions;
      expect(conflict.contentKey, sharedContent.key);
      expect(conflict.versions, <MtnMinecraftContentVersion>[bV1, bV2]);
      expect(state.installable, isFalse);
    });

    test('preserves root-local blockers without duplicating them as desired-state conflicts', () {
      final root = _version('a:v1', _content('a'));
      final sharedContent = _content('b');
      final bV1 = _version('b:v1', sharedContent);
      final bV2 = _version('b:v2', sharedContent);
      final localConflict = MtnMinecraftContentDependencyInstallConflictMultipleVersions(
        contentKey: sharedContent.key,
        versions: <MtnMinecraftContentVersion>[bV1, bV2],
      );
      final unresolved = _edge(root, MtnMinecraftContentDependencyType.required);

      final plan = _plan(
        root,
        <MtnMinecraftContentVersion>[root, bV1, bV2],
        unresolvedInstallEdges: <MtnMinecraftContentDependencyGraphEdge>[unresolved],
        conflicts: <MtnMinecraftContentDependencyInstallConflict>[localConflict],
      );
      final state = MtnMinecraftContentService().composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[plan]);

      expect(plan.installable, isFalse);
      expect(state.plans.single, same(plan));
      expect(state.conflicts, isEmpty);
      expect(state.installable, isFalse);
    });

    test('detects content-level incompatibility introduced by another root plan', () {
      final rootA = _version('a:v1', _content('a'));
      final rootX = _version('x:v1', _content('x'));
      final incompatibleEdge = _edge(
        rootA,
        MtnMinecraftContentDependencyType.incompatible,
        dependency: MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.incompatible,
          content: rootX.content,
        ),
        target: rootX,
      );

      final planA = _plan(
        rootA,
        <MtnMinecraftContentVersion>[rootA],
        incompatibleEdges: <MtnMinecraftContentDependencyGraphEdge>[incompatibleEdge],
      );
      final planX = _plan(rootX, <MtnMinecraftContentVersion>[rootX]);

      final state = MtnMinecraftContentService().composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[planA, planX]);

      expect(planA.installable, isTrue);
      expect(planX.installable, isTrue);
      expect(state.conflicts, hasLength(1));
      final conflict = state.conflicts.single as MtnMinecraftContentDependencyInstallConflictIncompatible;
      expect(conflict.edge, same(incompatibleEdge));
      expect(conflict.conflictingVersion, same(rootX));
      expect(state.installable, isFalse);
    });

    test('exact incompatibility matches only the exact cross-root version', () {
      final rootA = _version('a:v1', _content('a'));
      final bContent = _content('b');
      final bV1 = _version('b:v1', bContent);
      final bV2 = _version('b:v2', bContent);
      final rootX = _version('x:v1', _content('x'));
      final rootY = _version('y:v1', _content('y'));
      final exactDependency = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.incompatible,
        version: bV1,
      );
      final incompatibleEdge = _edge(
        rootA,
        MtnMinecraftContentDependencyType.incompatible,
        dependency: exactDependency,
        target: bV1,
      );
      final planA = _plan(
        rootA,
        <MtnMinecraftContentVersion>[rootA],
        incompatibleEdges: <MtnMinecraftContentDependencyGraphEdge>[incompatibleEdge],
      );

      final noMatch = MtnMinecraftContentService().composeDependencyInstallPlans(
        <MtnMinecraftContentDependencyInstallPlan>[
          planA,
          _plan(rootX, <MtnMinecraftContentVersion>[rootX, bV2]),
        ],
      );

      expect(noMatch.conflicts, isEmpty);
      expect(noMatch.installable, isTrue);

      final match = MtnMinecraftContentService().composeDependencyInstallPlans(
        <MtnMinecraftContentDependencyInstallPlan>[
          planA,
          _plan(rootY, <MtnMinecraftContentVersion>[rootY, bV1]),
        ],
      );

      expect(match.conflicts, hasLength(1));
      final conflict = match.conflicts.single as MtnMinecraftContentDependencyInstallConflictIncompatible;
      expect(conflict.conflictingVersion, same(bV1));
      expect(match.installable, isFalse);
    });

    test('does not duplicate a root-local incompatibility as a desired-state conflict', () {
      final root = _version('a:v1', _content('a'));
      final b = _version('b:v1', _content('b'));
      final incompatibleEdge = _edge(
        root,
        MtnMinecraftContentDependencyType.incompatible,
        dependency: MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.incompatible,
          content: b.content,
        ),
        target: b,
      );
      final localConflict = MtnMinecraftContentDependencyInstallConflictIncompatible(
        edge: incompatibleEdge,
        conflictingVersion: b,
      );
      final plan = _plan(
        root,
        <MtnMinecraftContentVersion>[root, b],
        incompatibleEdges: <MtnMinecraftContentDependencyGraphEdge>[incompatibleEdge],
        conflicts: <MtnMinecraftContentDependencyInstallConflict>[localConflict],
      );

      final state = MtnMinecraftContentService().composeDependencyInstallPlans(<MtnMinecraftContentDependencyInstallPlan>[plan]);

      expect(plan.installable, isFalse);
      expect(state.conflicts, isEmpty);
      expect(state.installable, isFalse);
    });

    test('supports an empty desired state and keeps all result collections immutable', () {
      final plans = <MtnMinecraftContentDependencyInstallPlan>[];
      final state = MtnMinecraftContentService().composeDependencyInstallPlans(plans);
      plans.clear();

      expect(state.plans, isEmpty);
      expect(state.directVersions, isEmpty);
      expect(state.versions, isEmpty);
      expect(state.installVersions, isEmpty);
      expect(state.conflicts, isEmpty);
      expect(state.installable, isTrue);
      expect(() => state.plans.clear(), throwsUnsupportedError);
      expect(() => state.directVersions.clear(), throwsUnsupportedError);
      expect(() => state.versions.clear(), throwsUnsupportedError);
      expect(() => state.installVersions.clear(), throwsUnsupportedError);
      expect(() => state.conflicts.clear(), throwsUnsupportedError);
    });

    test('desired version root ownership is immutable', () {
      final root = _version('a:v1', _content('a'));
      final dependency = _version('b:v1', _content('b'));
      final state = MtnMinecraftContentService().composeDependencyInstallPlans(
        <MtnMinecraftContentDependencyInstallPlan>[
          _plan(root, <MtnMinecraftContentVersion>[root, dependency]),
        ],
      );

      final desiredDependency = state.versions.singleWhere((item) => item.version.key == dependency.key);
      expect(desiredDependency.roots, <MtnMinecraftContentVersion>[root]);
      expect(() => desiredDependency.roots.add(root), throwsUnsupportedError);
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

MtnMinecraftContentDependencyInstallPlan _plan(
  MtnMinecraftContentVersion root,
  List<MtnMinecraftContentVersion> installVersions, {
  List<MtnMinecraftContentDependencyGraphEdge>? incompatibleEdges,
  List<MtnMinecraftContentDependencyGraphEdge>? unresolvedInstallEdges,
  List<MtnMinecraftContentDependencyInstallConflict>? conflicts,
}) {
  return MtnMinecraftContentDependencyInstallPlan(
    root: root,
    installVersions: installVersions,
    installEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    optionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    selectedOptionalEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    bundledEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    toolEdges: const <MtnMinecraftContentDependencyGraphEdge>[],
    incompatibleEdges: incompatibleEdges ?? const <MtnMinecraftContentDependencyGraphEdge>[],
    unresolvedInstallEdges: unresolvedInstallEdges ?? const <MtnMinecraftContentDependencyGraphEdge>[],
    conflicts: conflicts ?? const <MtnMinecraftContentDependencyInstallConflict>[],
  );
}

MtnMinecraftContentDependencyGraphEdge _edge(
  MtnMinecraftContentVersion source,
  MtnMinecraftContentDependencyType type, {
  MtnMinecraftContentDependency? dependency,
  MtnMinecraftContentVersion? target,
}) {
  final declaration = dependency ?? MtnMinecraftContentDependency(type: type);

  return MtnMinecraftContentDependencyGraphEdge(
    source: source,
    dependency: declaration,
    resolution: MtnMinecraftContentDependencyResolution(
      dependency: declaration,
      version: target,
    ),
    target: target,
    cyclic: false,
  );
}
