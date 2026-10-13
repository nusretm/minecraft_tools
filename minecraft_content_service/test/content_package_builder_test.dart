import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

MtnMinecraftContentVersion contentVersion(String id, {String? projectId, String? artifactHash}) {
  final project = projectId ?? id;
  final content = MtnMinecraftContentMod(
    key: 'modrinth:$project',
    name: 'Mod $project',
    providers: <MtnMinecraftContentProviderMetadata>[
      MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: project),
    ],
  );
  return MtnMinecraftContentVersion(
    key: 'modrinth:version-$id',
    content: content,
    name: 'Version $id',
    version: '1.0.0',
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: const <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    providers: <MtnMinecraftContentProviderMetadata>[
      MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'version-$id'),
    ],
    files: <MtnMinecraftContentFile>[
      MtnMinecraftContentFile(
        fileName: '$id.jar',
        primary: true,
        available: true,
        size: 42,
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(algorithm: 'sha1', value: artifactHash ?? 'a' * 40),
        ],
      ),
    ],
  );
}

MtnMinecraftContentDependencyGraphEdge dependencyEdge(
  MtnMinecraftContentVersion source,
  MtnMinecraftContentVersion target,
  MtnMinecraftContentDependencyType type,
) {
  final dependency = MtnMinecraftContentDependency(type: type, provider: 'modrinth', providerContentId: target.content.providers.single.id);
  return MtnMinecraftContentDependencyGraphEdge(
    source: source,
    dependency: dependency,
    resolution: MtnMinecraftContentDependencyResolution(dependency: dependency, version: target),
    target: target,
    cyclic: false,
  );
}

MtnMinecraftContentDependencyDesiredState stateFor(
  MtnMinecraftContentService service,
  List<MtnMinecraftContentDependencyGraph> graphs, {
  Map<String, List<String>> optionalByRoot = const <String, List<String>>{},
}) {
  final plans = <MtnMinecraftContentDependencyInstallPlan>[
    for (final graph in graphs)
      service.planDependencyInstall(
        graph,
        MtnMinecraftContentDependencyInstallRequest(selectedOptionalVersionKeys: optionalByRoot[graph.root.key] ?? const <String>[]),
      ),
  ];
  return service.composeDependencyInstallPlans(plans);
}

MtnMinecraftContentPackage build(
  MtnMinecraftContentDependencyDesiredState desired,
  Map<String, MtnMinecraftContentFile> files, {
  Map<String, List<MtnMinecraftContentItemPermission>> permissions = const <String, List<MtnMinecraftContentItemPermission>>{},
}) =>
    const MtnMinecraftContentPackageBuilder().build(
      id: 'my-pack',
      title: 'My Pack',
      minecraftVersion: '1.21.11',
      modLoader: MtnMinecraftModLoaderType.fabric,
      desired: desired,
      selectedFilesByVersionKey: files,
      permissionsByItemKey: permissions,
    );

