import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentService dependency install policy', () {
    test('traverses only install-reachable required and embedded-library branches', () {
      final root = _version('root:v1', _content('root'));
      final b = _version('b:v1', _content('b'));
      final c = _version('c:v1', _content('c'));
      final d = _version('d:v1', _content('d'));
      final e = _version('e:v1', _content('e'));
      final x = _version('x:v1', _content('x'));
      final y = _version('y:v1', _content('y'));
      final tool = _version('tool:v1', _content('tool'));

      final rootToB = _edge(root, MtnMinecraftContentDependencyType.required, target: b);
      final bToD = _edge(b, MtnMinecraftContentDependencyType.embeddedLibrary, target: d);
      final rootToC = _edge(root, MtnMinecraftContentDependencyType.optional, target: c);
      final cToE = _edge(c, MtnMinecraftContentDependencyType.required, target: e);
      final rootToX = _edge(root, MtnMinecraftContentDependencyType.bundled, target: x);
      final xToY = _edge(x, MtnMinecraftContentDependencyType.required, target: y);
      final rootToTool = _edge(root, MtnMinecraftContentDependencyType.tool, target: tool);

      final graph = MtnMinecraftContentDependencyGraph(
        root: root,
        versions: <MtnMinecraftContentVersion>[root, b, d, c, e, x, y, tool],
        edges: <MtnMinecraftContentDependencyGraphEdge>[rootToB, bToD, rootToC, cToE, rootToX, xToY, rootToTool],
      );
      final service = MtnMinecraftContentService();

      final plan = service.planDependencyInstall(graph, MtnMinecraftContentDependencyInstallRequest());

      expect(plan.installVersions.map((version) => version.key), <String>['root:v1', 'b:v1', 'd:v1']);
      expect(plan.installEdges, <MtnMinecraftContentDependencyGraphEdge>[rootToB, bToD]);
      expect(plan.optionalEdges, <MtnMinecraftContentDependencyGraphEdge>[rootToC]);
      expect(plan.selectedOptionalEdges, isEmpty);
      expect(plan.bundledEdges, <MtnMinecraftContentDependencyGraphEdge>[rootToX]);
      expect(plan.toolEdges, <MtnMinecraftContentDependencyGraphEdge>[rootToTool]);
      expect(plan.incompatibleEdges, isEmpty);
      expect(plan.unresolvedInstallEdges, isEmpty);
      expect(plan.conflicts, isEmpty);
      expect(plan.installable, isTrue);
      expect(plan.installVersions, isNot(contains(e)));
      expect(plan.installVersions, isNot(contains(y)));
    });

    test('selected optional versions obey active-source reachability', () {
      final root = _version('root:v1', _content('root'));
      final b = _version('b:v1', _content('b'));
      final c = _version('c:v1', _content('c'));

      final rootToB = _edge(root, MtnMinecraftContentDependencyType.optional, target: b);
      final bToC = _edge(b, MtnMinecraftContentDependencyType.optional, target: c);
      final graph = MtnMinecraftContentDependencyGraph(
        root: root,
        versions: <MtnMinecraftContentVersion>[root, b, c],
        edges: <MtnMinecraftContentDependencyGraphEdge>[rootToB, bToC],
      );
      final service = MtnMinecraftContentService();

      final nestedOnly = service.planDependencyInstall(
        graph,
        MtnMinecraftContentDependencyInstallRequest(selectedOptionalVersionKeys: <String>[c.key]),
      );

      expect(nestedOnly.installVersions, <MtnMinecraftContentVersion>[root]);
      expect(nestedOnly.optionalEdges, <MtnMinecraftContentDependencyGraphEdge>[rootToB]);
      expect(nestedOnly.selectedOptionalEdges, isEmpty);

      final both = service.planDependencyInstall(
        graph,
        MtnMinecraftContentDependencyInstallRequest(selectedOptionalVersionKeys: <String>[b.key, c.key]),
      );

      expect(both.installVersions, <MtnMinecraftContentVersion>[root, b, c]);
      expect(both.optionalEdges, <MtnMinecraftContentDependencyGraphEdge>[rootToB, bToC]);
      expect(both.selectedOptionalEdges, <MtnMinecraftContentDependencyGraphEdge>[rootToB, bToC]);
      expect(both.installEdges, <MtnMinecraftContentDependencyGraphEdge>[rootToB, bToC]);
      expect(both.installable, isTrue);
    });

    test('rejects optional selections that do not identify a resolved optional graph target', () {
      final root = _version('root:v1', _content('root'));
      final required = _version('required:v1', _content('required'));
      final optional = _version('optional:v1', _content('optional'));
      final graph = MtnMinecraftContentDependencyGraph(
        root: root,
        versions: <MtnMinecraftContentVersion>[root, required, optional],
        edges: <MtnMinecraftContentDependencyGraphEdge>[
          _edge(root, MtnMinecraftContentDependencyType.required, target: required),
          _edge(root, MtnMinecraftContentDependencyType.optional, target: optional),
        ],
      );
      final service = MtnMinecraftContentService();

      expect(
        () => service.planDependencyInstall(
          graph,
          MtnMinecraftContentDependencyInstallRequest(selectedOptionalVersionKeys: <String>[required.key]),
        ),
        throwsArgumentError,
      );
      expect(
        () => MtnMinecraftContentDependencyInstallRequest(selectedOptionalVersionKeys: <String>['']),
        throwsArgumentError,
      );
      expect(
        () => MtnMinecraftContentDependencyInstallRequest(selectedOptionalVersionKeys: <String>[optional.key, optional.key]),
        throwsArgumentError,
      );
    });

    test('only unresolved install-required edges block the plan', () {
      final root = _version('root:v1', _content('root'));
      final required = _edge(root, MtnMinecraftContentDependencyType.required);
      final embeddedLibrary = _edge(root, MtnMinecraftContentDependencyType.embeddedLibrary);
      final optional = _edge(root, MtnMinecraftContentDependencyType.optional);
      final bundled = _edge(root, MtnMinecraftContentDependencyType.bundled);
      final tool = _edge(root, MtnMinecraftContentDependencyType.tool);
      final incompatible = _edge(root, MtnMinecraftContentDependencyType.incompatible);
      final graph = MtnMinecraftContentDependencyGraph(
        root: root,
        versions: <MtnMinecraftContentVersion>[root],
        edges: <MtnMinecraftContentDependencyGraphEdge>[required, embeddedLibrary, optional, bundled, tool, incompatible],
      );

      final plan = MtnMinecraftContentService().planDependencyInstall(graph, MtnMinecraftContentDependencyInstallRequest());

      expect(plan.unresolvedInstallEdges, <MtnMinecraftContentDependencyGraphEdge>[required, embeddedLibrary]);
      expect(plan.optionalEdges, <MtnMinecraftContentDependencyGraphEdge>[optional]);
      expect(plan.bundledEdges, <MtnMinecraftContentDependencyGraphEdge>[bundled]);
      expect(plan.toolEdges, <MtnMinecraftContentDependencyGraphEdge>[tool]);
      expect(plan.incompatibleEdges, <MtnMinecraftContentDependencyGraphEdge>[incompatible]);
      expect(plan.conflicts, isEmpty);
      expect(plan.installable, isFalse);
    });

    test('required cycles remain installable and do not duplicate versions', () {
      final contentA = _content('a');
      final contentB = _content('b');
      final a = _version('a:v1', contentA);
      final b = _version('b:v1', contentB);
      final aToB = _edge(a, MtnMinecraftContentDependencyType.required, target: b);
      final bToA = _edge(b, MtnMinecraftContentDependencyType.required, target: a, cyclic: true);
      final graph = MtnMinecraftContentDependencyGraph(
        root: a,
        versions: <MtnMinecraftContentVersion>[a, b],
        edges: <MtnMinecraftContentDependencyGraphEdge>[aToB, bToA],
      );

      final plan = MtnMinecraftContentService().planDependencyInstall(graph, MtnMinecraftContentDependencyInstallRequest());

      expect(plan.installVersions, <MtnMinecraftContentVersion>[a, b]);
      expect(plan.installEdges, <MtnMinecraftContentDependencyGraphEdge>[aToB, bToA]);
      expect(plan.conflicts, isEmpty);
      expect(plan.installable, isTrue);
    });

    test('multiple install-reachable versions of the same logical content are blocking', () {
      final root = _version('root:v1', _content('root'));
      final sharedContent = _content('shared');
      final sharedV1 = _version('shared:v1', sharedContent);
      final sharedV2 = _version('shared:v2', sharedContent);
      final c = _version('c:v1', _content('c'));

      final rootToV1 = _edge(root, MtnMinecraftContentDependencyType.required, target: sharedV1);
      final rootToC = _edge(root, MtnMinecraftContentDependencyType.required, target: c);
      final cToV2 = _edge(c, MtnMinecraftContentDependencyType.required, target: sharedV2);
      final graph = MtnMinecraftContentDependencyGraph(
        root: root,
        versions: <MtnMinecraftContentVersion>[root, sharedV1, c, sharedV2],
        edges: <MtnMinecraftContentDependencyGraphEdge>[rootToV1, rootToC, cToV2],
      );

      final plan = MtnMinecraftContentService().planDependencyInstall(graph, MtnMinecraftContentDependencyInstallRequest());

      expect(plan.installVersions, <MtnMinecraftContentVersion>[root, sharedV1, c, sharedV2]);
      expect(plan.conflicts, hasLength(1));
      final conflict = plan.conflicts.single as MtnMinecraftContentDependencyInstallConflictMultipleVersions;
      expect(conflict.contentKey, sharedContent.key);
      expect(conflict.versions, <MtnMinecraftContentVersion>[sharedV1, sharedV2]);
      expect(plan.installable, isFalse);
    });

    test('content-level incompatibility is not narrowed to the graph-selected version', () {
      final root = _version('root:v1', _content('root'));
      final contentB = _content('b');
      final bInstalled = _version('b:v2', contentB);
      final bGraphTarget = _version('b:v1', contentB);
      final c = _version('c:v1', _content('c'));

      final rootToB = _edge(root, MtnMinecraftContentDependencyType.required, target: bInstalled);
      final rootToC = _edge(root, MtnMinecraftContentDependencyType.required, target: c);
      final incompatibleDependency = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.incompatible,
        providerContentId: 'b',
      );
      final cIncompatibleB = _edge(
        c,
        MtnMinecraftContentDependencyType.incompatible,
        dependency: incompatibleDependency,
        target: bGraphTarget,
      );
      final graph = MtnMinecraftContentDependencyGraph(
        root: root,
        versions: <MtnMinecraftContentVersion>[root, bInstalled, c, bGraphTarget],
        edges: <MtnMinecraftContentDependencyGraphEdge>[rootToB, rootToC, cIncompatibleB],
      );

      final plan = MtnMinecraftContentService().planDependencyInstall(graph, MtnMinecraftContentDependencyInstallRequest());

      expect(plan.incompatibleEdges, <MtnMinecraftContentDependencyGraphEdge>[cIncompatibleB]);
      final incompatibilities = plan.conflicts.whereType<MtnMinecraftContentDependencyInstallConflictIncompatible>().toList();
      expect(incompatibilities, hasLength(1));
      expect(incompatibilities.single.conflictingVersion, same(bInstalled));
      expect(plan.installable, isFalse);
    });

    test('exact incompatibility matches only its exact version and inactive-source rules are ignored', () {
      final root = _version('root:v1', _content('root'));
      final contentB = _content('b');
      final bV1 = _version('b:v1', contentB);
      final bV2 = _version('b:v2', contentB);
      final c = _version('c:v1', _content('c'));
      final d = _version('d:v1', _content('d'));

      final rootToB = _edge(root, MtnMinecraftContentDependencyType.required, target: bV2);
      final rootToC = _edge(root, MtnMinecraftContentDependencyType.required, target: c);
      final rootToD = _edge(root, MtnMinecraftContentDependencyType.optional, target: d);
      final exactDependency = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.incompatible,
        providerVersionId: 'remote-b-v1',
      );
      final cIncompatibleV1 = _edge(
        c,
        MtnMinecraftContentDependencyType.incompatible,
        dependency: exactDependency,
        target: bV1,
      );
      final inactiveContentDependency = MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.incompatible,
        content: contentB,
      );
      final dIncompatibleB = _edge(
        d,
        MtnMinecraftContentDependencyType.incompatible,
        dependency: inactiveContentDependency,
        resolvedContent: contentB,
      );
      final graph = MtnMinecraftContentDependencyGraph(
        root: root,
        versions: <MtnMinecraftContentVersion>[root, bV2, c, d, bV1],
        edges: <MtnMinecraftContentDependencyGraphEdge>[rootToB, rootToC, rootToD, cIncompatibleV1, dIncompatibleB],
      );

      final plan = MtnMinecraftContentService().planDependencyInstall(graph, MtnMinecraftContentDependencyInstallRequest());

      expect(plan.installVersions, <MtnMinecraftContentVersion>[root, bV2, c]);
      expect(plan.incompatibleEdges, <MtnMinecraftContentDependencyGraphEdge>[cIncompatibleV1]);
      expect(plan.conflicts.whereType<MtnMinecraftContentDependencyInstallConflictIncompatible>(), isEmpty);
      expect(plan.installable, isTrue);
    });

    test('plan and request collections are immutable and planning does not mutate version direct state', () {
      final root = _version('root:v1', _content('root'), direct: true);
      final optional = _version('optional:v1', _content('optional'));
      final optionalEdge = _edge(root, MtnMinecraftContentDependencyType.optional, target: optional);
      final graph = MtnMinecraftContentDependencyGraph(
        root: root,
        versions: <MtnMinecraftContentVersion>[root, optional],
        edges: <MtnMinecraftContentDependencyGraphEdge>[optionalEdge],
      );
      final selectedKeys = <String>[optional.key];
      final request = MtnMinecraftContentDependencyInstallRequest(selectedOptionalVersionKeys: selectedKeys);
      selectedKeys.clear();

      final plan = MtnMinecraftContentService().planDependencyInstall(graph, request);

      expect(request.selectedOptionalVersionKeys, <String>[optional.key]);
      expect(root.direct, isTrue);
      expect(optional.direct, isFalse);
      expect(() => request.selectedOptionalVersionKeys.add('other'), throwsUnsupportedError);
      expect(() => plan.installVersions.clear(), throwsUnsupportedError);
      expect(() => plan.installEdges.clear(), throwsUnsupportedError);
      expect(() => plan.optionalEdges.clear(), throwsUnsupportedError);
      expect(() => plan.selectedOptionalEdges.clear(), throwsUnsupportedError);
      expect(() => plan.bundledEdges.clear(), throwsUnsupportedError);
      expect(() => plan.toolEdges.clear(), throwsUnsupportedError);
      expect(() => plan.incompatibleEdges.clear(), throwsUnsupportedError);
      expect(() => plan.unresolvedInstallEdges.clear(), throwsUnsupportedError);
      expect(() => plan.conflicts.clear(), throwsUnsupportedError);
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

MtnMinecraftContentDependencyGraphEdge _edge(
  MtnMinecraftContentVersion source,
  MtnMinecraftContentDependencyType type, {
  MtnMinecraftContentDependency? dependency,
  MtnMinecraftContentVersion? target,
  MtnMinecraftContent? resolvedContent,
  bool cyclic = false,
}) {
  final declaration = dependency ?? MtnMinecraftContentDependency(type: type);

  return MtnMinecraftContentDependencyGraphEdge(
    source: source,
    dependency: declaration,
    resolution: MtnMinecraftContentDependencyResolution(
      dependency: declaration,
      content: target == null ? resolvedContent : null,
      version: target,
    ),
    target: target,
    cyclic: cyclic,
  );
}