void main() {
  test('two roots share one locked dependency and only selected optional edge survives', () {
    final a = contentVersion('a');
    final x = contentVersion('x');
    final shared = contentVersion('shared');
    final optional = contentVersion('optional');
    final aToShared = dependencyEdge(a, shared, MtnMinecraftContentDependencyType.required);
    final xToShared = dependencyEdge(x, shared, MtnMinecraftContentDependencyType.required);
    final aToOptional = dependencyEdge(a, optional, MtnMinecraftContentDependencyType.optional);
    final service = MtnMinecraftContentService();
    final desired = stateFor(service, <MtnMinecraftContentDependencyGraph>[
      MtnMinecraftContentDependencyGraph(root: a, versions: <MtnMinecraftContentVersion>[a, shared, optional], edges: <MtnMinecraftContentDependencyGraphEdge>[aToShared, aToOptional]),
      MtnMinecraftContentDependencyGraph(root: x, versions: <MtnMinecraftContentVersion>[x, shared], edges: <MtnMinecraftContentDependencyGraphEdge>[xToShared]),
    ], optionalByRoot: <String, List<String>>{a.key: <String>[optional.key]});

    final files = <String, MtnMinecraftContentFile>{
      for (final version in desired.installVersions) version.key: version.files.single,
    };
    final package = build(desired, files, permissions: <String, List<MtnMinecraftContentItemPermission>>{
      'modrinth:a': MtnMinecraftContentItemPermission.values,
      'modrinth:x': MtnMinecraftContentItemPermission.values,
    });

    expect(package.directItems.map((item) => item.projectId).toSet(), <String>{'a', 'x'});
    expect(package.allItems.length, 4);
    expect(package.lock!.versions.length, 4);
    expect(package.lock!.edges.length, 3);
    expect(package.lock!.edges.where((edge) => edge.targetKey == 'modrinth:shared'), hasLength(2));
    expect(package.lock!.edges.where((edge) => edge.type == MtnMinecraftContentDependencyType.optional), hasLength(1));
    expect(package.getItem('modrinth:shared')!.direct, isFalse);
    expect(package.getItem('modrinth:shared')!.canDisable, isFalse);
    expect(package.lock!.versions.first.hashAlgorithm, 'sha1');
    expect(package.lock!.versions.first.hashValue, 'a' * 40);

    package.setDirectEnabled(package.getItem('modrinth:a')!, false);
    expect(package.effectiveEnabled(package.getItem('modrinth:shared')!), isTrue);
    expect(package.effectiveEnabled(package.getItem('modrinth:optional')!), isFalse);
    expect(MtnMinecraftContentPackage.fromJson(package.toJson()).toJson(), package.toJson());
  });

  test('missing retained-version selection or foreign artifact blocks package publication', () {
    final root = contentVersion('root');
    final service = MtnMinecraftContentService();
    final desired = stateFor(service, <MtnMinecraftContentDependencyGraph>[
      MtnMinecraftContentDependencyGraph(root: root, versions: <MtnMinecraftContentVersion>[root], edges: const <MtnMinecraftContentDependencyGraphEdge>[]),
    ]);
    expect(() => build(desired, <String, MtnMinecraftContentFile>{}), throwsArgumentError);
    expect(() => build(desired, <String, MtnMinecraftContentFile>{root.key: MtnMinecraftContentFile(fileName: 'other.jar')}), throwsArgumentError);
    expect(() => build(desired, <String, MtnMinecraftContentFile>{root.key: root.files.single}), returnsNormally);
  });

  test('conflicting exact versions of one content are never silently selected', () {
    final rootA = contentVersion('a');
    final rootX = contentVersion('x');
    final first = contentVersion('b-v1', projectId: 'b');
    final second = contentVersion('b-v2', projectId: 'b');
    final desired = stateFor(MtnMinecraftContentService(), <MtnMinecraftContentDependencyGraph>[
      MtnMinecraftContentDependencyGraph(root: rootA, versions: <MtnMinecraftContentVersion>[rootA, first], edges: <MtnMinecraftContentDependencyGraphEdge>[dependencyEdge(rootA, first, MtnMinecraftContentDependencyType.required)]),
      MtnMinecraftContentDependencyGraph(root: rootX, versions: <MtnMinecraftContentVersion>[rootX, second], edges: <MtnMinecraftContentDependencyGraphEdge>[dependencyEdge(rootX, second, MtnMinecraftContentDependencyType.required)]),
    ]);
    expect(desired.installable, isFalse);
    expect(() => build(desired, <String, MtnMinecraftContentFile>{
      for (final version in desired.installVersions) version.key: version.files.single,
    }), throwsStateError);
  });

  test('file with no portable hash or file ID cannot be locked', () {
    final root = contentVersion('root');
    final version = MtnMinecraftContentVersion(
      key: root.key,
      content: root.content,
      name: root.name,
      version: root.version,
      releaseType: root.releaseType,
      modLoaders: root.modLoaders,
      providers: root.providers,
      files: <MtnMinecraftContentFile>[MtnMinecraftContentFile(fileName: 'no-hash.jar')],
    );
    final desired = stateFor(MtnMinecraftContentService(), <MtnMinecraftContentDependencyGraph>[
      MtnMinecraftContentDependencyGraph(root: version, versions: <MtnMinecraftContentVersion>[version], edges: const <MtnMinecraftContentDependencyGraphEdge>[]),
    ]);
    expect(() => build(desired, <String, MtnMinecraftContentFile>{version.key: version.files.single}), throwsStateError);
  });
}
